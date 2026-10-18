import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
globalThis.window=new EventTarget();globalThis.CustomEvent??=class extends Event{constructor(type,options){super(type);this.detail=options?.detail;}};
const {DelphiBridge}=load('bridge.ts');const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const element=(id,rev='1',file='A.pas')=>({kind:'method',name:id,params:[],symbolId:id,fileName:file,sessionId:'session',sourceRevision:rev});
test('delayed save cannot acquire the later selected identity',async()=>{
 const b=new DelphiBridge();b.saveDebounceMs=10;const sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};
 b.setContext(element('A'));b.notifyDocChanged({summary:'A edit'});b.setContext(element('B'));
 await sleep(25);assert.equal(sent.length,0);assert.equal(b.drafts.get('A.pas|A').doc.summary,'A edit');
 b.notifyDocChanged({summary:'B edit'});await sleep(25);assert.equal(sent[0].symbolId,'B');assert.equal(sent[0].doc.summary,'B edit');
});
test('pending content and context are immutable snapshots',async()=>{
 const b=new DelphiBridge();b.saveDebounceMs=5;const sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};const e=element('A');const doc={summary:'initial'};
 b.setContext(e);b.notifyDocChanged(doc);e.symbolId='changed';doc.summary='changed';await sleep(15);
 assert.equal(sent[0].symbolId,'A');assert.equal(sent[0].doc.summary,'initial');
});
test('old draft keeps its original revision and must conflict after external edits',()=>{
 const b=new DelphiBridge();const sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};
 b.setContext(element('A','old'));b.notifyDocChanged({summary:'draft'});b.setContext(element('B'));
 b.setContext(element('A','new'));b.notifyDocChanged({summary:'restored draft'});b.flush();
 assert.equal(sent[0].sourceRevision,'old');
});
test('same symbol in two files is isolated',()=>{
 const b=new DelphiBridge();const sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};
 b.setContext(element('Run','1','A.pas'));b.notifyDocChanged({summary:'A'});b.setContext(element('Run','1','B.pas'));b.notifyDocChanged({summary:'B'});b.flush();
 assert.equal(sent[0].fileName,'B.pas');assert.equal(sent[0].doc.summary,'B');assert.equal(b.drafts.get('A.pas|Run').doc.summary,'A');
});
test('deterministic navigation/debounce fuzz never changes the captured target',()=>{
 let seed=0x516abc;const b=new DelphiBridge();const sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};
 for(let i=0;i<5000;i++){
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;const id='symbol'+seed%47;const file='unit'+seed%13+'.pas';
  b.setContext(element(id,'r'+i,file));b.notifyDocChanged({summary:id+'|'+file});
  if(seed%3===0)b.flush();else b.setContext(element('other'));
 }
 b.cancelPending();assert.ok(sent.length>1000);
 for(const m of sent)assert.equal(m.doc.summary,m.symbolId+'|'+m.fileName);
});

test('declaration and implementation drafts are separate even with identical symbol identity',()=>{
 const b=new DelphiBridge();b.sendToHost=()=>{};
 b.setContext({...element('Run'),declarationId:'Run@10'});b.notifyDocChanged({summary:'Declaration'});
 b.setContext({...element('Run'),declarationId:'Run@30'});b.notifyDocChanged({summary:'Implementation'});b.cancelPending();
 assert.equal(b.drafts.get('A.pas|Run@10').doc.summary,'Declaration');assert.equal(b.drafts.get('A.pas|Run@30').doc.summary,'Implementation');
});
test('unapplied XML draft is persisted without scheduling a source write',()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);b.setContext(element('Run'));
 b.saveDraft({summary:'',rawXml:'<summary>Broken',xmlEdited:true});b.flush();
 assert.equal(sent.length,1);assert.equal(sent[0].type,'draftUpdated');assert.equal(sent[0].sourceRevision,'1');
});
