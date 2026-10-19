"""Validate the generated API reference before publishing it into docs/."""
from html.parser import HTMLParser
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids = set()
        self.links = []
        self.feed(text)
    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        if tag in ('a', 'link', 'script', 'img'):
            target = attrs.get('href') or attrs.get('src')
            if target:
                self.links.append(target)

def validate(root, source):
    failures = []
    pages = {p.resolve(): Page(p.read_text(encoding='utf-8-sig')) for p in root.rglob('*.html')}
    for unit in source.rglob('*.pas'):
        for extension in ('.md', '.html'):
            page = root / 'units' / (unit.stem + extension)
            if not page.is_file():
                failures.append(f'Missing unit page: {page.name}')
        md = root / 'units' / (unit.stem + '.md')
        if md.is_file() and len(md.read_text(encoding='utf-8-sig').strip().splitlines()) < 3:
            failures.append(f'Unit description missing: {unit.stem}')
    checked = set()
    def check(origin, link, anchors):
        key = (origin if not urlsplit(link).path else origin.parent, link, anchors)
        if key in checked:
            return
        checked.add(key)
        url = urlsplit(link)
        if url.scheme or url.netloc:
            return
        target = (origin.parent / unquote(url.path)).resolve() if url.path else origin.resolve()
        if not target.is_relative_to(root.resolve()) or not target.is_file():
            failures.append(f'{origin.name}: missing local resource {link}')
        elif anchors and url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
            failures.append(f'{origin.name}: missing anchor {link}')
    for filename, page in pages.items():
        for link in page.links:
            check(filename, link, True)
    for filename in root.rglob('*.md'):
        for link in re.findall(r'\]\(([^)]+)\)', filename.read_text(encoding='utf-8-sig')):
            check(filename, link, False)
    for name in ('assets/style.css', 'assets/search-index.json', 'README.md', 'SUMMARY.md', '_sidebar.md'):
        if not (root / name).is_file():
            failures.append('Missing reference resource: ' + name)
    if failures:
        raise SystemExit('\n'.join(sorted(set(failures))))
    print(f'PASS: {len(list(source.rglob("*.pas")))} units, {len(pages)} HTML pages, local resources and link anchors')

if __name__ == '__main__':
    validate(Path(sys.argv[1]), Path(sys.argv[2]))
