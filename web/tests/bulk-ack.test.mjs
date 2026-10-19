import {JSDOM} from 'jsdom';import {readFileSync} from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
function setup(){
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});
 for(const k of ['window','document','DOMParser','XMLSerializer','HTMLElement','Element','Node','Event','CustomEvent'])globalThis[k]=dom.window[k];
 const sent=[];window.chrome={webview:{postMessage:s=>sent.push(JSON.parse(s))}};
 const owner={kind:'class',name:'TWorker',symbolId:'worker',fileName:'Case.pas',params:[]};
 load('workbench.ts').initWorkbench({get:()=>({element:owner,doc:{summary:'Owner'}}),apply:()=>{}});
 const element=(summary,revision)=>({kind:'method',name:'Run',signature:'Run',symbolId:'run',locationId:'run@interface',qualifiedParent:'TWorker',fileName:'Case.pas',params:[],sourceRevision:revision,sessionId:'session',doc:{summary}});
 const catalog=(text,rev)=>window.xmlDocWorkbench.receiveCatalog({elements:[element(text,rev)]});
 const edit=text=>{const input=document.querySelector('#member-summaries textarea');input.value=text;input.dispatchEvent(new Event('input'));const check=document.querySelector('#member-summaries input');check.checked=true;check.dispatchEvent(new Event('change'));};
 const apply=()=>{document.querySelector('#apply-summaries').click();document.querySelector('#apply-operation').click();return sent.filter(m=>m.type==='batchUpdated').at(-1);};
 return {dom,sent,catalog,edit,apply};
}
test('two consecutive bulk edits use acknowledged source revisions and retain newer input',()=>{
 const {dom,sent,catalog,edit,apply}=setup();catalog('Original','r1');edit('FIRST EDIT');const first=apply();assert.equal(first.changes[0].element.sourceRevision,'r1');
 edit('SECOND EDIT');window.xmlDocWorkbench.receiveBatchResult({batchId:first.batchId,status:'applied'});catalog('FIRST EDIT','r2');
 assert.equal(document.querySelector('#member-summaries textarea').value,'SECOND EDIT');
 const second=apply();assert.equal(second.changes[0].element.sourceRevision,'r2');assert.equal(second.changes[0].doc.summary,'SECOND EDIT');assert.equal(sent.filter(m=>m.type==='batchUpdated').length,2);
 catalog('SECOND EDIT','r3');window.xmlDocWorkbench.receiveBatchResult({batchId:second.batchId,status:'applied'});
 edit('THIRD EDIT');const third=apply();assert.equal(third.changes[0].element.sourceRevision,'r3');dom.window.close();
});
test('external summary changes require an explicit baseline review before applying retained text',()=>{
 const {dom,catalog,edit,apply}=setup();catalog('Original','r1');edit('Local edit');catalog('External edit','r2');assert.equal(apply(),undefined);
 const review=Array.from(document.querySelectorAll('#member-summaries button')).find(b=>b.getAttribute('aria-label')==='Review current source');assert.ok(review);review.click();assert.match(document.querySelector('#xml-before').textContent,/External edit/);
 document.querySelector('#apply-operation').click();const batch=apply();assert.equal(batch.changes[0].element.sourceRevision,'r2');assert.equal(batch.changes[0].doc.summary,'Local edit');dom.window.close();
});

test('seeded repeated bulk ACK orders, filtering, rejection and unchanged-source acknowledgements',()=>{
 const {dom,sent,catalog,edit,apply}=setup();let seed=7319,revision=1,committed='Original';
 const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 catalog(committed,'r'+revision);
 for(let i=0;i<80;i++){
  const text=i%9===0?committed:'Edit '+i+' &amp; detail';edit(text);const batch=apply();assert.ok(batch,'iteration '+i);
  window.xmlDocWorkbench.receiveBatchResult({batchId:'unknown',status:'applied'});
  assert.equal(document.querySelector('#apply-summaries').disabled,true);
  const next='Pending '+i;edit(next);
  const query=document.querySelector('#catalog-query');query.value='hidden';query.dispatchEvent(new Event('input'));query.value='';query.dispatchEvent(new Event('input'));
  if(i%11===0){
   window.xmlDocWorkbench.receiveBatchResult({batchId:batch.batchId,status:'rejected'});
   assert.equal(document.querySelector('#member-summaries textarea').value,next);continue;
  }
  if(text!==committed)revision++;committed=text;
  if(random()<0.5){catalog(committed,'r'+revision);window.xmlDocWorkbench.receiveBatchResult({batchId:batch.batchId,status:'applied'});}
  else {window.xmlDocWorkbench.receiveBatchResult({batchId:batch.batchId,status:'applied'});catalog(committed,'r'+revision);}
  assert.equal(document.querySelector('#apply-summaries').disabled,false,'settled '+i);
  assert.equal(document.querySelector('#member-summaries textarea').value,next,'newer text '+i);
 }
 assert.equal(sent.filter(m=>m.type==='batchUpdated').length,80);dom.window.close();
});

test('a batch ACK binds to its exact written revision instead of an external matching summary',()=>{
 const {dom,catalog,edit,apply}=setup();catalog('Original','r1');edit('FIRST');const batch=apply();edit('NEXT');
 window.xmlDocWorkbench.receiveBatchResult({batchId:batch.batchId,status:'applied',sourceRevisions:{'CASE.PAS':'r2'}});
 assert.equal(document.querySelector('#apply-summaries').disabled,true);
 catalog('FIRST','external-r3');assert.equal(document.querySelector('#apply-summaries').disabled,false);
 assert.equal(apply().batchId,batch.batchId,'External revision must not submit another batch');
 assert.ok(document.querySelector('#member-summaries [aria-label="Review current source"]'));
 document.querySelector('#member-summaries [aria-label="Review current source"]').click();document.querySelector('#apply-operation').click();
 const next=apply();assert.equal(next.changes[0].element.sourceRevision,'external-r3');assert.equal(next.changes[0].doc.summary,'NEXT');dom.window.close();
});
