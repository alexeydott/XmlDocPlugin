(async()=>{
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));const until=async(f,label)=>{for(let i=0;i<200;i++){if(f())return;await pause(50);}throw Error(label+' '+document.querySelector('#ai-status').textContent);};const assert=(v,m)=>{if(!v)throw Error(m);};const click=id=>document.getElementById(id).click();
 const prepare=async()=>{click('ai-describe');await until(()=>!document.querySelector('#ai-send').disabled,'Request not prepared');};
 try{
  send('ai-test-arm');await until(()=>window.__aiTestArmed&&document.querySelector('#ai-profile').options.length===1,'Mock profile missing');
  const before=window.xmlDocEditor.get();
  await prepare();assert(document.querySelector('#ai-request').textContent.includes('procedure TDocumented.Run(const Value:string);'),'Wrong implementation in prompt');click('ai-send');await until(()=>!document.querySelector('#ai-proposal').hidden,'No AI proposal');
  const proposed=document.querySelector('#ai-summary');proposed.value=proposed.value.replace('Native AI proposed summary','Native AI reviewed summary');proposed.dispatchEvent(new Event('input'));click('ai-apply');await until(()=>window.xmlDocEditor.get().doc.summary.startsWith('Native AI reviewed summary')&&window.bridge.status==='Applied','AI apply not acknowledged');send('ai-write-checked');await until(()=>window.__aiUndoRedo,'No AI Undo/Redo');
  click('ai-rephrase');await until(()=>!document.querySelector('#ai-send').disabled,'Rephrase was not prepared');assert(document.querySelector('#ai-request').textContent.includes('without adding, removing or changing factual claims'),'Rephrase used the wrong prompt');click('ai-send');await until(()=>!document.querySelector('#ai-proposal').hidden,'No rephrase proposal');
  const revisionBeforeRephrase=window.bridge.captureStamp().sourceRevision;
  proposed.value=proposed.value.replace('Native AI proposed summary','Rephrased native summary');proposed.dispatchEvent(new Event('input'));click('ai-apply');await until(()=>window.xmlDocEditor.get().doc.summary.startsWith('Rephrased native summary')&&window.bridge.status==='Applied'&&window.bridge.captureStamp().sourceRevision!==revisionBeforeRephrase,'Rephrase not applied');send('ai-rephrase-checked');
  // A late response must not write into B.
  await prepare();click('ai-send');send('switch-second');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TSecond','No B');await pause(600);assert(document.querySelector('#ai-apply').disabled,'Late A response can apply to B');click('ai-cancel');send('switch-sample');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TDocumented','No A');
  // Keep a local modification unsent until the delayed response arrives.
  window.bridge.saveDebounceMs=5000;await prepare();click('ai-send');document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('Local AI draft wins').run();await pause(600);assert(document.querySelector('#ai-apply').disabled,'AI overwrote newer local text');assert(window.xmlDocEditor.get().doc.summary==='Local AI draft wins','Local draft lost');click('ai-cancel');click('reload-document');await pause(250);
  click('open-xml');const xml=document.querySelector('#xml-source');xml.value='<summary>Unapproved AI XML</summary>';xml.dispatchEvent(new Event('input'));click('ai-describe');assert(document.querySelector('#ai-send').disabled,'AI started with an XML draft');
  for(const language of ['ru','zh','ko','ja']){send('language-ui',{language});await until(()=>window.__xmlDocLanguageUi===language,'Locale failed');assert(xml.value==='<summary>Unapproved AI XML</summary>','Locale modified XML draft');}
  click('reload-document');await pause(250);document.querySelector('[data-tab=design]').click();await prepare();click('ai-send');send('ai-body-change');await until(()=>window.__aiBodyChanged,'No body mutation');await pause(600);assert(document.querySelector('#ai-apply').disabled,'Changed method body accepted');click('ai-cancel');click('reload-document');await pause(250);
  send('ai-close-pending');
 }catch(e){send('fail',{message:e.message,stack:e.stack});}
})();
