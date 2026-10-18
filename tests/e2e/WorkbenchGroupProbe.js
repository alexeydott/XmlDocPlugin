(async()=>{
 if(!window.xmlDocEditor || !window.xmlDocWorkbench || window.__xmlDocGroupE2E)return;
 window.__xmlDocGroupE2E=true;
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const assert=(test,text)=>{if(!test)throw Error(text);};
 try{
  let groupCatalog;const receive=window.xmlDocWorkbench.receiveCatalog;window.xmlDocWorkbench.receiveCatalog=data=>{groupCatalog=data;receive(data);};
  window.bridge.sendToHost({type:'requestCatalog',scope:'group'});
  for(let i=0;i<100 && !groupCatalog;i++)await pause(100);
  const fromB=groupCatalog?.elements.find(e=>e.name==='FromB' && e.params[0].type==='string');assert(fromB?.projectFile,'Project B context missing from group search');
  window.bridge.sendToHost({type:'openSymbol',projectFile:fromB.projectFile,fileName:fromB.fileName,symbolId:fromB.symbolId,line:fromB.lineNumber});for(let i=0;i<100 && window.xmlDocEditor.get().element.name!=='FromB';i++)await pause(100);
  assert(window.xmlDocEditor.get().element.name==='FromB' && window.xmlDocEditor.get().element.params[0].type==='string','Navigation to B failed: '+JSON.stringify(window.xmlDocEditor.get().element)+' status='+window.bridge.status);send('assert-group');
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
  send('format-group-source');for(let i=0;i<500 && !window.__xmlDocNativeFormatted;i++)await pause(100);assert(window.__xmlDocNativeFormatted,'Native GroupB formatter did not complete');
  send('view-system');await pause(2500);const current=window.xmlDocEditor.get();assert(current.element.readOnly,'System source is not read-only');assert(document.querySelector('#summary-editor .tiptap').contentEditable==='false','System source editable');window.chrome.webview.postMessage(JSON.stringify({type:'docUpdated',...current.element,doc:{...current.doc,summary:'FORBIDDEN READONLY WRITE'}}));await pause(250);send('assert-system');await pause(100);
  send('finish');
 }catch(error){send('fail',{message:error.message,stack:error.stack});}
})();
