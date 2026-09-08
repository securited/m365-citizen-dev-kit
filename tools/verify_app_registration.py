# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "azure-identity",
#   "httpx",
# ]
# ///
"""Verify the shared 'Contoso EUDA Applications' registration.

Answers one question: can this registration issue delegated tokens for
SharePoint REST (and Microsoft Graph) as the signed-in user? The answer
decides whether euda-worker and new packaged Python apps can use it as
their default client id, or whether IT needs to admin-consent SharePoint
delegated permissions first.

Run:   uv run tools/verify_app_registration.py
A browser window opens for Entra sign-in (normal Conditional Access flow).
Nothing is written anywhere — both probes are read-only.
"""

import base64
import json
import sys

import httpx
from azure.identity import InteractiveBrowserCredential, TokenCachePersistenceOptions

TENANT_ID = "<your-tenant-id>"
CLIENT_ID = "<your-entra-client-id>"  # Contoso EUDA Applications
SP_RESOURCE = "https://contoso.sharepoint.com"
TEST_SITE = f"{SP_RESOURCE}/sites/euda-sample"


def decode_claims(token: str) -> dict:
    """Decode the JWT payload locally (no validation — display only)."""
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def main() -> int:
    credential = InteractiveBrowserCredential(
        tenant_id=TENANT_ID,
        client_id=CLIENT_ID,
        cache_persistence_options=TokenCachePersistenceOptions(name="euda-registration-check"),
    )

    sp_ok = False
    sp_scopes = ""

    print("== SharePoint REST ==")
    try:
        token = credential.get_token(f"{SP_RESOURCE}/.default")
    except Exception as exc:
        print(f"  FAIL: could not acquire a SharePoint token.")
        print(f"        {exc}")
        print("  This usually means the registration has no SharePoint delegated")
        print("  permissions consented. Ask IT to add delegated 'AllSites.Manage'")
        print("  (SharePoint resource) to the registration and grant admin consent.")
    else:
        sp_scopes = decode_claims(token.token).get("scp", "")
        print(f"  Token acquired. Delegated scopes (scp): {sp_scopes or '(none)'}")
        resp = httpx.get(
            f"{TEST_SITE}/_api/web?$select=Title",
            headers={
                "Authorization": f"Bearer {token.token}",
                "Accept": "application/json;odata=nometadata",
            },
            timeout=30,
        )
        if resp.status_code == 200:
            sp_ok = True
            print(f"  PASS: read {TEST_SITE} as '{resp.json().get('Title')}'")
        else:
            print(f"  FAIL: token acquired but the REST probe returned HTTP {resp.status_code}")
            print(f"        {resp.text[:300]}")

    manage_scopes = ("AllSites.Manage", "AllSites.FullControl", "Sites.Manage.All", "Sites.FullControl.All")
    if sp_ok and not any(s in sp_scopes for s in manage_scopes):
        print("  NOTE: no manage-level scope in scp — list reads/writes work, but list")
        print("        auto-provisioning (worker pool first connect) may be denied.")

    print("== Microsoft Graph ==")
    try:
        gtoken = credential.get_token("https://graph.microsoft.com/.default")
    except Exception as exc:
        print(f"  WARN: could not acquire a Graph token: {exc}")
    else:
        gscopes = decode_claims(gtoken.token).get("scp", "(none)")
        print(f"  Token acquired. Delegated scopes (scp): {gscopes}")
        resp = httpx.get(
            "https://graph.microsoft.com/v1.0/me?$select=displayName",
            headers={"Authorization": f"Bearer {gtoken.token}"},
            timeout=30,
        )
        if resp.status_code == 200:
            print(f"  PASS: /me resolved to '{resp.json().get('displayName')}'")
        else:
            print(f"  WARN: Graph probe returned HTTP {resp.status_code}: {resp.text[:200]}")

    print("== Verdict ==")
    if sp_ok:
        print("  READY: the registration issues working SharePoint tokens — safe to make")
        print("  it the euda-worker default and rely on the packaged Python v1.2 guidance.")
    else:
        print("  NOT READY for SharePoint: keep euda-worker on its current default and")
        print("  ask IT to admin-consent SharePoint delegated permissions (AllSites.Manage).")
    return 0 if sp_ok else 1


if __name__ == "__main__":
    sys.exit(main())
