(async()=>{
 if(window.__xmlDocE2ERunning)return;window.__xmlDocE2ERunning=true;
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const assert=(test,text)=>{if(!test)throw Error(text);};
 const editSummary=text=>{const e=document.querySelector('#summary-editor .tiptap');e.focus();const range=document.createRange();range.selectNodeContents(e);const selection=getSelection();selection.removeAllRanges();selection.addRange(range);document.execCommand('insertText',false,text);};
 try{
  await pause(300);
  assert(document.querySelector('#workbench'),'Documentation tools missing');
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
  send('assert-project');
  const first=document.querySelector('#member-summaries input[data-id*="undocumentedfirst"]');
  const second=document.querySelector('#member-summaries input[data-id*="undocumentedsecond"]');
  assert(first&&second,'Member summaries missing');first.checked=true;second.checked=true;
  document.querySelector('#member-summaries textarea[data-id*="undocumentedfirst"]').value='E2E grid first';
  document.querySelector('#member-summaries textarea[data-id*="undocumentedsecond"]').value='E2E grid second';
  document.querySelector('#apply-summaries').click();assert(!document.querySelector('#operation-preview').hidden,'Batch edit needs a preview');document.querySelector('#apply-operation').click();await pause(650);send('assert-grid');
  send('finish');
 }catch(error){send('fail',{message:error.message,stack:error.stack});}
})();
