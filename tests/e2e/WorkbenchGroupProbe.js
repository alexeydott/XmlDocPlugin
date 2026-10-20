(async()=>{
 if(!window.xmlDocEditor || !window.xmlDocWorkbench || window.__xmlDocGroupE2E)return;
 window.__xmlDocGroupE2E=true;
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const assert=(test,text)=>{if(!test)throw Error(text);};
 try{
  let groupCatalog,analysis,analysisStarted=false;
  const receive=window.xmlDocWorkbench.receiveCatalog;window.xmlDocWorkbench.receiveCatalog=data=>{groupCatalog=data;receive(data);};
  const receiveAnalysis=window.xmlDocWorkbench.receiveAnalysis;window.xmlDocWorkbench.receiveAnalysis=data=>{if(data.state==='running')analysisStarted=true;if(analysisStarted)analysis=data;receiveAnalysis(data);};
  const isGroupCatalog=()=>groupCatalog?.elements.some(e=>e.name==='FromB') && groupCatalog.elements.some(e=>(e.fileName??'').endsWith('Workbench.Sample.pas'));
  // Match the real scope control so subsequent automatic refreshes retain group scope.
  document.getElementById('catalog-scope').value='group';
  window.bridge.sendToHost({type:'requestCatalog',scope:'group'});
  // Ignore queued file/project catalogs from the card navigation. Finish a real
  // group request before measuring reuse in the following, unchanged request.
  for(let i=0;i<100 && (!isGroupCatalog() || analysis?.state!=='completed');i++)await pause(100);
  assert(isGroupCatalog() && analysis?.state==='completed','Initial group analysis did not finish: '+JSON.stringify({status:window.bridge.status,analysis,elements:groupCatalog?.elements.length,errors:groupCatalog?.errors,group:isGroupCatalog()}));
  analysisStarted=false;analysis=undefined;groupCatalog=undefined;
  let lastPulse=performance.now(),maxGap=0;const pulse=setInterval(()=>{const now=performance.now();maxGap=Math.max(maxGap,now-lastPulse);lastPulse=now;},10);const warmStart=performance.now();
  window.bridge.sendToHost({type:'requestCatalog',scope:'group'});for(let i=0;i<100 && (!isGroupCatalog() || !analysisStarted || analysis?.state!=='completed');i++)await pause(100);assert(analysis?.parsed===0 && analysis?.reused>0,'Unchanged modules were not reused: '+JSON.stringify(analysis));
  clearInterval(pulse);
  assert(groupCatalog && !groupCatalog.errors?.length,'Project catalog reported errors: '+JSON.stringify(groupCatalog?.errors));
  assert(groupCatalog.elements.some(e=>/ReferenceSources[\\/]SearchOnly\.pas$/i.test(e.fileName??'')),'Bare OTA module alias was not resolved through the unit search path');
  const nativePhases=Object.fromEntries(['preparationMs','validationMs','publicationMs','stopWorkerMs'].map(key=>{assert(Number.isFinite(analysis[key]) && analysis[key]>=0,'Missing native phase timing: '+key);return [key,analysis[key]];}));
  send('analysis-metrics',{warmMs:performance.now()-warmStart,maxUiGapMs:maxGap,...nativePhases});
  const cancelStart=performance.now();
  window.bridge.sendToHost({type:'requestCatalog',scope:'group'});window.bridge.sendToHost({type:'cancelAnalysis'});for(let i=0;i<100 && analysis?.state!=='cancelled';i++)await pause(100);assert(analysis?.state==='cancelled','Analysis cancellation was not reported');send('analysis-metrics',{cancelMs:performance.now()-cancelStart});await pause(250);assert(analysis?.state==='cancelled','Cancelled analysis resumed from a queued timer');assert(getComputedStyle(document.querySelector('#cancel-analysis')).display==='none','Cancelled analysis action is still visible');
  groupCatalog=null;window.bridge.sendToHost({type:'requestCatalog',scope:'group'});for(let i=0;i<100 && !groupCatalog;i++)await pause(100);
  const fromB=groupCatalog?.elements.find(e=>e.name==='FromB' && e.params[0].type==='string');assert(fromB?.projectFile,'Project B context missing from group search');
  window.bridge.sendToHost({type:'openSymbol',projectFile:fromB.projectFile,fileName:fromB.fileName,symbolId:fromB.symbolId,line:fromB.lineNumber});for(let i=0;i<100 && window.xmlDocEditor.get().element.name!=='FromB';i++)await pause(100);
  assert(window.xmlDocEditor.get().element.name==='FromB' && window.xmlDocEditor.get().element.params[0].type==='string','Navigation to B failed: '+JSON.stringify(window.xmlDocEditor.get().element)+' status='+window.bridge.status);send('assert-group');
  const currentB=window.xmlDocEditor.get().element;assert(currentB.projectFile===fromB.projectFile,'Inspector card lost owning project');
  document.querySelector('#focus-source').click();await pause(400);assert(window.xmlDocEditor.get().element.params[0].type==='string','Source command lost B defines');
  const fromA=groupCatalog.elements.find(e=>e.fileName===fromB.fileName && e.name==='OtherB');assert(fromA,'Project A navigation target missing');
  window.bridge.sendToHost({type:'openSymbol',...fromA,line:fromA.lineNumber});await pause(600);
  document.querySelector('#history-back').click();await pause(500);assert(window.xmlDocEditor.get().element.name==='FromB','Back lost B selection');assert(window.xmlDocEditor.get().element.params[0].type==='string','Back lost B defines');
  document.querySelector('#history-forward').click();await pause(400);assert(window.xmlDocEditor.get().element.name==='OtherB','Forward lost A selection');document.querySelector('#history-back').click();await pause(400);
  send('group-navigation-checked');
  let quick;const receiveQuick=window.xmlDocWorkbench.receiveQuickDoc;window.xmlDocWorkbench.receiveQuickDoc=data=>{quick=data;receiveQuick(data);};
  send('group-quick-context');for(let i=0;i<100 && !window.__quickContextReady;i++)await pause(100);await pause(250);window.bridge.sendToHost({type:'requestQuickDoc'});for(let i=0;i<100 && !quick;i++)await pause(100);
  assert(quick?.resolved && quick.matches.length===1 && quick.matches[0].signature.includes('Integer'),'Instance/local overload resolution failed: '+JSON.stringify(quick)+' '+window.bridge.status);
  window.bridge.sendToHost({type:'openSymbol',...fromB,line:fromB.lineNumber});await pause(400);send('group-stub');await pause(600);
  send('group-include',{enabled:false});await pause(200);groupCatalog=null;window.bridge.sendToHost({type:'requestCatalog',scope:'group'});for(let i=0;i<100 && !groupCatalog;i++)await pause(100);
  assert(groupCatalog.elements.some(e=>e.name==='FromB' && e.params[0].type==='Integer'),'Refresh reused catalog after closed include changed');
  send('group-include',{enabled:true});await pause(200);groupCatalog=null;window.bridge.sendToHost({type:'requestCatalog',scope:'group'});for(let i=0;i<100 && !groupCatalog;i++)await pause(100);assert(groupCatalog.elements.some(e=>e.name==='FromB' && e.params[0].type==='string'),'Restored include not refreshed');send('group-include-checked');
  window.bridge.sendToHost({type:'openSymbol',...fromB,line:fromB.lineNumber});await pause(400);
  document.querySelector('#doc-tabs [data-tab=design]').click();
  for(const mode of ['pending','saved']){
   const summary=document.querySelector('#summary-editor .tiptap');assert(summary?.editor,'GroupB rich editor missing');
   summary.editor.chain().focus().selectAll().insertContent('GroupB '+mode+' before format — Пример & details').run();
   if(mode==='saved'){window.bridge.flush();await pause(1000);assert(window.bridge.status==='Applied','GroupB edit did not save');}
   document.querySelector('#format-document').click();assert(!document.querySelector('#operation-preview').hidden,'GroupB format did not show preview');
   assert(document.querySelector('#xml-after').textContent.includes('GroupB '+mode+' before format'),'Format discarded current edit');
   document.querySelector('#apply-operation').click();await pause(1200);
   assert(window.bridge.status==='Applied','GroupB formatted edit was rejected: '+window.bridge.status+' bridge='+JSON.stringify({context:window.bridge.context,pending:window.bridge.pending,flight:window.bridge.inFlight,drafts:[...window.bridge.drafts]}));
   assert(window.xmlDocEditor.get().doc.summary.includes('GroupB '+mode+' before format'),'GroupB summary lost after format');
   send('assert-group-format',{mode});await pause(200);
  }
  const declaration=window.xmlDocEditor.get().element;
  const implementationId=declaration.locationId.replace('@interface','@implementation');
  window.bridge.sendToHost({type:'openSymbol',...declaration,locationId:implementationId,line:declaration.lineNumber});await pause(500);
  assert(window.xmlDocEditor.get().element.locationId===implementationId,'Implementation navigation selected interface');
  document.querySelector('#pin-document').click();await pause(100);
  const implementationDoc=window.xmlDocEditor.get().doc;
  window.bridge.notifyDocChanged({...implementationDoc,summary:'Implementation first'});window.bridge.flush();
  window.bridge.notifyDocChanged({...implementationDoc,summary:'Implementation second'});await pause(1800);
  assert(window.bridge.status==='Applied','Pinned implementation did not save both edits: '+window.bridge.status);assert(window.xmlDocEditor.get().element.locationId===implementationId,'ACK moved pinned implementation to declaration');send('group-implementation-checked');
  window.bridge.notifyDocChanged({...window.xmlDocEditor.get().doc,summary:'Implementation design before XML'});window.bridge.flush();
  document.querySelector('#open-xml').click();const raw=document.querySelector('#xml-source');raw.value='<summary>XML requires explicit approval</summary>';raw.dispatchEvent(new Event('input',{bubbles:true}));await pause(1000);
  send('group-xml-draft-checked');document.querySelector('#apply-xml').click();await pause(1000);assert(window.bridge.status==='Applied','Explicit XML apply failed');send('group-xml-applied-checked');
  document.querySelector('#pin-document').click();await pause(100);
  window.bridge.sendToHost({type:'openSymbol',...declaration,line:declaration.lineNumber});await pause(400);
  const recoveryTarget=window.xmlDocEditor.get().element;window.bridge.sendToHost({type:'openSymbol',...recoveryTarget,locationId:implementationId});await pause(400);
  const savedTarget=window.xmlDocEditor.get().element;window.bridge.saveDraft({...window.xmlDocEditor.get().doc,summary:'Recovered implementation draft',rawXml:'<summary>Recovered implementation draft</summary>',xmlEdited:true});
  send('review-external-comment',{line:savedTarget.lineNumber});for(let i=0;i<100 && !window.__reviewExternalReady;i++)await pause(50);assert(window.__reviewExternalReady,'External comment edit failed');
  window.bridge.saveDraft({...window.xmlDocEditor.get().doc,summary:'Recovered implementation draft',rawXml:'<summary>Recovered implementation draft</summary>',xmlEdited:true});
  window.bridge.sendToHost({type:'openSymbol',...declaration,line:declaration.lineNumber});await pause(400);
  let drafts;const receiveDrafts=window.xmlDocWorkbench.receiveDrafts;window.xmlDocWorkbench.receiveDrafts=data=>{drafts=data.drafts;receiveDrafts(data);};window.bridge.sendToHost({type:'listDrafts'});for(let i=0;i<100 && !drafts;i++)await pause(100);
  const saved=drafts?.find(d=>d.locationId===savedTarget.locationId && d.fileName===savedTarget.fileName);assert(saved?.draftId,'Saved implementation draft missing');
  assert(saved.baseXml.includes('XML requires explicit approval') && !saved.baseXml.includes('EXTERNAL SOURCE CHANGE'),'Persisted Original was replaced by external source');
  assert(saved.sourceRevision===savedTarget.sourceRevision,'Draft revision was rebased on external edit');
  let recovered;const receiveRecovery=window.xmlDocWorkbench.receiveRecovery;window.xmlDocWorkbench.receiveRecovery=data=>{recovered=data;receiveRecovery(data);};
  window.bridge.sendToHost({type:'recoverDraft',draftId:saved.draftId});for(let i=0;i<100 && !document.querySelector('.draft-comparison');i++)await pause(100);
  assert(recovered?.conflict && recovered.currentXml.includes('EXTERNAL SOURCE CHANGE') && recovered.baseXml===saved.baseXml,'Native recovery failed to detect original/current conflict');
  assert(window.xmlDocEditor.get().element.locationId===implementationId,'Recovery selected another source section');assert(document.querySelectorAll('.draft-comparison section').length===3,'Recovery comparison missing');
  assert(document.querySelector('.draft-comparison').textContent.includes('Recovered implementation draft'),'Draft comparison lost saved XML');document.querySelector('#documentation-problems button').click();await pause(1200);assert(window.bridge.status==='Applied','Recovery apply failed: '+window.bridge.status);
  window.bridge.sendToHost({type:'openSymbol',...declaration,line:declaration.lineNumber});await pause(400);
  // Restore an unapplied raw draft, choose Design, then verify the native source.
  window.bridge.sendToHost({type:'openSymbol',...declaration,locationId:implementationId});await pause(400);
  const designTarget=window.xmlDocEditor.get();
  document.querySelector('#open-xml').click();const hiddenRaw=document.querySelector('#xml-source');
  hiddenRaw.value='<summary>REVIEW HIDDEN RAW MUST NOT WRITE</summary>';hiddenRaw.dispatchEvent(new Event('input',{bubbles:true}));
  window.bridge.sendToHost({type:'openSymbol',...declaration,line:declaration.lineNumber});await pause(400);
  window.bridge.sendToHost({type:'openSymbol',...declaration,locationId:implementationId});await pause(400);
  assert(window.xmlDocEditor.get().doc.xmlEdited,'Raw draft was not restored');
  document.querySelector('#doc-tabs [data-tab=design]').click();
  const summaryEditor=document.querySelector('#summary-editor .tiptap').editor;
  summaryEditor.chain().focus().selectAll().insertContent('REVIEW UNDO TEMPORARY TEXT').run();summaryEditor.commands.undo();window.bridge.flush();await pause(1000);
  assert(!window.xmlDocEditor.get().doc.xmlEdited,'Undo reauthorized hidden XML');assert(window.bridge.unappliedXml()?.xml.includes('REVIEW HIDDEN RAW'),'Undo lost separate raw draft');send('assert-review-undo');
  document.querySelector('#summary-editor .tiptap').editor.chain().focus().selectAll().insertContent('REVIEW VISIBLE DESIGN WINS').run();
  window.bridge.flush();await pause(1100);assert(window.bridge.status==='Applied','Design transition was not applied');
  send('assert-review-design');await pause(200);
  drafts=undefined;window.bridge.sendToHost({type:'listDrafts'});for(let i=0;i<100 && !drafts;i++)await pause(50);
  const retainedRaw=drafts?.find(d=>d.locationId===implementationId && d.fileName===designTarget.element.fileName);
  assert(retainedRaw?.doc.xmlEdited && retainedRaw.doc.rawXml.includes('REVIEW HIDDEN RAW') && retainedRaw.applyAllowed===false,'Design ACK discarded or authorized the persisted raw draft');

  window.bridge.sendToHost({type:'openSymbol',...declaration,line:declaration.lineNumber});await pause(400);
  send('format-group-source');for(let i=0;i<500 && !window.__xmlDocNativeFormatted;i++)await pause(100);assert(window.__xmlDocNativeFormatted,'Native GroupB formatter did not complete');
  send('group-context-error');await pause(400);send('view-system');for(let i=0;i<200 && !window.xmlDocEditor.get().element.fileName?.toLowerCase().endsWith('system.pas');i++)await pause(100);const current=window.xmlDocEditor.get();assert(current.element.fileName?.toLowerCase().endsWith('system.pas') && current.element.readOnly,'System source is not read-only: '+JSON.stringify(current.element));assert(document.querySelector('#summary-editor .tiptap').contentEditable==='false','System source editable');window.chrome.webview.postMessage(JSON.stringify({type:'docUpdated',...current.element,doc:{...current.doc,summary:'FORBIDDEN READONLY WRITE'}}));await pause(250);send('assert-system');await pause(100);
  send('open-user-guide');await pause(300);send('large-editor-check');
 }catch(error){send('fail',{message:error.message,stack:error.stack});}
})();
