import {JSDOM} from 'jsdom';import {readFileSync} from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
function editor(){
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});
 for(const k of ['window','document','DOMParser','XMLSerializer','HTMLElement','Element','Node','Event','MutationObserver','CustomEvent','getComputedStyle'])globalThis[k]=k==='getComputedStyle'?dom.window.getComputedStyle.bind(dom.window):dom.window[k];
 Object.defineProperty(globalThis,'navigator',{value:dom.window.navigator,configurable:true});globalThis.ResizeObserver=class{observe(){}disconnect(){}};
 window.matchMedia=()=>({matches:false,addEventListener(){},removeEventListener(){}});const sent=[];window.chrome={webview:{postMessage:s=>sent.push(JSON.parse(s))}};load('editor.ts').init();
 const element={kind:'method',name:'Run',symbolId:'run',locationId:'run@interface',fileName:'Case.pas',sessionId:'session',sourceRevision:'r1',params:[{name:'Value',type:'Summary'}],genericParams:[],lineNumber:5};
 return {dom,sent,element,bridge:window.bridge};
}
test('localization preserves every untouched document field in outgoing real editor messages',async()=>{
 for(const language of ['ru','zh','ko','ja','en']){
  const {dom,sent,element,bridge}=editor();
  const doc={summary:'Original',remarks:'Notes',params:[{name:'Value',description:'Summary'}],examples:[{title:'Summary',code:'Value',description:'Example'}],seeAlso:[{cref:'Value',description:'Summary'}],exceptions:[{typeRef:'Summary',description:'Value'}]};
  bridge.receive({type:'loadDoc',data:{element,doc}});
  for(const code of [language,'en',language]){window.xmlDocSettings.apply({language:code,fontSize:13,showSignatureHeader:true,theme:'light'});await new Promise(r=>setTimeout(r,0));}
  if(language!=='en')assert.notEqual(document.querySelector('.exception-type').placeholder,'Exception type (e.g. EArgumentException)');
  document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('Changed only summary').run();bridge.flush();
  const out=sent.filter(m=>m.type==='docUpdated').at(-1).doc;
  for(const key of ['remarks','params','examples','seeAlso','exceptions'])assert.deepEqual(out[key],doc[key],language+' '+key);
  bridge.cancelPending();dom.window.close();
 }
});
test('old preview rejects local edits and Undo without cancelling their pending save',()=>{
 const {dom,sent,element,bridge}=editor();bridge.receive({type:'loadDoc',data:{element,doc:{summary:'Original'}}});
 document.querySelector('#sync-document').click();assert.equal(document.querySelector('#operation-preview').hidden,false);
 document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('New local summary').run();
 document.querySelector('#apply-operation').click();bridge.flush();
 assert.equal(sent.filter(m=>m.type==='docUpdated').at(-1).doc.summary,'New local summary');
 assert.ok(!sent.filter(m=>m.type==='docUpdated').some(m=>m.doc.summary==='Original'));
 bridge.cancelPending();dom.window.close();
});

test('parse failure locks only source mutation and a corrected snapshot restores the real editor',async()=>{
 const {dom,sent,element,bridge}=editor();
 bridge.receive({type:'loadDoc',data:{element,doc:{summary:'Original'}}});
 bridge.receive({type:'loadDoc',data:{element:{kind:'unit',name:'Case.pas',fileName:'Case.pas',symbolId:'',sessionId:'',lineNumber:1,params:[],genericParams:[],readOnly:true,readOnlyReason:'Read-only: source could not be parsed'},doc:{summary:''}}});
 await new Promise(r=>setTimeout(r,0));
 assert.equal(bridge.readOnly,true);assert.equal(document.querySelector('#summary-editor .tiptap').editor.isEditable,false);
 assert.equal(document.querySelector('#reload-document').disabled,false);assert.equal(document.querySelector('#refresh-catalog').disabled,false);
 bridge.notifyDocChanged({summary:'Forbidden'});bridge.flush();assert.equal(sent.filter(m=>m.type==='docUpdated').length,0);
 window.xmlDocWorkbench.receiveCatalog({elements:[],errors:['File: Case.pas\nLine: 7; Column: 18\nReason: Value']});
 assert.equal(document.querySelector('#catalog-errors').hidden,false);assert.match(document.querySelector('#catalog-errors pre').textContent,/Line: 7; Column: 18/);
 bridge.receive({type:'loadDoc',data:{element:{...element,sourceRevision:'r2'},doc:{summary:'Restored'}}});
 await new Promise(r=>setTimeout(r,0));assert.equal(bridge.readOnly,false);assert.equal(document.querySelector('#summary-editor .tiptap').editor.isEditable,true);
 assert.equal(window.xmlDocEditor.get().doc.summary,'Restored');
 window.xmlDocWorkbench.receiveCatalog({elements:[],errors:[]});assert.equal(document.querySelector('#catalog-errors').hidden,true);
 bridge.cancelPending();dom.window.close();
});
