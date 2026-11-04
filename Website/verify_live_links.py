"""Read-only post-deployment guard: real public HTTP, not only handler unit tests."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

def verify():
    uid = "11111111-1111-4111-8111-111111111111"
    paths = ["/@review_cook", "/%40review_cook", f"/r/{uid}", f"/p/{uid}", f"/p/{uid}/recipe"]
    evidence = []
    with tempfile.TemporaryDirectory(prefix="staygrubby-public-http-") as tmp:
        for path in paths + ["/r/bad", "/", "/privacy", "/support", "/.well-known/apple-app-site-association", "/apple-app-site-association"]:
            for method in ["GET", "HEAD"]:
                header, body = Path(tmp)/"headers", Path(tmp)/"body"
                args = ["curl", "-sS", "--connect-timeout", "8", "--max-time", "20", "--dump-header", str(header), "--output", str(body),
                        "--user-agent", "Mozilla/5.0 (iPhone) AppleWebKit/605.1.15 Version/26.5 Mobile Safari/604.1"]
                if method == "HEAD": args += ["--head"]
                result = subprocess.run(args + ["https://staygrubby.com"+path], check=True, capture_output=True)
                lines = header.read_text().splitlines()
                status = int(lines[0].split()[1])
                headers = {k.lower():v.strip() for line in lines[1:] if ":" in line for k,v in [line.split(":",1)]}
                assert status == (404 if path == "/r/bad" else 200), (path, method, status)
                assert "location" not in headers and "attachment" not in headers.get("content-disposition", "").lower(), (path, method)
                association = "apple-app-site-association" in path
                assert headers.get("content-type", "").startswith("application/json" if association else "text/html"), (path, method, headers.get("content-type"))
                if path in paths or path == "/r/bad":
                    assert headers.get("content-disposition") == "inline"
                    assert headers.get("cache-control") == "no-store"
                if method == "GET":
                    data = body.read_bytes()
                    if association:
                        assert json.loads(data) == json.loads((Path(__file__).parent/"association.json").read_text())
                    elif path in paths:
                        html = data.decode()
                        assert "Open StayGrubby" in html and "staygrubby://open" in html
                        assert "<script" not in html and "supabase" not in html.lower()
                    evidence.append({"path":path,"status":status,"type":headers.get("content-type"),"disposition":headers.get("content-disposition"),"sha256":hashlib.sha256(data).hexdigest()})
    return evidence

if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--report", type=Path); args = parser.parse_args()
    rows = verify()
    if args.report: args.report.write_text(json.dumps(rows, indent=2))
    print(f"PASS {len(rows)*2} hosted GET/HEAD checks: HTML, headers, no redirects, generic pointers and matching association files")
