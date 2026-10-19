import {JSDOM} from 'jsdom';import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,readdirSync} from 'node:fs';import {load} from './load.mjs';
test('Four bundled languages UI switch without changing document text, selectors or event handlers',async()=>{
 const dom=new JSDOM('<html><body><h3 class="doc-heading">Summary</h3><button title="Recover drafts" aria-label="Recover drafts">Recover drafts</button><select><option>All symbols</option></select><input placeholder="Find symbol or documentation"><div class="tiptap" contenteditable="true">Summary</div><div id="tree-content"><button>Summary</button></div></body></html>');
 for(const k of ['window','document','MutationObserver','CustomEvent'])globalThis[k]=dom.window[k];
 const {setLanguage,resolveLanguage,localizeUi}=load('i18n.ts');let clicks=0;document.querySelector('button').onclick=()=>clicks++;
 const ru=JSON.parse(readFileSync(new URL('../../resources/locales/ru.json',import.meta.url),'utf8')),zh=JSON.parse(readFileSync(new URL('../../resources/locales/zh.json',import.meta.url),'utf8'));
 assert.deepEqual(Object.keys(ru).sort(),Object.keys(zh).sort());assert.ok(Object.keys(ru).length>180);for(const [key,value] of Object.entries(ru)){const tokens=t=>t.match(/\{\d+\}/g)??[];assert.deepEqual(tokens(value),tokens(key));assert.deepEqual(tokens(zh[key]),tokens(key));}
 assert.equal(resolveLanguage('ru-RU'),'ru');assert.equal(resolveLanguage('zh-Hans'),'zh');assert.equal(resolveLanguage('fr-FR'),'en');
 const ko=JSON.parse(readFileSync(new URL('../../resources/locales/ko.json',import.meta.url),'utf8')),ja=JSON.parse(readFileSync(new URL('../../resources/locales/ja.json',import.meta.url),'utf8'));
 assert.equal(resolveLanguage('ko-KR'),'ko');assert.equal(resolveLanguage('ja_JP'),'ja');
 for(const [code,pack] of [['ru',ru],['zh-CN',zh],['ko-KR',ko],['ja_JP',ja],['en',{}]]){setLanguage(code);assert.equal(document.querySelector('h3').textContent,pack.Summary??'Summary');assert.equal(document.querySelector('button').title,pack['Recover drafts']??'Recover drafts');assert.equal(document.querySelector('select').value,'All symbols');assert.equal(document.querySelector('.tiptap').textContent,'Summary');assert.equal(document.querySelector('#tree-content button').textContent,'Summary');document.querySelector('button').click();}
 assert.equal(clicks,5);setLanguage('zh');const dynamic=document.createElement('button');dynamic.textContent='Save terminology';document.body.append(dynamic);await new Promise(r=>setTimeout(r,0));assert.equal(dynamic.textContent,zh['Save terminology']);
 const codeOption=document.createElement('option');codeOption.dataset.code='';codeOption.textContent='Value';document.querySelector('select').append(codeOption);setLanguage('ru');localizeUi();assert.equal(codeOption.textContent,'Value');
 let seed=16;for(let i=0;i<1000;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;setLanguage(['en','ru','zh','ko','ja'][seed%5]);localizeUi();assert.equal(document.querySelector('.tiptap').textContent,'Summary');assert.equal(document.querySelector('select').value,'All symbols');}
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
 for(const code of ['ru','zh','ko','ja','en','ja','ko','zh','ru']){
  ui.setLanguage(code);ui.localizeUi();
  assert.equal(document.querySelector('.symbol-caption').textContent,'Summary');assert.equal(document.querySelector('.tree-label').textContent,'Summary');
  assert.ok(document.querySelector('button').title.endsWith('TWorker.Run<T>'));
  assert.ok(document.querySelector('textarea').getAttribute('aria-label').includes('TWorker.Run<T>'));
  if(code!=='en'){assert.notEqual(document.querySelector('p').textContent,'Documentation checks passed.');assert.notEqual(document.querySelector('.tree-empty').textContent,'Open a .pas file to see the structure');assert.ok(!document.querySelector('button').title.startsWith('Open source:'));}
  assert.ok(ui.translate('Unknown param Value').includes('param'));assert.ok(ui.translate('Unknown param Value').includes('Value'));
 }
 dom.window.close();
});

