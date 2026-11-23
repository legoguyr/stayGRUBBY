"""Render the Terms of Use and Community Guidelines drafts for owner review, never for publication.

Usage: python3 Website/preview_legal.py OUTPUT_DIR
Writes terms.html and community-guidelines.html (plus the stylesheet) with the same page shell as the
live Privacy page. OUTPUT_DIR must be outside Website/public, and the production build does not read
Legal/: publishing needs the separate, owner-approved activation change (Website/README.md).
"""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
PAGES = [("TermsOfUse.md", "terms.html", "Terms of Use — StayGrubby", "/terms"),
         ("CommunityGuidelines.md", "community-guidelines.html", "Community Guidelines — StayGrubby", "/community-guidelines")]


def main(output):
    output = Path(output).resolve()
    public = (ROOT / "Website/public").resolve()
    if output == public or public in output.parents:
        raise SystemExit("Refusing to write drafts into Website/public")
    (output / "assets").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "Website/site.css", output / "assets/site.css")
    shutil.copytree(build.BRAND, output / "assets/brand", dirs_exist_ok=True)
    for source, name, title, route in PAGES:
        text = (ROOT / "Legal" / source).read_text(encoding="utf-8")
        html = build.page(title, route, '<article class="policy">\n' + build.policy_html(text) + "\n</article>", "reading")
        (output / name).write_text(html.replace("<title>", '<meta name="robots" content="noindex,nofollow"><title>', 1), encoding="utf-8")
        print(output / name)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
