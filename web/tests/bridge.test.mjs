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

test('read-only source cancels pending edits and refuses drafts',async()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);b.saveDebounceMs=5;
 b.setContext(element('A'));b.notifyDocChanged({summary:'pending'});sent.length=0;
 b.setContext({...element('B'),readOnly:true,readOnlyReason:'Read-only source'});
 b.notifyDocChanged({summary:'forbidden'});b.saveDraft({summary:'forbidden'});b.flush();await sleep(15);
 assert.equal(sent.length,0);assert.equal(b.drafts.has('A.pas|B'),false);
 b.setContext(element('C'));b.notifyDocChanged({summary:'allowed'});b.flush();
 assert.ok(sent.some(m=>m.type==='docUpdated'&&m.doc.summary==='allowed'));
});
test('native read-only rejection locks source and cancels pending edit',async()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);b.saveDebounceMs=5;
 b.setContext(element('A'));b.notifyDocChanged({summary:'pending'});sent.length=0;
 b.receive({type:'editResult',sessionId:'session',status:'Read-only: IDE buffer'});
 b.notifyDocChanged({summary:'forbidden'});await sleep(15);b.flush();
 assert.equal(b.readOnly,true);assert.equal(sent.length,0);
});

test('read-only viewing uses source rather than a recovered draft',()=>{
 const b=new DelphiBridge();b.sendToHost=()=>{};b.setContext(element('A'));b.saveDraft({summary:'draft'});
 let shown;b.onElementLoaded((e,doc)=>shown=doc);
 b.receive({type:'loadDoc',data:{element:{...element('A'),readOnly:true},doc:{summary:'source'}}});
 assert.equal(shown.summary,'source');
});

test('seeded protection/navigation fuzz never schedules protected writes',()=>{
 let seed=0xa61c3;const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);
 for(let i=0;i<5000;i++){
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;const locked=!!(seed&1);
  b.setContext({...element('node'+i),readOnly:locked});
  b.saveDraft({summary:'draft'});b.notifyDocChanged({summary:'edit'});b.flush();
  if(locked)assert.equal(sent.length,0);else assert.ok(sent.some(m=>m.type==='docUpdated'));
  sent.length=0;
 }
});

test('ACK of first write retains newer edit and rebases its source context, also when pinned',()=>{
 for(const pinned of [false,true]){
  const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);b.setContext(element('A'));b.setPinned(pinned);
  b.notifyDocChanged({summary:'first'});b.flush();const first=sent.find(m=>m.type==='docUpdated');
  b.notifyDocChanged({summary:'second'});b.flush();assert.equal(sent.filter(m=>m.type==='docUpdated').length,1);
  b.receive({type:'editResult',sessionId:'session',editId:first.editId,status:'Applied'});
  let shown;b.onElementLoaded((e,d)=>shown=d);
  b.receive({type:'loadDoc',data:{element:{...element('A','2'),sessionId:'session2'},doc:{summary:'first'}}});
  assert.equal(shown.summary,'second');b.flush();const second=sent.filter(m=>m.type==='docUpdated')[1];
  assert.equal(second.doc.summary,'second');assert.equal(second.sourceRevision,'2');assert.equal(second.sessionId,'session2');
  b.receive({type:'editResult',sessionId:'session',editId:first.editId,status:'Applied'});
  assert.equal(b.drafts.get('A.pas|A').doc.summary,'second');
  b.receive({type:'editResult',sessionId:'session2',editId:second.editId,status:'Applied'});
  b.receive({type:'loadDoc',data:{element:{...element('A','3'),sessionId:'session3'},doc:{summary:'second'}}});
  assert.equal(b.drafts.size,0);b.cancelPending();
 }
});
test('same bridge loading restores draft after A to B to A',()=>{
 const b=new DelphiBridge();b.sendToHost=()=>{};let shown;b.onElementLoaded((e,d)=>shown=d);
 b.receive({type:'loadDoc',data:{element:element('A'),doc:{summary:'source'}}});b.notifyDocChanged({summary:'draft'});
 b.receive({type:'loadDoc',data:{element:element('B'),doc:{summary:'B'}}});
 b.receive({type:'loadDoc',data:{element:element('A'),doc:{summary:'source'}}});assert.equal(shown.summary,'draft');b.cancelPending();
});

test('same revision refresh retains pending formatted edit, external revision does not autosave it',async()=>{
 for(const revision of ['1','external']){
  const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);b.saveDebounceMs=5;
  b.setContext(element('FromB'));b.notifyDocChanged({summary:'edited',rawXml:'<summary>edited</summary>',xmlEdited:true});
  b.receive({type:'loadDoc',data:{element:element('FromB',revision),doc:{summary:'source'}}});
  await sleep(20);const writes=sent.filter(m=>m.type==='docUpdated');
  assert.equal(writes.length,revision==='1'?1:0);
  if(writes.length){assert.equal(writes[0].doc.xmlEdited,true);assert.equal(writes[0].doc.summary,'edited');}
  b.cancelPending();
 }
});