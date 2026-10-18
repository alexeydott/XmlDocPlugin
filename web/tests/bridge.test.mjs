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
test('pinned implementation ACK cannot rebase its next edit onto the interface declaration',()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};
 const impl={...element('Run'),declarationId:'Run@30',locationId:'Run@implementation'};
 b.setContext(impl);b.setPinned(true);b.notifyDocChanged({summary:'first'});b.flush();b.notifyDocChanged({summary:'second'});
 b.receive({type:'editResult',sessionId:'session',editId:sent[0].editId,status:'Applied'});
 b.receive({type:'loadDoc',data:{element:{...impl,declarationId:'Run@10',locationId:'Run@interface',sourceRevision:'2'},doc:{summary:'interface'}}});b.flush();
 assert.equal(sent.length,1);
 b.receive({type:'loadDoc',data:{element:{...impl,declarationId:'Run@32',sourceRevision:'2'},doc:{summary:'first'}}});b.flush();
 assert.equal(sent.length,2);assert.equal(sent[1].declarationId,'Run@32');assert.equal(sent[1].locationId,'Run@implementation');assert.equal(sent[1].doc.summary,'second');
});
test('ACK rebases XML draft without applying it until explicitly approved',()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};const e=element('Run');
 b.setContext(e);b.notifyDocChanged({summary:'Design'});b.flush();b.saveDraft({summary:'XML',rawXml:'<summary>XML</summary>',xmlEdited:true});
 b.receive({type:'editResult',sessionId:'session',editId:sent[0].editId,status:'Applied'});
 b.receive({type:'loadDoc',data:{element:{...e,sourceRevision:'2'},doc:{summary:'Design'}}});b.flush();assert.equal(sent.length,1);
 assert.equal(b.drafts.get('A.pas|Run').revision,'2');b.notifyDocChanged(b.drafts.get('A.pas|Run').doc);b.flush();assert.equal(sent.length,2);assert.equal(sent[1].sourceRevision,'2');
});

test('ACK and unapplied XML drafts remain isolated across declaration/implementation fuzz',()=>{
 for(let i=0;i<1000;i++){
  const b=new DelphiBridge(),sent=[];b.sendToHost=m=>{if(m.type==='docUpdated')sent.push(m);};const role=i%2?'interface':'implementation';
  const e={...element('Run'),locationId:'Run@'+role,declarationId:'Run@'+(10+i)};
  b.setContext(e);b.setPinned(true);b.notifyDocChanged({summary:'first'});b.flush();
  const xml=i%3===0;if(xml)b.saveDraft({summary:'draft XML',xmlEdited:true,rawXml:'<summary>XML</summary>'});else b.notifyDocChanged({summary:'next'});
  b.receive({type:'editResult',sessionId:'session',editId:sent[0].editId,status:'Applied'});
  b.receive({type:'loadDoc',data:{element:{...e,locationId:role==='interface'?'Run@implementation':'Run@interface',declarationId:'other',sourceRevision:'2'},doc:{summary:'other'}}});b.flush();assert.equal(sent.length,1);
  b.receive({type:'loadDoc',data:{element:{...e,declarationId:'Run@'+(20+i),sourceRevision:'2'},doc:{summary:'first'}}});b.flush();assert.equal(sent.length,xml?1:2);if(!xml)assert.equal(sent[1].locationId,e.locationId);
 }
});
test('stable location preserves non-applying draft after external line shift and card switching',()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);let shown;b.onElementLoaded((e,d)=>shown=d);
 const e={...element('Run'),declarationId:'Run@30',locationId:'Run@implementation'};
 b.receive({type:'loadDoc',data:{element:e,doc:{summary:'Original',sourceXml:'<summary>Original</summary>'}}});b.saveDraft({summary:'XML',rawXml:'<summary>XML</summary>',xmlEdited:true});
 b.receive({type:'loadDoc',data:{element:element('Other'),doc:{summary:'Other'}}});
 const moved={...e,declarationId:'Run@40',sourceRevision:'external',sessionId:'new'};b.receive({type:'loadDoc',data:{element:moved,doc:{summary:'Changed'}}});b.flush();
 assert.equal(shown.summary,'XML');assert.equal(sent.filter(m=>m.type==='docUpdated').length,0);assert.equal(b.drafts.get('A.pas|Run@implementation').apply,false);
 assert.equal(sent.find(m=>m.type==='draftUpdated').baseXml,'<summary>Original</summary>');assert.equal(sent.find(m=>m.type==='draftUpdated').applyAllowed,false);
 b.prepareRecovery(moved);b.notifyDocChanged(shown);b.flush();assert.equal(sent.at(-1).sourceRevision,'external');assert.equal(sent.at(-1).declarationId,'Run@40');b.cancelPending();
});


test('same-revision reload requeues Design without overwriting a newer XML draft',()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);
 const e=element('A');const load=doc=>b.receive({type:'loadDoc',data:{element:e,doc}});
 load({summary:'Original',sourceXml:'<summary>Original</summary>'});
 b.notifyDocChanged({summary:'Older design'});
 b.saveDraft({rawXml:'<summary>New XML</summary>',xmlEdited:true});
 const before=sent.filter(m=>m.type==='draftUpdated').length;
 load({summary:'Original',sourceXml:'<summary>Original</summary>'});b.flush();
 assert.equal(b.drafts.get('A.pas|A').doc.rawXml,'<summary>New XML</summary>');
 assert.equal(sent.filter(m=>m.type==='draftUpdated').length,before);
 assert.equal(sent.find(m=>m.type==='docUpdated').doc.summary,'Older design');
 b.cancelPending();
});

test('external reload preserves draft base XML paired with its original revision',()=>{
 const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);
 b.receive({type:'loadDoc',data:{element:element('A','r1'),doc:{sourceXml:'<summary>Original</summary>'}}});
 b.saveDraft({summary:'Draft'});
 b.receive({type:'loadDoc',data:{element:element('A','r2'),doc:{sourceXml:'<summary>External</summary>'}}});
 b.saveDraft({summary:'Draft edited again'});
 const saved=sent.filter(m=>m.type==='draftUpdated').at(-1);
 assert.equal(saved.sourceRevision,'r1');assert.equal(saved.baseXml,'<summary>Original</summary>');
});


test('seeded reload and raw/Design interleavings preserve draft provenance and apply mode',()=>{
 let seed=0x917bc;const b=new DelphiBridge(),sent=[];b.sendToHost=m=>sent.push(m);
 for(let i=0;i<1000;i++){
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;
  const e=element('A'+i,'r1');const base='<summary>Base '+i+'</summary>';
  b.receive({type:'loadDoc',data:{element:e,doc:{sourceXml:base}}});
  b.notifyDocChanged({summary:'Allowed '+i});b.saveDraft({xmlEdited:true,rawXml:'<summary>Raw '+i+'</summary>'});
  const external=!!(seed&1);b.receive({type:'loadDoc',data:{element:{...e,sourceRevision:external?'r2':'r1'},doc:{sourceXml:external?'<summary>External</summary>':base}}});
  b.saveDraft({xmlEdited:true,rawXml:'<summary>Latest '+i+'</summary>'});
  const saved=sent.at(-1);assert.equal(saved.baseXml,base);assert.equal(saved.sourceRevision,'r1');assert.equal(saved.applyAllowed,false);
  assert.equal(b.drafts.get('A.pas|A'+i).doc.rawXml,saved.doc.rawXml);b.cancelPending();
 }
});
