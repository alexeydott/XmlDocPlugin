(async()=>{
 if(window.__xmlDocE2ERunning)return;window.__xmlDocE2ERunning=true;
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const assert=(test,text)=>{if(!test)throw Error(text);};
 const editSummary=text=>{const e=document.querySelector('#summary-editor .tiptap');e.focus();const range=document.createRange();range.selectNodeContents(e);const selection=getSelection();selection.removeAllRanges();selection.addRange(range);document.execCommand('insertText',false,text);};
 try{
  await pause(300);
  assert(document.querySelector('#workbench'),'Documentation tools missing');
  const iconButtons=document.querySelectorAll('#workbench button[id].workbench-icon');
  assert(iconButtons.length===26,'Documentation tool icons are missing');
  for(const button of iconButtons){
   assert(button.querySelector('svg[aria-hidden="true"]'),'Tool must use an inline SVG: '+button.id);
   assert(button.title && button.getAttribute('aria-label'),'Tool needs a hint and accessible name: '+button.id);
   assert(!button.textContent.trim(),'Icon button retained its visible label: '+button.id);
  }
  // Initial host updates can replace the ProseMirror image node while the
  // WebView is loading. Observe the current DOM, not a detached first node.
  let image;
  for(let i=0;i<100;i++){
   image=document.querySelector('#remarks-editor img');
   if(image?.complete && image.naturalWidth>0)break;
   await pause(50);
  }
  assert(image?.isConnected && image.complete && image.naturalWidth>0,'Project image resource failed to load: '+image?.src+' base='+window.xmlDocResourceBase);
  document.body.style.width='320px';await pause(50);
  for(const field of document.querySelectorAll('#workbench input,#workbench textarea,#workbench select'))assert(field.getBoundingClientRect().width<=322,'Control exceeds narrow panel: '+field.id);
  for(const button of iconButtons)if(button.getClientRects().length)assert(button.getBoundingClientRect().width===30,'Icon button size changed: '+button.id);
  document.body.style.width='';send('assert-resources');
  assert(window.xmlDocEditor.get().element.signature.includes('string'),'String overload was not selected: '+JSON.stringify(window.xmlDocEditor.get().element));
  editSummary('E2E draft for A');await pause(25);send('switch-second');await pause(900);send('assert-cancelled');
  assert(window.xmlDocEditor.get().element.qualifiedParent==='TSecond','File switch did not load B');
  send('switch-sample');await pause(300);
  // Explicitly discard the cancelled draft before testing a fresh edit.
  document.querySelector('#reload-document').click();await pause(300);
  send('arm-explorer');await pause(250);
  editSummary('E2E applied summary');await pause(950);send('assert-write');await pause(100);send('stale-explorer');await pause(200);send('assert-second-view-conflict');
  send('undo');await pause(200);send('redo');await pause(200);
  const stale=window.xmlDocEditor.get();send('mutate-signature');await pause(150);
  window.bridge.sendToHost({type:'docUpdated',...stale.element,doc:{...stale.doc,summary:'SHOULD NOT WRITE'}});await pause(150);send('assert-conflict');
  assert(window.bridge.status.includes('Source changed'),'Stale edit has no conflict status');
  send('repair-signature');await pause(250);
  document.querySelector('#open-xml').click();assert(!document.querySelector('#doc-xml').classList.contains('hidden'),'XML view missing');
  document.querySelector('#xml-source').value='<summary>broken';document.querySelector('#apply-xml').click();assert(document.querySelector('#xml-error').textContent,'Malformed XML not diagnosed');
  send('switch-broken');await pause(250);assert(window.xmlDocEditor.get().doc.parseError,'Original malformed XML not retained');
  assert(document.querySelector('#xml-source').value.includes('Malformed XML'),'Original broken text lost');
  send('switch-rename');await pause(250);document.querySelector('#sync-document').click();
  const map=document.querySelector('#rename-mapping select');assert(map,'Rename mapping missing');map.value='NewName';map.dispatchEvent(new Event('change'));
  document.querySelector('#rename-mapping button').click();assert(!document.querySelector('#operation-preview').hidden,'Synchronization needs a preview');
  assert(document.querySelector('#xml-after').textContent.includes('NewName'),'Preview did not map name');document.querySelector('#apply-operation').click();await pause(950);send('assert-sync');
  document.querySelector('#refresh-catalog').click();await pause(600);
  assert(document.querySelectorAll('.catalog-row').length>12,'Project catalog missing');
  const query=document.querySelector('#catalog-query');query.value='TSecond';query.dispatchEvent(new Event('input'));assert(document.querySelectorAll('.catalog-row').length>0,'Project search failed');query.value='';query.dispatchEvent(new Event('input'));
  for(const button of document.querySelectorAll('#workbench button')){
   assert(button.querySelector('svg') && button.title && button.getAttribute('aria-label'),'Remaining textual/dynamic action: '+button.id+' '+button.textContent);
   assert(!button.textContent.trim(),'Remaining action description must be a hint');
  }
  assert(document.querySelector('.catalog-row .symbol-caption')?.textContent.trim(),'Symbol identity must remain readable');
  send('assert-project');
  const first=document.querySelector('#member-summaries input[data-id*="undocumentedfirst"]');
  const second=document.querySelector('#member-summaries input[data-id*="undocumentedsecond"]');
  assert(first&&second,'Member summaries missing');first.checked=true;second.checked=true;
  document.querySelector('#member-summaries textarea[data-id*="undocumentedfirst"]').value='E2E grid first';
  document.querySelector('#member-summaries textarea[data-id*="undocumentedsecond"]').value='E2E grid second';
  document.querySelector('#apply-summaries').click();assert(!document.querySelector('#operation-preview').hidden,'Batch edit needs a preview');document.querySelector('#apply-operation').click();await pause(650);send('assert-grid');
  const checkReadOnly=()=>{
   const current=window.xmlDocEditor.get();assert(current.element.readOnly,'Source is not marked read-only');
   assert(document.querySelector('#summary-editor .tiptap')?.contentEditable==='false','Rich editor remains editable');
   assert(document.querySelector('#xml-source').readOnly,'XML source remains editable');
   assert(document.querySelector('#apply-xml').disabled,'Apply XML remains enabled');
   for(const editor of document.querySelectorAll('#doc-design [contenteditable]'))assert(editor.contentEditable==='false','Description remains editable');
   assert(!document.querySelector('#focus-source').disabled,'Source navigation was disabled');
   window.chrome.webview.postMessage(JSON.stringify({type:'docUpdated',...current.element,doc:{...current.doc,summary:'FORBIDDEN READONLY WRITE'}}));
   window.chrome.webview.postMessage(JSON.stringify({type:'batchUpdated',changes:[{element:current.element,doc:{...current.doc,summary:'FORBIDDEN READONLY WRITE'}}]}));
  };
  for(const mode of ['file','buffer','system']){
   send('lock-source',{mode});await pause(600);checkReadOnly();await pause(200);send('assert-protected');await pause(300);
   assert(!window.xmlDocEditor.get().element.readOnly,'Writable source did not unlock: '+mode);
  }
  send('view-system');await pause(2500);checkReadOnly();await pause(250);send('assert-system');await pause(100);
  send('finish');
 }catch(error){send('fail',{message:error.message,stack:error.stack});}
})();
