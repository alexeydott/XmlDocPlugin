(async()=>{
 if(window.__xmlDocE2ERunning)return;window.__xmlDocE2ERunning=true;
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const until=async(predicate,description)=>{for(let attempt=0;attempt<100;attempt++){if(predicate())return;await pause(50);}throw Error(description+'; status='+window.bridge.status+'; document='+JSON.stringify(window.xmlDocEditor.get().element));};
 let loads=0;window.addEventListener('documentationLoaded',()=>loads++);
 const assert=(test,text)=>{if(!test)throw Error(text);};
 const capture=async(name,anchor)=>{if(!window.__guideScreenshots)return;if(anchor){const el=document.querySelector(anchor);for(let p=el?.parentElement;p;p=p.parentElement)if(p.tagName==='DETAILS')p.open=true;el?.scrollIntoView({block:'start'});}window.__aiScreenshot='';await pause(150);send('ai-screenshot',{name});await until(()=>window.__aiScreenshot===name,'Screenshot '+name);};
 const editSummary=text=>{const e=document.querySelector('#summary-editor .tiptap');assert(e?.editor,'TipTap editor unavailable');e.editor.chain().focus().selectAll().insertContent(text).run();};

 try{
  await pause(300);
  assert(document.querySelector('#workbench'),'Documentation tools missing');
  const originalDoc=JSON.stringify(window.xmlDocEditor.get().doc);
  for(const [language,caption,hint] of [['ru','Описание','Восстановить черновики'],['zh','摘要','恢复草稿'],['ko','요약','초안 복구'],['ja','概要','下書きを復元'],['en','Summary','Recover drafts']]){
   send('language-ui',{language});for(let i=0;i<100 && (window.__xmlDocLanguageUi!==language || document.documentElement.lang!==language);i++)await pause(100);
   assert(window.__xmlDocLanguageUi===language && document.documentElement.lang===language,'Language did not reach editor: '+language);
   assert(document.querySelector('[data-section=summary]').textContent.includes(caption),'Heading not translated: '+language);
   assert(document.querySelector('#recover-drafts').title===hint,'SVG tooltip not translated: '+language);
   const previousStatus=window.bridge.status;window.bridge.setStatus('Source changed — reload before applying');
   await until(()=>document.querySelector('#edit-status').textContent!=='Source changed — reload before applying'||language==='en','Conflict status not translated: '+language);
   assert(window.bridge.status==='Source changed — reload before applying','Localization changed the bridge protocol');
   window.bridge.setStatus(previousStatus);
   const parameter=document.querySelector('.td-name[data-ui-title]');
   assert(parameter?.textContent===window.xmlDocEditor.get().element.params[0].name,'Parameter identifier changed during localization');
   await until(()=>language==='en'||!parameter.title.startsWith('Double-click to go to method'),'Parameter navigation tooltip not translated: '+language);
   const script={ru:/[А-Яа-я]/,zh:/[\u3400-\u9fff]/,ko:/[\uac00-\ud7af]/,ja:/[\u3040-\u30ff\u3400-\u9fff]/}[language];
   if(script){const native=window.__nativeLocaleAudit;assert(native?.language===language,'Native locale audit missing');for(const key of ['settingsTitle','markerHint','generationTitle','coverageTitle'])assert(script.test(native[key]),'Native text not translated: '+language+' '+key);}
   document.querySelector('[data-action="help"]').click();
   await until(()=>document.querySelector('.help-modal-title') && (!script || script.test(document.querySelector('.help-modal-title').textContent)),'Tag reference not translated: '+language);
   const tagNames=Array.from(document.querySelectorAll('.help-tag-name')).map(e=>e.textContent);assert(tagNames.length===14&&tagNames.includes('<summary>')&&tagNames.includes('<see cref>'),'XML tag names were lost');
   if(script)for(const e of document.querySelectorAll('.help-tag-desc,.help-tag-usage'))assert(script.test(e.textContent),'Tag reference prose not translated: '+language);
   document.querySelector('.help-modal-close').click();
   document.querySelector('#summary-editor .tiptap').editor.commands.focus();await pause(50);
   document.querySelector('[data-action="paramref"]').click();await pause(100);
   assert(document.querySelector('.popover-item-name')?.textContent===window.xmlDocEditor.get().element.params[0].name,'Parameter picker mismatch: '+language+' '+JSON.stringify({actual:document.querySelector('.popover-item-name')?.textContent,expected:window.xmlDocEditor.get().element.params[0].name,focused:document.querySelector('#summary-editor .tiptap').editor.isFocused,disabled:document.querySelector('[data-action="paramref"]').disabled,active:document.activeElement?.className,popovers:document.querySelectorAll('.popover').length}));
   document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}));

   assert(JSON.stringify(window.xmlDocEditor.get().doc)===originalDoc,'Language switch modified user documentation');
  }

  const previousSummaries=new Map();
  for(const [prefix,member,marker] of [['FIXME: ','UndocumentedFirst','ПРОВЕРИТЬ:'],['待补充：','UndocumentedSecond','待完善：'],['TODO: ','UndocumentedFirst','수정 필요:'],['TODO: ','UndocumentedSecond','要修正：']]){
   send('prefix-ui',{prefix,member});await until(()=>window.xmlDocEditor.get().element.name===member&&(previousSummaries.has(member)?window.xmlDocEditor.get().doc.summary===previousSummaries.get(member):window.xmlDocEditor.get().doc.summary.startsWith(prefix)),'Custom prefix was not used in native stub');
   assert(document.querySelector('#documentation-problems').textContent.includes('XD008'),'Custom stub was incorrectly treated as ready');
   const summary=marker+' Pending summary for '+member;editSummary(summary);
   await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary===summary,'Custom stub edit was not acknowledged');
   assert(document.querySelector('#documentation-problems').textContent.includes('XD008'),'Recognized multilingual marker was incorrectly treated as ready: '+marker);
   document.querySelector('#refresh-catalog').click();
   const filter=document.querySelector('#catalog-filter');filter.value='todo';filter.dispatchEvent(new Event('change'));
   await until(()=>Array.from(document.querySelectorAll('.catalog-row')).some(row=>row.textContent.includes(summary)),'Configured prefix missing from unfinished catalog filter');
   filter.value='all';filter.dispatchEvent(new Event('change'));previousSummaries.set(member,summary);
  }
  send('prefix-restore');await until(()=>window.__prefixRestored&&window.xmlDocEditor.get().element.name==='Run','Prefix settings were not restored');

  const iconButtons=document.querySelectorAll('#workbench button[id].workbench-icon');
  assert(iconButtons.length===27,'Documentation tool icons are missing');
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
  document.body.style.width='';await capture('inspector','#summary-editor');send('assert-resources');
  assert(window.xmlDocEditor.get().element.signature.includes('string'),'String overload was not selected: '+JSON.stringify(window.xmlDocEditor.get().element));
  editSummary('E2E draft for A');send('switch-second');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TSecond','File switch did not load B');send('assert-cancelled');
  send('switch-sample');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TDocumented'&&window.xmlDocEditor.get().element.signature.includes('string'),'Sample was not loaded');
  // Explicitly discard the cancelled draft before testing a fresh edit.
  const beforeReload=loads;document.querySelector('#reload-document').click();await until(()=>loads>beforeReload,'Reload source did not complete');
  send('arm-explorer');await pause(250);await capture('explorer');
  editSummary('E2E applied summary');await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary==='E2E applied summary','Fresh browser edit was not acknowledged');send('assert-write');await pause(100);send('stale-explorer');await pause(200);send('assert-second-view-conflict');
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
  assert(document.querySelector('#xml-after').textContent.includes('NewName'),'Preview did not map name');await capture('synchronization','#operation-preview');document.querySelector('#apply-operation').click();await pause(950);send('assert-sync');
  document.querySelector('#refresh-catalog').click();await pause(600);
  assert(document.querySelectorAll('.catalog-row').length>12,'Project catalog missing');
  const unfinished=document.querySelector('#catalog-filter');unfinished.value='todo';unfinished.dispatchEvent(new Event('change'));assert(document.querySelectorAll('.catalog-row').length>0,'Unfinished draft filter lost TODO stubs');unfinished.value='all';unfinished.dispatchEvent(new Event('change'));
  const query=document.querySelector('#catalog-query');query.value='TSecond';query.dispatchEvent(new Event('input'));assert(document.querySelectorAll('.catalog-row').length>0,'Project search failed');await capture('project-workspace','#catalog-query');query.value='';query.dispatchEvent(new Event('input'));
  for(const button of document.querySelectorAll('#workbench button')){
   assert(button.querySelector('svg') && button.title && button.getAttribute('aria-label'),'Remaining textual/dynamic action: '+button.id+' '+button.textContent);
   assert(!button.textContent.trim(),'Remaining action description must be a hint');
  }
  assert(document.querySelector('.catalog-row .symbol-caption')?.textContent.trim(),'Symbol identity must remain readable');
  if(window.__guideScreenshots){
   for(const [id,value] of [['template-section','param'],['template-scope','project'],['template-kind','method'],['template-name','Options'],['template-type','Integer'],['template-text','Controls how the operation is performed.'],['project-terms','MapRenderer\nGeoJSON']])document.getElementById(id).value=value;
   await capture('wording','#template-section');
   document.getElementById('find-doc').value='Documentation';document.getElementById('replace-doc').value='API documentation';document.getElementById('replace-all').click();
   await capture('replacement','#operation-preview');document.getElementById('cancel-operation').click();
  }
  send('assert-project');
  const first=document.querySelector('#member-summaries input[data-id*="undocumentedfirst"]');
  const second=document.querySelector('#member-summaries input[data-id*="undocumentedsecond"]');
  assert(first&&second,'Member summaries missing');first.checked=true;second.checked=true;
  document.querySelector('#member-summaries textarea[data-id*="undocumentedfirst"]').value='E2E grid first';
  document.querySelector('#member-summaries textarea[data-id*="undocumentedsecond"]').value='E2E grid second';
  document.querySelector('#apply-summaries').click();assert(!document.querySelector('#operation-preview').hidden,'Batch edit needs a preview');document.querySelector('#apply-operation').click();await pause(200);
  for(let attempt=0;document.querySelector('#apply-summaries').disabled&&attempt<100;attempt++)await pause(100);
  assert(!document.querySelector('#apply-summaries').disabled,'Batch acknowledgement did not settle');send('assert-grid');
  const repeated=document.querySelector('#member-summaries textarea[data-id*="undocumentedfirst"]');
  repeated.value='E2E grid first again';repeated.dispatchEvent(new Event('input',{bubbles:true}));
  document.querySelector('#member-summaries input[data-id*="undocumentedfirst"]').checked=true;
  document.querySelector('#apply-summaries').click();assert(!document.querySelector('#operation-preview').hidden,'Repeated batch preview missing: '+window.bridge.status);document.querySelector('#apply-operation').click();await pause(200);
  for(let attempt=0;document.querySelector('#apply-summaries').disabled&&attempt<100;attempt++)await pause(100);
  assert(!document.querySelector('#apply-summaries').disabled,'Repeated batch acknowledgement did not settle');send('assert-grid-repeat');
  send('switch-sample');await pause(350);
  document.querySelector('#doc-tabs [data-tab=design]').click();
  window.bridge.setPinned(true);window.bridge.sendToHost({type:'pin',pinned:true});
  editSummary('E2E ACK first');window.bridge.flush();editSummary('E2E ACK second');
  await pause(1400);
  assert(window.xmlDocEditor.get().doc.summary==='E2E ACK second','ACK discarded newer edit');
  assert(window.bridge.status==='Applied','Second edit was not saved after ACK: '+window.bridge.status);
  editSummary('E2E pinned third');await pause(1100);
  assert(window.bridge.status==='Applied','Pinned second save used stale context');
  document.querySelector('#summary-editor .tiptap').dispatchEvent(new KeyboardEvent('keydown',{key:'z',code:'KeyZ',ctrlKey:true,bubbles:true}));
  await pause(100);assert(window.xmlDocEditor.get().doc.summary==='E2E ACK second','Panel Undo history was lost after autosave');await pause(1000);
  window.bridge.setPinned(false);window.bridge.sendToHost({type:'pin',pinned:false});
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
   assert(document.querySelector('#summary-editor .tiptap').contentEditable==='true','Rich editor did not unlock: '+mode);
  }
  for(const [config,platform,first,second] of [['Debug','Win32','Integer','Integer'],['Release','Win32','string','Integer'],['Debug','Win64','Integer','Int64'],['Debug','Win32','Integer','Integer']]){
   const requestId=config+'|'+platform+'|'+performance.now();send('context',{config,platform,requestId});
   for(let wait=0;wait<100 && window.__xmlDocContextReady!==requestId;wait++)await pause(50);
   assert(window.__xmlDocContextReady===requestId,'Native context switch did not complete: '+config+' '+platform);
   const e=window.xmlDocEditor.get().element;
   assert(e.name==='ContextProbe' && e.params[0].type===first && e.params[1].type===second,'Stale IDE configuration/platform: '+JSON.stringify(e));
  }
  send('prepare-group');return;
 }catch(error){send('fail',{message:error.message,stack:error.stack});}
})();
