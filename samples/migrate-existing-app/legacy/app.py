# Illustrative "before" state for the migration example — intentionally shows
# the patterns the migration replaces. Not a runnable production app.
#
# Anti-patterns on display (all fixed by MIGRATION_PROMPT.md):
#   - hand-rolled http.server + hand-built HTML string
#   - f-string SQL built from user input (injection-prone)
#   - SQLite file cache (cache.db) instead of in-memory session state
#   - launched by a .bat that pip-installs at runtime
#
# Fictional target: Contoso "OrdersDW" warehouse on sqldev.contoso.com.
import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

# pretend driver — stand-in for the legacy ADODB/ODBC connection
import some_legacy_db_driver as db

CONN = "Server=sqldev.contoso.com;Database=OrdersDW;Trusted_Connection=yes"


def get_orders(status):
    # ANTI-PATTERN: status is interpolated straight into the SQL with an f-string.
    sql = f"""
        SELECT o.OrderId, c.CustomerName, o.Status, o.OrderTotal
        FROM Orders o
        JOIN Customers c ON c.CustomerId = o.CustomerId
        WHERE o.ActiveFlag = 1 AND c.ActiveFlag = 1
          AND o.Status = '{status}'
        ORDER BY o.OrderId
    """
    rows = db.connect(CONN).execute(sql).fetchall()

    # ANTI-PATTERN: persist results to a SQLite file so the next launch is "fast".
    cache = sqlite3.connect("cache.db")
    cache.execute("CREATE TABLE IF NOT EXISTS cache(OrderId, CustomerName, Status, OrderTotal)")
    cache.executemany("INSERT INTO cache VALUES (?,?,?,?)", rows)
    cache.commit()
    cache.close()
    return rows


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status = parse_qs(urlparse(self.path).query).get("status", ["Open"])[0]
        rows = get_orders(status)
        # ANTI-PATTERN: HTML assembled by hand in Python.
        html = "<html><body><h1>Order Status Report</h1><table>"
        for r in rows:
            html += "<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>"
        html += "</table></body></html>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))


if __name__ == "__main__":
    HTTPServer(("localhost", 8000), Handler).serve_forever()
