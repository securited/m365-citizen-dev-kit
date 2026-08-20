# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "streamlit",
#   "httpx",
#   "azure-identity",
#   "tenacity",
# ]
# ///
"""EUDA Worker — multi-user coordinated automation (working proof, Pattern C).

The pattern: several users keep this app open. Recurring jobs are defined as
items in a SharePoint list ("EUDA Schedules"). Every open worker polls for due
schedules and races to claim each run with an atomic compare-and-swap: a list
item MERGE conditioned on If-Match: <etag>. SharePoint guarantees exactly one
writer wins (everyone else gets 412 Precondition Failed), so exactly one
machine executes each run — no server, no leader election, no lock files.
Every run is logged to a second list ("EUDA JobRuns") for visibility; the
euda-worker-status.aspx page shows the same state to anyone on SharePoint.

End-user experience: double-click launch.cmd. A browser tab opens; click
"Sign in & join". While the tab is open, this machine is part of the worker
pool. Close the tab, and it isn't. That's the whole contract.

Identity is the signed-in user (Entra browser sign-in, cached via DPAPI).
Because requests authenticate with a Bearer token, no X-RequestDigest is
needed — the form digest only applies to cookie-authenticated sessions.

Jobs must be idempotent: claiming is exactly-once, but a crashed winner means
a skipped run and an extreme edge (claim response lost in transit) could
double-run. The demo job overwrites the same file, so reruns are harmless.
"""
from __future__ import annotations

import json
import logging
import platform
import sys
import threading
import time
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

import httpx
import streamlit as st
from azure.identity import InteractiveBrowserCredential, TokenCachePersistenceOptions
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

DEFAULT_SITE = "https://contoso.sharepoint.com/sites/euda-sample"
# Shared IT-owned public client registration ("Contoso EUDA Applications" —
# the platform standard, see PACKAGED_PYTHON_PATTERN.md); allows the
# http://localhost redirect URI used by interactive browser sign-in.
import os  # noqa: E402

TENANT_ID = os.environ.get("EUDA_WORKER_TENANT_ID", "<your-tenant-id>")
CLIENT_ID = os.environ.get("EUDA_WORKER_CLIENT_ID", "<your-entra-client-id>")

SCHEDULES_LIST = "EUDA Schedules"
JOBRUNS_LIST = "EUDA JobRuns"
DEMO_SCHEDULE_TITLE = "Weather snapshot (demo)"

# Internal field names are space-free so REST names match display names.
# FieldTypeKind: 2=Text, 3=Note, 4=DateTime, 8=Boolean, 9=Number
SCHEDULES_FIELDS = [
    ("JobType", 2), ("ParametersJson", 3), ("IntervalMinutes", 9),
    ("NextRunDue", 4), ("ClaimedBy", 2), ("RunId", 2), ("Enabled", 8),
]
JOBRUNS_FIELDS = [
    ("JobTitle", 2), ("JobStatus", 2), ("RunBy", 2), ("StartedUtc", 2),
    ("FinishedUtc", 2), ("DurationMs", 9), ("Output", 3), ("ErrorText", 3),
]

FIELD_EXISTS_CODE = "-2130575306"  # "field already exists" — treat as success
CLAIM_GRACE_SECONDS = 90           # re-verify the claim if execution starts later than this

log = logging.getLogger("euda-worker")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_sp_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


# ── SharePoint REST client ──────────────────────────────────────────────────


class SPError(RuntimeError):
    pass


class TransientSPError(SPError):
    pass