test('all four embedded dictionaries cover the same keys and preserve format arguments and XML names',()=>{
 const locales=['ru','zh','ko','ja'].map(code=>[code,JSON.parse(readFileSync(new URL('../../resources/locales/'+code+'.json',import.meta.url),'utf8'))]);
 const keys=Object.keys(locales[0][1]).sort();
 for(const [code,pack] of locales){
  assert.deepEqual(Object.keys(pack).sort(),keys,code);assert.ok(keys.length>=350);
  for(const [key,value] of Object.entries(pack)){
   assert.equal(typeof value,'string');assert.ok(value.trim(),code+': '+key);
   for(const pattern of [/\{\d+\}/g,/%(?:\d+\$)?(?:\.\d+)?[dfs%]/g,/<[^>]+>/g])assert.deepEqual(value.match(pattern)??[],key.match(pattern)??[],code+': '+key);
  }
 }
 const ko=locales[2][1],ja=locales[3][1];assert.equal(ko.Summary,'요약');assert.equal(ja.Summary,'概要');
 assert.equal(ko['Recover drafts'],'초안 복구');assert.equal(ja['Recover drafts'],'下書きを復元');
 assert.equal(ko['Generate API Documentation'],'API 문서 생성');assert.equal(ja['Generate API Documentation'],'API ドキュメントの生成');
});
test('translated diagnostics, recovery and read-only messages remain UI-only across four languages',()=>{
 const dom=new JSDOM('<body><output>Read-only: IDE source buffer</output><p id="recovery">The source is read-only. The draft can be viewed but cannot be applied.</p><span id="issue">Missing result description</span><code>Read-only: IDE source buffer</code></body>');
 for(const k of ['window','document','MutationObserver','CustomEvent'])globalThis[k]=dom.window[k];
 const ui=load('i18n.ts');let seed=42;
 for(let i=0;i<500;i++){
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;const code=['ru','zh','ko','ja','en'][seed%5];ui.setLanguage(code);ui.localizeUi();
  assert.equal(document.querySelector('code').textContent,'Read-only: IDE source buffer');
  const label=document.querySelector('output').textContent;assert.equal(label==='Read-only: IDE source buffer',code==='en');
  assert.equal(document.querySelector('#issue').textContent==='Missing result description',code==='en');
  assert.equal(document.querySelector('#recovery').textContent.startsWith('The source'),code==='en');
 }
 dom.window.close();
});

test('tag reference and insertion popovers localize in all languages while preserving XML and generic names',async()=>{
 const dom=new JSDOM('<body><div id="doc-toolbar"></div></body>',{pretendToBeVisual:true});
 for(const k of ['window','document','MutationObserver','CustomEvent','HTMLElement','Element','Node','Event'])globalThis[k]=dom.window[k];
 globalThis.requestAnimationFrame=fn=>fn();globalThis.ResizeObserver=class{observe(){}disconnect(){}};
 const ui=load('i18n.ts');const toolbar=load('toolbar.ts');const help=load('helpModal.ts');
 toolbar.initToolbar();toolbar.setActiveEditor({isActive:()=>false});toolbar.updateToolbarState({params:[{name:'Summary',type:'TList<Value>'}],genericParams:['Value']});
 help.showHelpModal();const names=Array.from(document.querySelectorAll('.help-tag-name')).map(e=>e.textContent);
 const examples=Array.from(document.querySelectorAll('.help-tag-example')).map(e=>e.textContent);
 assert.equal(names.length,14);assert.ok(names.includes('<summary>'));assert.ok(names.includes('<see cref>'));
 const helpSource=readFileSync(new URL('../src/helpModal.ts',import.meta.url),'utf8');
 const helpKeys=Array.from(helpSource.matchAll(/(?:description|usage): '([^']+)'/g),m=>m[1]);
 for(const language of ['ru','zh','ko','ja','en']){
  ui.setLanguage(language);ui.localizeUi();
  const pack=language==='en'?{}:JSON.parse(readFileSync(new URL('../../resources/locales/'+language+'.json',import.meta.url),'utf8'));
  const descriptions=Array.from(document.querySelectorAll('.help-tag-desc,.help-tag-usage')).map(e=>e.textContent);
  assert.deepEqual(descriptions,helpKeys.map(key=>{if(language!=='en')assert.ok(pack[key],language+': '+key);return pack[key]??key;}));
  assert.deepEqual(Array.from(document.querySelectorAll('.help-tag-name')).map(e=>e.textContent),names);
  assert.deepEqual(Array.from(document.querySelectorAll('.help-tag-example')).map(e=>e.textContent),examples);
  document.querySelector('[data-action="paramref"]').click();ui.localizeUi();
  assert.equal(document.querySelector('.popover-item-name').textContent,'Summary');assert.equal(document.querySelector('.popover-item-type').textContent,'TList<Value>');
  document.querySelector('[data-action="typeparamref"]').click();ui.localizeUi();assert.equal(document.querySelector('.popover-list-item').textContent,'Value');
  document.querySelector('[data-action="see"]').click();ui.localizeUi();assert.equal(document.querySelector('.popover-label').textContent,pack['cref (reference target)']??'cref (reference target)');
  document.querySelector('[data-action="image"]').click();ui.localizeUi();assert.equal(document.querySelector('.popover label').firstChild.textContent,pack['Resource path relative to project']??'Resource path relative to project');
 }
 help.hideHelpModal();load('popover.ts').hidePopover();await new Promise(r=>setTimeout(r,0));dom.window.close();
});
