"""Validate the fixed workbench fixture hierarchy and numeric export resources."""
import sys,json,re
from pathlib import Path
import xml.etree.ElementTree as ET
r=Path(sys.argv[1]); expected=['Workbench.Contracts','Workbench.Examples','Workbench.Markup','Workbench.Sample','Workbench.Second']
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
markup_unit=next(u for u in api['units'] if u['name']=='Workbench.Markup')
markup_method=markup_unit['types'][0]['members'][0]['doc']
assert '<para>Paragraph one:' in markup_method['summary']
assert '<b/>' in markup_method['summary'] and '<br></br>' in markup_method['summary']
assert '<para>Second parameter paragraph.</para>' in markup_method['params'][0]['description']
def markup_page(folder,extension):
 matches=[p.read_text('utf-8-sig') for p in folder.glob('*.'+extension) if 'Paragraph one:' in p.read_text('utf-8-sig')]
 assert matches,folder
 return '\n'.join(matches)
for folder in [r/'units',r/'_chm_html/units']:
 s=markup_page(folder,'html')
 for fragment in ['<strong>bold</strong>','<strong>strong alias</strong>','<em>emphasis alias</em>','<br>','<ol>','<table>','custom reference label','First parameter paragraph.']:
  assert fragment in s,(folder,fragment)
 assert '<p><p>' not in s and '&lt;para&gt;' not in s
 assert re.search(r'<a href="[^"]+">custom reference label</a>',s)
for folder in [r/'units']+[r/f'site-{site}/docs/units' for site in ['mkdocs','docusaurus','vitepress']]:
 s=markup_page(folder,'md')
 for fragment in ['**bold**','**strong alias**','*emphasis alias*','1. Numbered first','2. Numbered second','| --- | --- |','custom reference label']:
  assert fragment in s,(folder,fragment)
 assert '****' not in s and '<para>' not in s
 assert re.search(r'\[custom reference label\]\([^)]+\)',s)
topics=[ET.parse(p).getroot() for p in (r/'hmxp/Topics').glob('*.xml') if 'Paragraph one:' in p.read_text('utf-8-sig')]
assert topics
for topic in topics:
 assert topic.findall('.//br') and topic.findall('.//table')
 assert any('font-weight:bold' in t.get('style','') for t in topic.findall('.//text'))
 assert any('font-style:italic' in t.get('style','') for t in topic.findall('.//text'))
 assert any(t.text=='custom reference label' and t.get('href') for t in topic.findall('.//link'))
print('PASS paragraphs, emphasis aliases, breaks, empty short forms, lists, tables, references and JSON markup preservation')
print('PASS grouping by units/types/members, site navigation targets, JSON hierarchy, numeric names and image/example resources:',r)