class SPClient:
    """Minimal SharePoint REST client: Bearer auth, verbose OData, CAS via If-Match."""

    def __init__(self, site_url: str):
        self.site = site_url.rstrip("/")
        parts = urlsplit(self.site)
        self.scope = f"{parts.scheme}://{parts.netloc}/.default"
        self.credential = InteractiveBrowserCredential(
            tenant_id=TENANT_ID,
            client_id=CLIENT_ID,
            cache_persistence_options=TokenCachePersistenceOptions(name="euda-worker"),
        )
        self.http = httpx.Client(timeout=30)  # thread-safe; shared by race threads
        self._entity_types: dict[str, str] = {}

    def _headers(self, extra: dict | None = None) -> dict:
        token = self.credential.get_token(self.scope).token
        h = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json;odata=verbose",
        }
        if extra:
            h.update(extra)
        return h

    @retry(
        retry=retry_if_exception_type((httpx.TransportError, TransientSPError)),
        wait=wait_exponential(multiplier=1, max=30),
        stop=stop_after_attempt(4),
        reraise=True,
    )
    def request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict | None = None,
        content: bytes | None = None,
        headers: dict | None = None,
        params: dict | None = None,
        ok: tuple = (200, 201, 204),
        allow: tuple = (),
    ) -> httpx.Response:
        url = path if path.startswith("http") else self.site + path
        h = self._headers(headers)
        body = None
        if json_body is not None:
            body = json.dumps(json_body).encode()
            h["Content-Type"] = "application/json;odata=verbose"
        elif content is not None:
            body = content
        r = self.http.request(method, url, content=body, headers=h, params=params)
        if r.status_code in ok or r.status_code in allow:
            return r
        if r.status_code in (429, 503):
            # Throttling etiquette: honor Retry-After, then let tenacity retry.
            wait_s = min(int(r.headers.get("Retry-After", "10") or 10), 60)
            log.warning("Throttled (%s) — backing off %ss", r.status_code, wait_s)
            time.sleep(wait_s)
            raise TransientSPError(f"HTTP {r.status_code}")
        raise SPError(f"{method} {url} -> HTTP {r.status_code}: {r.text[:400]}")

    # ── identity ──
    def whoami(self) -> str:
        d = self.request("GET", "/_api/web/currentUser?$select=Title,LoginName").json()["d"]
        login = d["LoginName"].split("|")[-1]
        return f"{d['Title']} <{login}> via euda-worker@{platform.node()}"

    # ── lists & provisioning ──
    def list_path(self, title: str) -> str:
        return f"/_api/web/lists/getbytitle('{title.replace(' ', '%20')}')"

    def entity_type(self, title: str) -> str:
        if title not in self._entity_types:
            d = self.request(
                "GET", f"{self.list_path(title)}?$select=ListItemEntityTypeFullName"
            ).json()["d"]
            self._entity_types[title] = d["ListItemEntityTypeFullName"]
        return self._entity_types[title]

    def ensure_list(self, title: str, fields: list[tuple[str, int]]) -> None:
        r = self.request("GET", f"{self.list_path(title)}?$select=Title", ok=(200,), allow=(404,))
        if r.status_code == 404:
            self.request(
                "POST",
                "/_api/web/lists",
                json_body={
                    "__metadata": {"type": "SP.List"},
                    "Title": title,
                    "BaseTemplate": 100,
                    "Description": "EUDA Worker coordination list — managed by euda-worker.",
                },
                ok=(201,),
            )
        for name, kind in fields:
            r = self.request(
                "POST",
                f"{self.list_path(title)}/fields",
                json_body={
                    "__metadata": {"type": "SP.Field"},
                    "Title": name,
                    "FieldTypeKind": kind,
                },
                ok=(201,),
                allow=(500,),
            )
            if r.status_code == 500 and FIELD_EXISTS_CODE not in r.text:
                raise SPError(f"Creating field {title}.{name}: {r.text[:300]}")

    # ── items ──
    def get_items(self, title: str, odata_filter: str = "", top: int = 50,
                  orderby: str = "") -> list[dict]:
        params = {"$top": str(top)}
        if odata_filter:
            params["$filter"] = odata_filter
        if orderby:
            params["$orderby"] = orderby
        d = self.request("GET", f"{self.list_path(title)}/items", params=params).json()["d"]
        return d["results"]

    def add_item(self, title: str, fields: dict) -> dict:
        body = {"__metadata": {"type": self.entity_type(title)}, **fields}
        return self.request(
            "POST", f"{self.list_path(title)}/items", json_body=body, ok=(201,)
        ).json()["d"]

    def merge_item(
        self, title: str, item: dict, fields: dict, etag: str = "*"
    ) -> httpx.Response:
        """Conditional update. With a real etag this is the atomic claim:
        exactly one concurrent caller gets 204; the rest get 412."""
        body = {"__metadata": {"type": self.entity_type(title)}, **fields}
        return self.request(
            "POST",
            item["__metadata"]["uri"],
            json_body=body,
            headers={"X-HTTP-Method": "MERGE", "If-Match": etag},
            ok=(204,),
            allow=(412,),
        )

    # ── files ──
    def upload_file(self, folder_server_rel: str, filename: str, data: bytes) -> None:
        self.request(
            "POST",
            f"/_api/web/getfolderbyserverrelativeurl('{folder_server_rel}')"
            f"/files/add(url='{filename}',overwrite=true)",
            content=data,
            ok=(200,),
        )


