import {JSDOM} from 'jsdom';import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,readdirSync} from 'node:fs';import {load} from './load.mjs';
test('Russian and Chinese UI switch without changing document text, selectors or event handlers',async()=>{
 const dom=new JSDOM('<html><body><h3 class="doc-heading">Summary</h3><button title="Recover drafts" aria-label="Recover drafts">Recover drafts</button><select><option>All symbols</option></select><input placeholder="Find symbol or documentation"><div class="tiptap" contenteditable="true">Summary</div><div id="tree-content"><button>Summary</button></div></body></html>');
 for(const k of ['window','document','MutationObserver','CustomEvent'])globalThis[k]=dom.window[k];
 const {setLanguage,resolveLanguage,localizeUi}=load('i18n.ts');let clicks=0;document.querySelector('button').onclick=()=>clicks++;
 const ru=JSON.parse(readFileSync(new URL('../../resources/locales/ru.json',import.meta.url),'utf8')),zh=JSON.parse(readFileSync(new URL('../../resources/locales/zh.json',import.meta.url),'utf8'));
 assert.deepEqual(Object.keys(ru).sort(),Object.keys(zh).sort());assert.ok(Object.keys(ru).length>180);for(const [key,value] of Object.entries(ru)){const tokens=t=>t.match(/\{\d+\}/g)??[];assert.deepEqual(tokens(value),tokens(key));assert.deepEqual(tokens(zh[key]),tokens(key));}
 assert.equal(resolveLanguage('ru-RU'),'ru');assert.equal(resolveLanguage('zh-Hans'),'zh');assert.equal(resolveLanguage('fr-FR'),'en');
 for(const [code,pack] of [['ru',ru],['zh-CN',zh],['en',{}]]){setLanguage(code);assert.equal(document.querySelector('h3').textContent,pack.Summary??'Summary');assert.equal(document.querySelector('button').title,pack['Recover drafts']??'Recover drafts');assert.equal(document.querySelector('select').value,'All symbols');assert.equal(document.querySelector('.tiptap').textContent,'Summary');assert.equal(document.querySelector('#tree-content button').textContent,'Summary');document.querySelector('button').click();}
 assert.equal(clicks,3);setLanguage('zh');const dynamic=document.createElement('button');dynamic.textContent='Save terminology';document.body.append(dynamic);await new Promise(r=>setTimeout(r,0));assert.equal(dynamic.textContent,zh['Save terminology']);
 const codeOption=document.createElement('option');codeOption.dataset.code='';codeOption.textContent='Value';document.querySelector('select').append(codeOption);setLanguage('ru');localizeUi();assert.equal(codeOption.textContent,'Value');
 let seed=16;for(let i=0;i<1000;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;setLanguage(['en','ru','zh'][seed%3]);localizeUi();assert.equal(document.querySelector('.tiptap').textContent,'Summary');assert.equal(document.querySelector('select').value,'All symbols');}
 dom.window.close();
});

test('native and browser control captions and tooltips have complete bundled translations',()=>{
 const ru=JSON.parse(readFileSync(new URL('../../resources/locales/ru.json',import.meta.url),'utf8'));
 const zh=JSON.parse(readFileSync(new URL('../../resources/locales/zh.json',import.meta.url),'utf8'));
 const technical=new Set(['XmlDoc Plugin','DelphiAST','ProseMirror','TipTap Editor','Vite','vite-plugin-singlefile']);
 const check=text=>{if(ru[text] && zh[text])return;text=text.trim();if(!/[A-Za-z]{3}/.test(text)||technical.has(text)||text.startsWith('<a href='))return;
  assert.ok(ru[text],`Missing Russian UI text: ${text}`);assert.ok(zh[text],`Missing Chinese UI text: ${text}`);
 };
 for(const file of readdirSync(new URL('../../src/Plugin/',import.meta.url)).filter(f=>f.endsWith('.dfm'))){
  const source=readFileSync(new URL('../../src/Plugin/'+file,import.meta.url),'utf8');
  for(const match of source.matchAll(/(?:Caption|Hint) = '([^']+)'/g))check(match[1]);
 }
 for(const file of readdirSync(new URL('../../src/Plugin/',import.meta.url)).filter(f=>f.endsWith('.pas'))){
  const source=readFileSync(new URL('../../src/Plugin/'+file,import.meta.url),'utf8');
  for(const match of source.matchAll(/\.(?:Caption|Hint|TextHint)\s*:=\s*(?:TI18n\.Instance\.T\()?\s*'([^']+)'/g))check(match[1]);
 }
 for(const file of ['index.html','explorer.html']){
  const dom=new JSDOM(readFileSync(new URL('../'+file,import.meta.url),'utf8'));
  for(const el of dom.window.document.querySelectorAll('[title],[placeholder],[aria-label],button,option,.doc-heading,summary,label')){
   for(const attr of ['title','placeholder','aria-label'])if(el.hasAttribute(attr))check(el.getAttribute(attr));
   if(!el.children.length)check(el.textContent);
  }
  dom.window.close();
 }
});
test('dynamic UI templates preserve identifiers, paths and source prose when languages change',()=>{
 const dom=new JSDOM('<body><p>Documentation checks passed.</p><div class="symbol-caption">Summary</div><div id="tree-content"><div class="tree-empty">Open a .pas file to see the structure</div><span class="tree-label">Summary</span></div><button title="Open source: TWorker.Run&lt;T&gt;">Open source</button><textarea aria-label="Summary for TWorker.Run&lt;T&gt;"></textarea></body>');
 for(const k of ['window','document','MutationObserver','CustomEvent'])globalThis[k]=dom.window[k];
 const ui=load('i18n.ts');
 for(const code of ['ru','zh','en','zh','ru']){
  ui.setLanguage(code);ui.localizeUi();
  assert.equal(document.querySelector('.symbol-caption').textContent,'Summary');assert.equal(document.querySelector('.tree-label').textContent,'Summary');
  assert.ok(document.querySelector('button').title.endsWith('TWorker.Run<T>'));
  assert.ok(document.querySelector('textarea').getAttribute('aria-label').includes('TWorker.Run<T>'));
  if(code!=='en'){assert.notEqual(document.querySelector('p').textContent,'Documentation checks passed.');assert.notEqual(document.querySelector('.tree-empty').textContent,'Open a .pas file to see the structure');assert.ok(!document.querySelector('button').title.startsWith('Open source:'));}
  assert.ok(ui.translate('Unknown param Value').includes('param'));assert.ok(ui.translate('Unknown param Value').includes('Value'));
 }
 dom.window.close();
});
