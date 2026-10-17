"""Validate the complete eight-format export without third-party dependencies."""
import argparse
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.refs, self.ids, self.lang = [], set(), None
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a" and "name" in attrs:
            self.ids.add(attrs["name"])
        if tag == "html":
            self.lang = attrs.get("lang")
        self.refs.extend(attrs[k] for k in ("href", "src") if k in attrs)


def validate(root, project):
    root = root.resolve()
    pages = {}
    errors = []
    paths = [root / "index.html", root / "coverage.html"]
    paths += list((root / "units").glob("*.html"))
    paths += list((root / "_chm_html").rglob("*.html"))
    for path in paths:
        pages[path] = Page(path.read_text(encoding="utf-8-sig"))
        if pages[path].lang != "en":
            errors.append(f"Unexpected HTML language: {path}")
    refs = 0
    for path, page in pages.items():
        for ref in page.refs:
            url = urlsplit(ref)
            if url.scheme or url.netloc:
                continue
            refs += 1
            dest = (path.parent / unquote(url.path)).resolve() if url.path else path
            if not dest.is_file():
                errors.append(f"Missing HTML target: {path.name}: {ref}")
            elif url.fragment and dest in pages and unquote(url.fragment) not in pages[dest].ids:
                errors.append(f"Missing HTML anchor: {path.name}: {ref}")
    md_paths = list(root.glob("*.md")) + list((root / "units").glob("*.md"))
    for site in ("mkdocs", "docusaurus", "vitepress"):
        md_paths += list((root / f"site-{site}" / "docs").glob("*.md"))
        md_paths += list((root / f"site-{site}" / "docs" / "units").glob("*.md"))
    for path in md_paths:
        for ref in re.findall(r"\[[^\]\n]*\]\(([^\)\n]+)\)", path.read_text(encoding="utf-8-sig")):
            url = urlsplit(ref)
            if url.scheme or url.netloc or not url.path:
                continue
            dest = path.parent / unquote(url.path)
            if not dest.is_file() and not Path(str(dest) + ".md").is_file():
                errors.append(f"Missing Markdown target: {path}: {ref}")
    api = json.loads((root / "api.json").read_text(encoding="utf-8-sig"))
    if api["project"] != project:
        errors.append("Incorrect JSON project name")
    for suffix in ("hhp", "hhc", "hhk", "chm"):
        if not (root / f"{project}.{suffix}").is_file():
            errors.append(f"Missing CHM resource: {project}.{suffix}")
    hhp = (root / f"{project}.hhp").read_text(encoding="utf-8-sig")
    for name in hhp.split("[FILES]", 1)[1].splitlines():
        if name.strip() and not (root / name.strip().replace("\\", "/")).is_file():
            errors.append(f"Missing CHM project file: {name}")
    if (root / f"{project}.chm").read_bytes()[:4] != b"ITSF":
        errors.append("Invalid CHM signature")
    mkdocs = (root / "site-mkdocs/mkdocs.yml").read_text(encoding="utf-8-sig")
    if f'site_name: "{project}"' not in mkdocs or "language: en" not in mkdocs:
        errors.append("Incorrect MkDocs name or locale")
    for site in ("docusaurus", "vitepress"):
        folder = root / f"site-{site}"
        package = folder / "package.json"
        json.loads(package.read_text(encoding="utf-8"))  # Reject a BOM as Node does.
        config = folder / ("docusaurus.config.js" if site == "docusaurus" else "docs/.vitepress/config.mts")
        if f'title: "{project}"' not in config.read_text(encoding="utf-8"):
            errors.append(f"Incorrect site title: {site}")
    for name in ("site-mkdocs/requirements.txt", "site-mkdocs/docs/index.md", "site-vitepress/docs/index.md", f"hmxp/{project}.hmxp"):
        if not (root / name).is_file():
            errors.append(f"Missing project resource: {name}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(pages)} HTML pages, {refs} local HTML references, {len(md_paths)} Markdown files, project names and site resources")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--project", default="skia_vcl_canvas")
    args = parser.parse_args()
    validate(args.output, args.project)
