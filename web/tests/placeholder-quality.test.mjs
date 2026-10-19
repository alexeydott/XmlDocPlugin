import {JSDOM} from 'jsdom';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
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