# ── Job catalog ──────────────────────────────────────────────────────────────

WMO = {0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog",
       51: "Light drizzle", 53: "Drizzle", 61: "Light rain", 63: "Rain", 65: "Heavy rain",
       71: "Light snow", 73: "Snow", 75: "Heavy snow", 80: "Showers", 95: "Thunderstorm"}


def job_weather_to_json(sp: SPClient, params: dict, ctx: dict) -> str:
    """Fetch current weather and overwrite a JSON file (shown as "Latest output"
    on euda-worker-status.aspx). Idempotent: reruns overwrite the same file."""
    lat = params.get("latitude", 47.6062)
    lon = params.get("longitude", -122.3321)
    label = params.get("label", "Seattle, WA")
    r = httpx.get(
        "https://api.open-meteo.com/v1/forecast",
        params={
            "latitude": lat, "longitude": lon,
            "current": "temperature_2m,wind_speed_10m,relative_humidity_2m,weather_code",
            "temperature_unit": "fahrenheit", "wind_speed_unit": "mph",
            "timezone": "America/New_York",
        },
        timeout=20,
    )
    r.raise_for_status()
    cur = r.json()["current"]
    summary = (
        f"{WMO.get(cur['weather_code'], 'Code ' + str(cur['weather_code']))}, "
        f"{cur['temperature_2m']}°F, wind {cur['wind_speed_10m']} mph, humidity "
        f"{cur['relative_humidity_2m']}% ({label} at {cur['time']})"
    )
    payload = {
        "updatedAt": iso(utcnow()),
        "source": "worker",
        "runBy": ctx["who"],
        "summary": summary,
        "weather": cur,
        "runId": ctx["run_id"],
    }
    sp.upload_file(
        params["targetFolder"],
        params.get("targetFile", "latest.json"),
        json.dumps(payload, indent=2).encode(),
    )
    return summary


JOB_CATALOG = {"weather-to-json": job_weather_to_json}


# ── Coordination: claim + execute ────────────────────────────────────────────


def claim_schedule(sp: SPClient, item: dict, run_id: str, who: str) -> bool:
    """The heart of the pattern: CAS on the schedule item. 204 = we own this
    run; 412 = another instance claimed it between our read and our write."""
    interval = int(item.get("IntervalMinutes") or 15)
    r = sp.merge_item(
        SCHEDULES_LIST,
        item,
        {
            "NextRunDue": iso(utcnow() + timedelta(minutes=interval)),
            "ClaimedBy": who[:250],
            "RunId": run_id,
        },
        etag=item["__metadata"]["etag"],
    )
    return r.status_code == 204


def verify_claim(sp: SPClient, item: dict, run_id: str) -> bool:
    """Fencing guard: if this machine slept between claim and execution,
    re-read and confirm the claim is still ours before causing side effects."""
    fresh = sp.request("GET", item["__metadata"]["uri"]).json()["d"]
    return fresh.get("RunId") == run_id


def execute_claimed(sp: SPClient, item: dict, run_id: str, who: str,
                    feed) -> None:
    job_type = item.get("JobType") or ""
    job_fn = JOB_CATALOG.get(job_type)
    started = utcnow()
    run = sp.add_item(JOBRUNS_LIST, {
        "Title": run_id,
        "JobTitle": item.get("Title") or "(untitled)",
        "JobStatus": "Running",
        "RunBy": who[:250],
        "StartedUtc": iso(started),
    })
    status, output, error = "Succeeded", "", ""
    try:
        if job_fn is None:
            raise SPError(f"Unknown JobType '{job_type}' — not in this worker's catalog")
        params = json.loads(item.get("ParametersJson") or "{}")
        output = job_fn(sp, params, {"who": who, "run_id": run_id})
        feed("✅", f"Ran **{item['Title']}** — {output}")
    except Exception as exc:  # noqa: BLE001 — a job failure must not kill the worker
        status, error = "Failed", f"{type(exc).__name__}: {exc}"
        feed("❌", f"**{item['Title']}** failed — {error}")
    sp.merge_item(JOBRUNS_LIST, run, {
        "JobStatus": status,
        "FinishedUtc": iso(utcnow()),
        "DurationMs": int((utcnow() - started).total_seconds() * 1000),
        "Output": output[:5000],
        "ErrorText": error[:5000],
    })


