import {JSDOM} from 'jsdom';import {readFileSync} from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
test('draft recovery navigates to original identity, compares three versions, rejects changed target',()=>{
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});
 for(const name of ['window','document','DOMParser','XMLSerializer','HTMLElement','Element','Node','CustomEvent'])globalThis[name]=dom.window[name];
 const sent=[];dom.window.chrome={webview:{postMessage:text=>sent.push(JSON.parse(text))}};
 let element={kind:'method',name:'Run',symbolId:'Run',fileName:'B.pas',locationId:'Run@implementation',declarationId:'Run@30',sourceRevision:'new',sessionId:'new',params:[]};let doc={summary:'Current',params:[]};let applies=0;
 const {initWorkbench}=load('workbench.ts');initWorkbench({get:()=>({element,doc}),apply:d=>{doc=d;applies++;}});
 const wb=window.xmlDocWorkbench;wb.receiveDrafts({drafts:[{draftId:'abc',fileName:'B.pas',symbolId:'Run',doc:{summary:'Saved'}}]});
 document.querySelector('#documentation-problems button').click();assert.deepEqual(sent.at(-1),{type:'recoverDraft',draftId:'abc'});assert.equal(applies,0);
 const recovery={fileName:'B.pas',locationId:'Run@implementation',currentRevision:'new',baseXml:'<summary>Original</summary>',currentXml:'<summary>Current</summary>',doc:{summary:'Saved'},conflict:true};
 wb.receiveRecovery(recovery);window.dispatchEvent(new CustomEvent("documentationLoaded",{detail:{element,doc}}));assert.equal(document.querySelectorAll('.draft-comparison section').length,3);assert.match(document.querySelector('#documentation-problems').textContent,/Conflict/);assert.equal(applies,0);
 element={...element,sourceRevision:'later'};document.querySelector('#documentation-problems button').click();assert.equal(applies,0);
 wb.receiveRecovery({...recovery,currentRevision:'later'});window.dispatchEvent(new CustomEvent('documentationLoaded',{detail:{element,doc}}));document.querySelector('#documentation-problems button').click();assert.equal(applies,1);assert.equal(doc.summary,'Saved');
 wb.receiveRecovery({...recovery,currentRevision:'later',readOnly:true});window.dispatchEvent(new CustomEvent('documentationLoaded',{detail:{element,doc}}));assert.equal(document.querySelector('#documentation-problems button').disabled,true);
 wb.receiveAnalysis({state:'running',completed:1,total:3,parsed:1,reused:0});assert.equal(document.querySelector('#cancel-analysis').hidden,false);document.querySelector('#cancel-analysis').click();assert.equal(sent.at(-1).type,'cancelAnalysis');
 wb.receiveAnalysis({state:'cancelled',completed:1,total:3,parsed:1,reused:0});assert.equal(document.querySelector('#cancel-analysis').hidden,true);
 dom.window.close();
});
