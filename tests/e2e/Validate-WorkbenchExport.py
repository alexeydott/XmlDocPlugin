"""Validate the fixed workbench fixture hierarchy and numeric export resources."""
import sys,json,re
from pathlib import Path
import xml.etree.ElementTree as ET
r=Path(sys.argv[1]); expected=['Workbench.Contracts','Workbench.Examples','Workbench.Sample','Workbench.Second']
nav=json.loads((r/'site-mkdocs/navigation.json').read_text('utf-8-sig'))
assert [n['text'] for n in nav['items']]==expected
for site in ['docusaurus','vitepress']:
 assert json.loads((r/f'site-{site}/navigation.json').read_text('utf-8-sig'))==nav
contracts=nav['items'][0];assert [n['text'] for n in contracts['items']]==['Classes','Interfaces']
base=contracts['items'][0]['items'][0];assert base['text']=='TDocumentedBase'
assert [n['text'] for n in base['items']]==['Fields','Methods','Properties']
assert nav['items'][1]['items'][0]['text']=='Routines'
def walk(n):
 if 'link' in n:
  for site in ['mkdocs','docusaurus','vitepress']:
   link=n['link'].split('#')[0].lstrip('/');assert (r/f'site-{site}/docs'/f'{link}.md').is_file(),link
 for c in n.get('items',[]):walk(c)
walk(nav)
for path in [r/'index.html',r/'XmlDocE2E.hhc',r/'SUMMARY.md',r/'_sidebar.md']:
 s=path.read_text('utf-8-sig');assert all(label in s for label in expected+['Classes','Interfaces','Methods','Properties','Fields','Routines']),path
root=ET.parse(r/'hmxp/Maps/table_of_contents.xml').getroot(); project=root.find('topicref');assert project.findtext('caption')=='XmlDocE2E'
assert [n.findtext('caption') for n in project.findall('topicref')]==expected
contract=project.findall('topicref')[0];assert [n.findtext('caption') for n in contract.findall('topicref')]==['Classes','Interfaces']
api=json.loads((r/'api.json').read_text('utf-8-sig'));assert [u['name'] for u in api['units']]==expected
mapping=json.loads((r/'topic-map.json').read_text('utf-8-sig'));assert all(re.fullmatch(r't\d{6}',v) for v in mapping.values())
assert all(re.fullmatch(r't\d{6}',p.stem) for p in (r/'units').glob('*.html'))
for site in ['mkdocs','docusaurus','vitepress']:
 assert json.loads((r/f'site-{site}/docs/topic-map.json').read_text('utf-8-sig'))==mapping
for folder in [r/'assets',r/'_chm_html/assets']+[r/f'site-{s}/docs/assets' for s in ['mkdocs','docusaurus','vitepress']]:
 assert list(folder.glob('*.png')),folder
 assert list(folder.glob('*.pas')),folder
assert list((r/'hmxp/Images').glob('*.png'))
assert list((r/'hmxp/Baggage').glob('*.pas'))
print('PASS grouping by units/types/members, site navigation targets, JSON hierarchy, numeric names and image/example resources:',r)