def poll_pass(sp: SPClient, who: str, feed) -> None:
    """One pass: find due schedules, race to claim each, run what we win."""
    due = sp.get_items(
        SCHEDULES_LIST, f"Enabled eq 1 and NextRunDue le datetime'{iso(utcnow())}'"
    )
    for item in due:
        run_id = uuid.uuid4().hex[:12]
        claim_time = time.monotonic()
        if not claim_schedule(sp, item, run_id, who):
            feed("🤝", f"**{item['Title']}** was due, but another worker won the claim (412) — exactly as designed.")
            continue
        feed("🏆", f"Won the claim for **{item['Title']}** (run `{run_id}`) — executing here.")
        if time.monotonic() - claim_time > CLAIM_GRACE_SECONDS and not verify_claim(sp, item, run_id):
            feed("😴", f"Claim for **{item['Title']}** went stale (machine slept?) — aborting safely.")
            continue
        execute_claimed(sp, item, run_id, who, feed)


# ── The race proof ───────────────────────────────────────────────────────────


def race_proof(sp: SPClient, n: int) -> dict:
    """N concurrent claims against ONE etag. SharePoint must grant exactly one
    204 and reject the rest with 412 — the atomicity the pattern rests on."""
    items = sp.get_items(SCHEDULES_LIST, f"Title eq '{DEMO_SCHEDULE_TITLE}'", top=1)
    if not items:
        raise SPError("No demo schedule found — click 'Seed demo schedule' first.")
    item = sp.request("GET", items[0]["__metadata"]["uri"]).json()["d"]  # fresh etag
    etag = item["__metadata"]["etag"]

    results: list[int | None] = [None] * n
    barrier = threading.Barrier(n)

    def attempt(i: int) -> None:
        barrier.wait()  # maximize overlap: all requests fire together
        r = sp.merge_item(
            SCHEDULES_LIST, item,
            {"ClaimedBy": f"racer-{i}@{platform.node()}", "RunId": f"race-{i}"},
            etag=etag,
        )
        results[i] = r.status_code

    threads = [threading.Thread(target=attempt, args=(i,)) for i in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    fresh = sp.request("GET", item["__metadata"]["uri"]).json()["d"]
    winner = fresh.get("ClaimedBy") or "?"
    # Leave the demo schedule runnable again.
    sp.merge_item(SCHEDULES_LIST, fresh, {
        "ClaimedBy": "", "RunId": "", "NextRunDue": iso(utcnow()),
    })
    return {"etag": etag, "results": results, "winner": winner,
            "wins": sum(1 for c in results if c == 204)}


# ── Provision / seed ─────────────────────────────────────────────────────────


def provision(sp: SPClient) -> None:
    """Idempotent: a GET per list, creating only what's missing — safe to run
    on every connect, which is what lets end users skip setup entirely."""
    try:
        sp.ensure_list(SCHEDULES_LIST, SCHEDULES_FIELDS)
        sp.ensure_list(JOBRUNS_LIST, JOBRUNS_FIELDS)
    except SPError as exc:
        if "403" in str(exc):
            raise SPError(
                "The coordination lists don't exist yet and your account can't "
                "create lists on this site. Ask the app owner to connect once first."
            ) from exc
        raise


def seed(sp: SPClient, site_url: str) -> str:
    site_rel = urlsplit(site_url).path.rstrip("/")
    fields = {
        "JobType": "weather-to-json",
        "ParametersJson": json.dumps({
            "latitude": 47.6062,
            "longitude": -122.3321,
            "label": "Seattle, WA",
            "targetFolder": f"{site_rel}/Sample Sites/euda-worker_data",
            "targetFile": "latest.json",
        }),
        "IntervalMinutes": 15,
        "NextRunDue": iso(utcnow()),  # due immediately
        "ClaimedBy": "",
        "RunId": "",
        "Enabled": True,
    }
    existing = sp.get_items(SCHEDULES_LIST, f"Title eq '{DEMO_SCHEDULE_TITLE}'", top=1)
    if existing:
        sp.merge_item(SCHEDULES_LIST, existing[0], fields)
        return f"Reset demo schedule '{DEMO_SCHEDULE_TITLE}' — due now."
    sp.add_item(SCHEDULES_LIST, {"Title": DEMO_SCHEDULE_TITLE, **fields})
    return f"Created demo schedule '{DEMO_SCHEDULE_TITLE}' — due now."


# ── Streamlit UI ─────────────────────────────────────────────────────────────


@st.cache_resource
def get_sp(site: str) -> SPClient:
    return SPClient(site)


def add_feed(icon: str, msg: str) -> None:
    st.session_state.feed.insert(0, (datetime.now().strftime("%H:%M:%S"), icon, msg))
    del st.session_state.feed[50:]


def render_schedules(sp: SPClient) -> None:
    rows = []
    for it in sp.get_items(SCHEDULES_LIST, orderby="Title"):
        due = parse_sp_dt(it.get("NextRunDue"))
        if not it.get("Enabled"):
            state = "⏸️ disabled"
        elif due and due <= utcnow():
            state = "🔴 due now"
        elif due and due <= utcnow() + timedelta(minutes=5):
            state = "🟡 due soon"
        else:
            state = "🟢 scheduled"
        rows.append({
            "Schedule": it.get("Title") or "",
            "Job type": it.get("JobType") or "",
            "Every (min)": int(it.get("IntervalMinutes") or 0),
            "Next due (UTC)": (it.get("NextRunDue") or "").replace("T", " ").replace("Z", ""),
            "State": state,
            "Last claimed by": (it.get("ClaimedBy") or "—")[:70],
        })
    if rows:
        st.dataframe(rows, width="stretch", hide_index=True)
    else:
        st.info("No schedules defined yet — seed the demo schedule from the sidebar.")


def render_runs(sp: SPClient) -> None:
    icons = {"Succeeded": "✅", "Failed": "❌", "Running": "🏃"}
    rows = []
    for r in sp.get_items(JOBRUNS_LIST, top=15, orderby="Id desc"):
        rows.append({
            "Run": r.get("Title") or "",
            "Job": r.get("JobTitle") or "",
            "Status": f"{icons.get(r.get('JobStatus') or '', '•')} {r.get('JobStatus') or ''}",
            "Run by": (r.get("RunBy") or "")[:70],
            "Started (UTC)": (r.get("StartedUtc") or "").replace("T", " ").replace("Z", ""),
            "ms": int(r.get("DurationMs") or 0),
        })
    if rows:
        st.dataframe(rows, width="stretch", hide_index=True)
    else:
        st.info("No runs yet — once a schedule comes due, the winning worker will log one here.")


def render_metrics(sp: SPClient) -> None:
    schedules = sp.get_items(SCHEDULES_LIST)
    runs = sp.get_items(JOBRUNS_LIST, top=200, orderby="Id desc")
    day_ago = utcnow() - timedelta(hours=24)
    recent = [r for r in runs if (parse_sp_dt(r.get("StartedUtc")) or day_ago) > day_ago]
    workers = {(r.get("RunBy") or "").split(" via ")[-1] for r in recent if r.get("RunBy")}
    next_due = min(
        (parse_sp_dt(s.get("NextRunDue")) for s in schedules
         if s.get("Enabled") and parse_sp_dt(s.get("NextRunDue"))),
        default=None,
    )
    if next_due:
        mins = (next_due - utcnow()).total_seconds() / 60
        due_txt = "due now" if mins <= 0 else f"in {mins:.0f} min"
    else:
        due_txt = "—"
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Active schedules", sum(1 for s in schedules if s.get("Enabled")))
    c2.metric("Next run", due_txt)
    c3.metric("Runs (24 h)", f"{sum(1 for r in recent if r.get('JobStatus') == 'Succeeded')} ✓ / "
                             f"{sum(1 for r in recent if r.get('JobStatus') == 'Failed')} ✗")
    c4.metric("Machines that ran jobs (24 h)", len(workers))


def main() -> None:
    st.set_page_config(page_title="EUDA Worker", page_icon="🛰️", layout="wide")
    st.session_state.setdefault("feed", [])
    st.session_state.setdefault("connected", False)
    st.session_state.setdefault("who", "")
    st.session_state.setdefault("race", None)

    st.title("🛰️ EUDA Worker")
    st.caption("Server automation with no server — this browser tab is one worker in the pool.")

    with st.expander("How it works (60-second version)"):
        st.markdown(
            """
1. **Jobs live in SharePoint**, as items in the **EUDA Schedules** list — what to run, how often, and when it's next due.
2. **Everyone who keeps this app open is a worker.** Every minute or so, each worker checks for due jobs.
3. **Only one worker can win each run.** Claiming a job is a single conditional write — SharePoint accepts exactly one
   and answers every other worker with *412 Precondition Failed*. No locks, no server, nothing to clean up.
4. **Every run is logged** to the **EUDA JobRuns** list — who ran it, when, how long, what happened. The
   `euda-worker-status.aspx` page shows the same thing to anyone on SharePoint.
5. **Close the tab and you simply leave the pool.** As long as *someone* has it open, the automation runs.

*Try the “Race proof” in the sidebar to watch step 3 happen for real.*
            """
        )

    # ── Sidebar: connection + controls ──
    site = st.sidebar.text_input("SharePoint site", DEFAULT_SITE)
    sp = get_sp(site)
    st.sidebar.link_button(
        "📊 Pool status page (SharePoint)",
        site.rstrip("/") + "/Sample%20Sites/euda-worker-status.aspx",
        width="stretch",
        help="Read-only dashboard of schedules, runs, and active workers — "
             "for anyone, without running this app.",
    )

    if not st.session_state.connected:
        st.sidebar.info("Not connected yet.")
        if st.sidebar.button("🔐 Sign in & join the pool", type="primary", width="stretch"):
            with st.spinner("Signing in (a browser window may open) and preparing lists…"):
                provision(sp)
                st.session_state.who = sp.whoami()
                st.session_state.connected = True
                add_feed("🔌", f"Connected as **{st.session_state.who}** — lists verified.")
            st.rerun()
        st.info("⬅️ Click **Sign in & join the pool** to connect. First run opens a browser sign-in; "
                "afterwards it's silent (token cached securely for this Windows account).")
        return

    st.sidebar.success(f"Connected\n\n{st.session_state.who}")
    worker_on = st.sidebar.toggle("Worker active", value=True,
                                  help="While on (and this tab is open), this machine polls for due jobs.")
    interval = st.sidebar.slider("Poll every (seconds)", 30, 180, 60, step=15)

    st.sidebar.divider()
    st.sidebar.markdown("**Owner tools**")
    if st.sidebar.button("🌱 Seed demo schedule", width="stretch",
                         help="Create/reset the demo weather job, due immediately."):
        add_feed("🌱", seed(sp, site))
        st.rerun()
    n_racers = st.sidebar.number_input("Racers", 2, 10, 5,
                                       help="Concurrent claim attempts for the proof.")
    if st.sidebar.button("🏁 Run race proof", width="stretch",
                         help="Fire N simultaneous claims at one etag — exactly one must win."):
        with st.spinner(f"Racing {n_racers} concurrent claims…"):
            st.session_state.race = race_proof(sp, int(n_racers))
        add_feed("🏁", f"Race proof: {st.session_state.race['wins']} winner out of {n_racers} racers.")
        st.rerun()

    # ── Race proof results (the visual centerpiece) ──
    if st.session_state.race:
        res = st.session_state.race
        n = len(res["results"])
        st.subheader("🏁 Race proof — one etag, simultaneous claims")
        st.caption(f"All {n} workers tried to claim the same run at etag {res['etag']} at the same instant.")
        cols = st.columns(n)
        for i, (col, code) in enumerate(zip(cols, res["results"])):
            with col:
                if code == 204:
                    st.success(f"**racer-{i}**\n\nHTTP 204\n\n🏆 WON")
                else:
                    st.warning(f"**racer-{i}**\n\nHTTP {code}\n\n412 — lost")
        if res["wins"] == 1:
            st.success(f"**PROOF HOLDS** — {n} simultaneous claims, exactly 1 winner "
                       f"(`{res['winner']}`), {n - 1} × 412. The claim is atomic; "
                       "no job can ever run twice from one tick.")
        else:
            st.error(f"**PROOF FAILED** — {res['wins']} winners. Do not trust this pattern "
                     "until investigated.")
        st.divider()

    # ── Live status (auto-refreshing fragment; also does the actual work) ──
    @st.fragment(run_every=interval if worker_on else 30)
    def live() -> None:
        if worker_on:
            try:
                poll_pass(sp, st.session_state.who, add_feed)
            except Exception as exc:  # noqa: BLE001 — keep the UI alive; surface the error
                add_feed("⚠️", f"Poll error: {exc}")
        try:
            render_metrics(sp)
            left, right = st.columns([3, 2])
            with left:
                st.subheader("Schedules")
                render_schedules(sp)
                st.subheader("Recent runs")
                render_runs(sp)
            with right:
                st.subheader("This worker's activity")
                st.caption(("Polling every %ds — leave this tab open to stay in the pool."
                            % interval) if worker_on else "Worker paused — display only.")
                if not st.session_state.feed:
                    st.info("Nothing yet — waiting for the first poll.")
                for ts, icon, msg in st.session_state.feed:
                    st.markdown(f"`{ts}` {icon} {msg}")
        except Exception as exc:  # noqa: BLE001
            st.error(f"Could not load status: {exc}")

    live()


def colour_supported() -> bool:
    """Can we write ANSI colour to this terminal without leaving garbage?

    Honours the NO_COLOR / FORCE_COLOR conventions. On Windows, console
    virtual-terminal processing is off by default and has to be switched on,
    which is what the ctypes call does - if that fails we fall back to plain
    text rather than printing escape sequences at the operator.
    """
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    if not sys.stdout.isatty():
        return False
    if os.name != "nt":
        return True
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        mode = ctypes.c_uint32()
        if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            return False
        # ENABLE_VIRTUAL_TERMINAL_PROCESSING
        return bool(kernel32.SetConsoleMode(handle, mode.value | 0x0004))
    except Exception:
        return False


def print_banner() -> None:
    """Announce startup and, loudly, how to stop the app again.

    Deliberately ASCII only - cmd.exe runs under a legacy code page where box
    drawing characters come out as mojibake.
    """
    use_colour = colour_supported()

    def paint(text: str, *codes: str) -> str:
        if not use_colour or not codes:
            return text
        return "\033[" + ";".join(codes) + "m" + text + "\033[0m"

    rule = paint("=" * 66, "36")
    print()
    print(rule)
    print("  " + paint("EUDA WORKER", "1", "96"))
    print(rule)
    print()
    print("  Starting up - this opens in your browser in a few seconds.")
    print()
    print("  " + paint(" TO STOP THE APP ", "1", "30", "103")
          + "  press " + paint("Ctrl-C", "1", "93") + " here, or close this window.")
    print()
    print("  Closing the browser tab alone does "
          + paint("NOT", "1", "91") + " stop it.")
    print()
    print(rule)
    print()


if __name__ == "__main__":
    from streamlit import runtime
    if runtime.exists():
        main()
    else:
        import sys
        from pathlib import Path

        # First-run hygiene, applied before the Streamlit runtime starts:
        # - pre-seed credentials.toml so Streamlit never shows its
        #   "Welcome / Email:" prompt to end users
        # - no usage-stats telemetry off the machine
        # - toolbar in viewer mode: hides the "Deploy" button and developer
        #   menu items (Streamlit Community Cloud is not appropriate here)
        creds = Path.home() / ".streamlit" / "credentials.toml"
        if not creds.exists():
            creds.parent.mkdir(parents=True, exist_ok=True)
            creds.write_text('[general]\nemail = ""\n', encoding="utf-8")
        os.environ.setdefault("STREAMLIT_BROWSER_GATHER_USAGE_STATS", "false")
        os.environ.setdefault("STREAMLIT_CLIENT_TOOLBAR_MODE", "viewer")
        # The file watcher exists to hot-reload the source while a developer
        # is editing it. A released app.py never changes while an operator is
        # running it, so the watcher has nothing to watch - and leaving it on
        # prints an "install the Watchdog module" nag at the end user.
        os.environ.setdefault("STREAMLIT_SERVER_FILE_WATCHER_TYPE", "none")

        # Newer Streamlit shows an in-app "Help agents write better apps /
        # Install the official Streamlit skills" dialog on any machine with an
        # AI coding agent installed. There is no config option for it - the
        # only supported switch is the marker file its own "Don't show again"
        # button writes, so write it. Best effort: never block startup.
        try:
            from streamlit.web import skills as _skills
            _skills.write_nudge_dismissed_marker()
        except Exception:
            try:
                marker = Path.home() / ".streamlit" / ".skills_nudge_dismissed"
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.touch(exist_ok=True)
            except OSError:
                pass

        print_banner()

        from streamlit.web import cli as stcli
        sys.argv = ["streamlit", "run", sys.argv[0], "--server.address", "localhost"]
        sys.exit(stcli.main())
