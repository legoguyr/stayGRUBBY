"""Read-only post-deployment guard: real public HTTP, not only handler unit tests."""
import argparse
import hashlib
from html.parser import HTMLParser
from http.client import parse_headers
import io
import json
from pathlib import Path
import subprocess
import tempfile

IPHONE_SAFARI = ("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 "
                 "(KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1")


def verify_html_headers(headers, context, worker_page=False):
    assert len(headers.get_all("Content-Type", [])) == 1, (context, "expected one content type")
    assert headers.get_content_type() == "text/html", (context, headers["Content-Type"])
    assert "Content-Disposition" not in headers, (context, "unexpected content disposition")
    if worker_page:
        assert headers.get_content_charset() == "utf-8", (context, "expected UTF-8")
        directives = {value.strip().lower() for value in headers.get("Cache-Control", "").split(",")}
        assert {"no-store", "no-transform"} <= directives, (context, "expected no-store and no-transform")


class NavigationLinks(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.links = set()
        self.href = None
        self.label = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "download" not in attrs:
            self.href = attrs.get("href")
            self.label = []

    def handle_data(self, text):
        if self.href:
            self.label.append(text)

    def handle_endtag(self, tag):
        if tag == "a" and self.href:
            self.links.add((self.href, "".join(self.label).strip()))
            self.href = None


def verify_link(html, url, label):
    assert (url, label) in NavigationLinks(html).links, (url, label, "missing navigation CTA")


def verify():
    uid = "11111111-1111-4111-8111-111111111111"
    paths = ["/@review_cook", "/%40review_cook", f"/r/{uid}", f"/p/{uid}", f"/p/{uid}/recipe", f"/r/{uid}?ref=beta_sample_123456", f"/r/{uid}?ref=%22%3Ebad"]
    unknown = "/staygrubby-unknown-check"
    not_found = {"/r/bad": "Link unavailable", unknown: "Page not found"}
    beta = json.loads(Path(__file__).with_name("distribution.json").read_text())["url"]
    is_testflight = beta.startswith("https://testflight.apple.com/")
    acquisition_label = "Join StayGrubby Beta" if is_testflight else "Download StayGrubby"
    evidence = []
    with tempfile.TemporaryDirectory(prefix="staygrubby-public-http-") as tmp:
        for path in paths + ["/beta", *not_found, "/", "/privacy", "/support", "/.well-known/apple-app-site-association", "/apple-app-site-association"]:
            for method in ["GET", "HEAD"]:
                header, body = Path(tmp)/"headers", Path(tmp)/"body"
                args = ["curl", "-sS", "--connect-timeout", "8", "--max-time", "20", "--suppress-connect-headers",
                        "--dump-header", str(header), "--output", str(body), "--write-out", "%{response_code}",
                        "--user-agent", IPHONE_SAFARI, "--header", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]
                if method == "HEAD": args += ["--head"]
                status = int(subprocess.check_output(args + ["https://staygrubby.com"+path]))
                final_headers = header.read_bytes().strip().split(b"\r\n\r\n")[-1]
                headers = parse_headers(io.BytesIO(final_headers.partition(b"\n")[2]))
                assert status == (404 if path in not_found else 200), (path, method, status)
                assert "Location" not in headers, (path, method, "unexpected redirect")
                association = "apple-app-site-association" in path
                if association:
                    assert headers.get_content_type() == "application/json", (path, method, headers["Content-Type"])
                    assert "Content-Disposition" not in headers, (path, method, "unexpected content disposition")
                else:
                    verify_html_headers(headers, (path, method), path in paths or path in ("/r/bad", "/beta"))
                if method == "GET":
                    data = body.read_bytes()
                    if association:
                        assert json.loads(data) == json.loads((Path(__file__).parent/"association.json").read_text())
                    else:
                        html = data.decode()
                        assert html.startswith("<!doctype html>") and "<main" in html, (path, "missing HTML document")
                        if path in not_found:
                            assert not_found[path] in html, (path, "missing branded 404")
                        if path == "/":
                            verify_link(html, "/beta", "Join the Beta")
                        if path == "/beta" and is_testflight:
                            assert "<h1>We’re in beta.</h1>" in html, (path, "missing beta heading")
                        if path in paths or path == "/beta":
                            verify_link(html, beta, acquisition_label)
                            if path in paths: assert "Open StayGrubby" in html and "staygrubby://open" in html
                            if "beta_sample_123456" in path: assert "?ref=beta_sample_123456" in html
                            if "%22%3Ebad" in path: assert "%22%3Ebad" not in html
                            assert "<script" not in html.lower() and "supabase" not in html.lower(), (path, "unexpected script or backend reference")
                    evidence.append({"path":path,"status":status,"type":headers.get("content-type"),"disposition":headers.get("content-disposition"),"sha256":hashlib.sha256(data).hexdigest()})
    return evidence

if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--report", type=Path); args = parser.parse_args()
    rows = verify()
    if args.report: args.report.write_text(json.dumps(rows, indent=2))
    print(f"PASS {len(rows)*2} hosted GET/HEAD checks: HTML, headers, no redirects, generic pointers and matching association files")
