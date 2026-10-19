import {readFileSync} from 'node:fs';import {JSDOM} from 'jsdom';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
test('custom placeholder prefixes remain unfinished in diagnostics, completeness and readiness',()=>{
 const dom=new JSDOM();for(const key of ['window','document','DOMParser','XMLSerializer','CustomEvent'])globalThis[key]=dom.window[key];
 const tools=load('docTools.ts');const element={kind:'class',name:'TWidget',params:[],genericParams:[]};
 for(const prefix of ['TODO: ','FIXME: ','Описание: ','待补充：','[draft].* ','']){
  tools.setPlaceholderPrefix(prefix);const effective=prefix.trim()?prefix:'TODO: ';const doc={summary:effective+'TWidget class description'};
  const unfinished=tools.analyze(element,doc).find(i=>i.code==='XD008');assert.ok(unfinished,prefix);assert.equal(JSON.parse(tools.issueKey({...element,symbolId:'widget'},unfinished))[2],'Unfinished TODO documentation','keep existing baseline identity');assert.equal(tools.ready(element,doc),false,prefix);
  assert.equal(tools.meaningful('   '+doc.summary),false,'leading whitespace '+prefix);
  assert.equal(tools.ready(element,{summary:'TODO: Existing unfinished comment'}),false,'legacy TODO '+prefix);
  assert.equal(tools.ready(element,{summary:'Connects clients to the service.'}),true);
 }
 dom.window.close();
});

test('multilingual defaults, custom marker lists and literal matching stay consistent with native defaults',()=>{
 const dom=new JSDOM();for(const key of ['window','document','DOMParser','XMLSerializer','CustomEvent'])globalThis[key]=dom.window[key];
 const tools=load('docTools.ts');const defaults=JSON.parse(readFileSync(new URL('../../resources/placeholder-markers.json',import.meta.url),'utf8'));
 const native=readFileSync(new URL('../../src/Core/XmlDoc.Documentation.pas',import.meta.url),'utf8');
 const declared=native.match(/const CDefaultPlaceholderMarkers = (.*);/)[1];
 assert.deepEqual([...declared.matchAll(/'([^']*)'/g)].map(m=>m[1]),defaults);
 tools.setPlaceholderPrefix('OTHER: ');
 for(const marker of defaults){assert.equal(tools.meaningful('  '+marker+' description'),false,marker);assert.equal(tools.meaningful('<summary>'+marker+' description</summary>'),false,marker);}
 tools.setPlaceholderMarkers('CUSTOM:\r\n[draft].*\n');
 assert.equal(tools.meaningful('FIXME: completed'),true,'list replacement removes defaults');
 assert.equal(tools.meaningful('TODO: unfinished'),false,'legacy TODO is retained');
 let seed=1729;const chars='abcABC0123[].*+?^$(){}|\\-:待修正';
 for(let i=0;i<500;i++){
  let marker='';for(let j=0;j<12;j++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;marker+=chars[seed%chars.length];}
  tools.setPlaceholderMarkers('\n'+marker+'\r\n');
  assert.equal(tools.meaningful('  '+marker+' unfinished'),false,marker);
  assert.equal(tools.meaningful('Completed description with '+marker+' as an example.'),true,marker);
 }
 dom.window.close();
});
