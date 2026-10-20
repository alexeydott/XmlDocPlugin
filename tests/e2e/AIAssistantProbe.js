(async()=>{
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));const until=async(f,label)=>{for(let i=0;i<200;i++){if(f())return;await pause(50);}throw Error(label+' '+document.querySelector('#ai-status').textContent);};const assert=(v,m)=>{if(!v)throw Error(m);};const click=id=>document.getElementById(id).click();
 const capture=async(name)=>{const language=document.documentElement.lang;if(language!=='en'){send('language-ui',{language:'en'});await until(()=>window.__xmlDocLanguageUi==='en','Screenshot language');}window.__aiScreenshot='';if(name!=='ai-preview')document.querySelector('#ai-request-preview').open=false;document.querySelector(name==='inspector'?'#member-signature':'#ai-assistant').scrollIntoView({block:'start'});await pause(80);send('ai-screenshot',{name});await until(()=>window.__aiScreenshot===name,'Screenshot not saved');if(language&&language!=='en'){send('language-ui',{language});await until(()=>window.__xmlDocLanguageUi===language,'Restore screenshot language');}};
 const prepare=async()=>{click('ai-prepare');await until(()=>!document.querySelector('#ai-send').disabled,'Request not prepared');};
 try{
  send('language-ui',{language:'en'});await until(()=>window.__xmlDocLanguageUi==='en','Screenshot language');send('ai-test-arm');await until(()=>window.__aiTestArmed&&document.querySelector('#ai-profile').options.length===1,'Mock profile missing');
  assert(document.querySelector('#ai-template').hidden===(document.querySelector('#ai-template').options.length<2),'Template visibility does not match the available choices');assert(document.querySelector('#ai-operation').title!==document.querySelector('#ai-template').title,'AI selectors need distinct hints');
  document.querySelector('#ai-template').value='custom-describe';
  const before=window.xmlDocEditor.get();
  for(const id of ['ai-settings','ai-describe','ai-rephrase'])assert(document.getElementById(id).dataset.workbenchIcon===id,'Wrong AI action icon: '+id);
  await capture('inspector');await prepare();assert(document.querySelector('#ai-request').textContent.includes('procedure TDocumented.Run(const Value:string);'),'Wrong implementation in prompt');await capture('ai-preview');click('ai-send');await capture('ai-waiting');await until(()=>!document.querySelector('#ai-proposal').hidden,'No AI proposal');await capture('ai-proposal');
  const proposed=document.querySelector('#ai-summary');proposed.value=proposed.value.replace('Returns immediately when the supplied value is empty.','Returns without further processing when the value is empty.');proposed.dispatchEvent(new Event('input'));click('ai-apply');await until(()=>window.xmlDocEditor.get().doc.summary.startsWith('Returns without further processing when the value is empty.')&&window.bridge.status==='Applied','AI apply not acknowledged');send('ai-write-checked');await until(()=>window.__aiUndoRedo,'No AI Undo/Redo');
  click('ai-rephrase');await until(()=>!document.querySelector('#ai-send').disabled,'Rephrase was not prepared');assert(document.querySelector('#ai-request').textContent.includes('without adding, removing or changing factual claims'),'Rephrase used the wrong prompt');click('ai-send');await until(()=>!document.querySelector('#ai-proposal').hidden,'No rephrase proposal');
  const revisionBeforeRephrase=window.bridge.captureStamp().sourceRevision;
  proposed.value=proposed.value.replace('Returns immediately when the supplied value is empty.','Stops processing immediately for an empty value.');proposed.dispatchEvent(new Event('input'));click('ai-apply');await until(()=>window.xmlDocEditor.get().doc.summary.startsWith('Stops processing immediately for an empty value.')&&window.bridge.status==='Applied'&&window.bridge.captureStamp().sourceRevision!==revisionBeforeRephrase,'Rephrase not applied');send('ai-rephrase-checked');
  // A late response must not write into B.
  await prepare();click('ai-send');send('switch-second');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TSecond','No B');await pause(600);assert(document.querySelector('#ai-apply').disabled,'Late A response can apply to B');click('ai-cancel');send('switch-sample');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TDocumented','No A');
  // Keep a local modification unsent until the delayed response arrives.
  window.bridge.saveDebounceMs=5000;await prepare();click('ai-send');document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('Local AI draft wins').run();await pause(600);assert(document.querySelector('#ai-apply').disabled,'AI overwrote newer local text');assert(window.xmlDocEditor.get().doc.summary==='Local AI draft wins','Local draft lost');click('ai-cancel');click('reload-document');await pause(250);
  click('open-xml');const xml=document.querySelector('#xml-source');xml.value='<summary>Unapproved AI XML</summary>';xml.dispatchEvent(new Event('input'));click('ai-describe');assert(document.querySelector('#ai-send').disabled,'AI started with an XML draft');
  for(const language of ['ru','zh','ko','ja']){send('language-ui',{language});await until(()=>window.__xmlDocLanguageUi===language,'Locale failed');assert(xml.value==='<summary>Unapproved AI XML</summary>','Locale modified XML draft');}
  click('reload-document');await pause(250);document.querySelector('[data-tab=design]').click();await prepare();click('ai-send');send('ai-body-change');await until(()=>window.__aiBodyChanged,'No body mutation');await pause(600);assert(document.querySelector('#ai-apply').disabled,'Changed method body accepted');click('ai-cancel');click('reload-document');await pause(250);
  send('ai-preview-off');await until(()=>window.__previewOff,'Preview setting missing');click('ai-describe');await until(()=>document.querySelector('#ai-assistant').getAttribute('aria-busy')==='true','No AI wait interface');assert(document.querySelector('#ai-request-preview').hidden,'Default flow forced a preview');await until(()=>!document.querySelector('#ai-proposal').hidden,'Automatic send did not finish');click('ai-cancel');
  send('ai-clear-param');await until(()=>window.__aiParamCleared&&window.xmlDocEditor.get().doc.params.some(p=>p.name==='Value'&&!p.description),'Missing parameter fixture not loaded');click('ai-describe');await until(()=>!document.querySelector('#ai-proposal').hidden,'No parameter proposal');const parameter=document.querySelector('#ai-parameters textarea[data-name=Value]');assert(parameter&&parameter.value==='Input text to process.','Parameter suggestion missing');await capture('ai-proposal');parameter.value='Reviewed input parameter';parameter.dispatchEvent(new Event('input'));click('ai-apply');await until(()=>window.xmlDocEditor.get().doc.params.some(p=>p.name==='Value'&&p.description==='Reviewed input parameter')&&window.bridge.status==='Applied','AI parameter not acknowledged');send('ai-param-checked');
  const instruction=document.getElementById('ai-instruction');instruction.value='HTML cleanup fixture';instruction.dispatchEvent(new Event('input'));click('ai-describe');await until(()=>!document.querySelector('#ai-proposal').hidden,'No HTML cleanup proposal');
  assert(document.getElementById('ai-summary').value.startsWith('First formatted paragraph.\n\nSecond paragraph.'),'Provider HTML not cleaned');assert(!document.getElementById('ai-summary').value.includes('providerHtmlFixture'),'Script content survived');click('ai-apply');await until(()=>window.xmlDocEditor.get().doc.summary.includes('<para>First formatted paragraph.</para>')&&window.bridge.status==='Applied','HTML paragraphs not applied');send('ai-html-checked');await until(()=>window.__aiHTMLChecked,'HTML source not checked');
  instruction.value='';instruction.dispatchEvent(new Event('input'));click('ai-cancel');
  send('language-ui',{language:'en'});await until(()=>window.__xmlDocLanguageUi==='en','Review language failed');
  const select=async(name,param='')=>{send('review-select',{name,param});await until(()=>window.xmlDocEditor.get().element.name===name&&(!param||window.xmlDocEditor.get().element.params[0]?.type===param),'Review selection failed');await pause(250);};
  const checkSource=async(text,label)=>{window.__reviewSourceChecked=false;send('review-source-check',{text,label});await until(()=>window.__reviewSourceChecked,'OTA review check failed');};
  await select('Run','Integer');click('refresh-catalog');await until(()=>document.querySelector('#inheritance-sources button[data-workbench-icon="copy-documentation"]'),'Inherited source missing');
  window.bridge.saveDebounceMs=5000;
  document.querySelector('#remarks-editor .tiptap').editor.commands.clearContent();
  document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('New local summary before inherited copy').run();
  document.querySelector('#inheritance-sources button[data-workbench-icon="copy-documentation"]').click();
  assert(document.querySelector('#xml-after').textContent.includes('New local summary before inherited copy'),'Inherited preview resurrected old summary');
  assert(document.querySelector('#xml-after').textContent.includes('The input value.'),'Missing inherited parameter not copied');click('apply-operation');
  await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary==='New local summary before inherited copy','Inherited copy not acknowledged');
  await checkSource('New local summary before inherited copy','inherited copy preserves local summary');
  await checkSource('Inherited numeric processing remarks.','inherited copy fills missing remarks');
  window.bridge.saveDebounceMs=100;
  await select('Run','string');click('open-xml');const reviewXml=document.getElementById('xml-source');
  reviewXml.value='<summary><para>Editable prose <b>bold wording</b><br/>second line <see cref="TDocumentedBase"/><c>$&amp;</c></para></summary><param name="Value">Existing parameter stays.</param>';
  reviewXml.dispatchEvent(new Event('input'));click('apply-xml');await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary.includes('bold wording'),'XML setup not applied');
  document.querySelector('[data-tab=design]').click();instruction.value='XML rephrase fixture';instruction.dispatchEvent(new Event('input'));click('ai-rephrase');await until(()=>!document.querySelector('#ai-proposal').hidden,'XML rephrase failed');
  const restored=document.getElementById('ai-after').textContent;
  assert(restored.includes('<see cref="TDocumentedBase"')&&restored.includes('<c>$&amp;</c>')&&!restored.includes('__XMLDOC_'),'Protected XML preview corrupted: '+restored);
  click('ai-apply');await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary.includes('Returns immediately'),'XML proposal not applied');
  await checkSource('<c>$&amp;</c>','XML rephrase preserves literal code and references');click('ai-cancel');instruction.value='';instruction.dispatchEvent(new Event('input'));
  await select('NoBody');click('ai-rephrase');await until(()=>!document.querySelector('#ai-proposal').hidden,'Bodyless Rephrase failed');click('ai-apply');
  await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary.includes('Returns immediately'),'Bodyless Rephrase not applied');
  await checkSource('procedure NoBody;virtual;abstract;','bodyless Rephrase leaves abstract declaration intact');click('ai-cancel');
  click('ai-describe');await until(()=>/implementation|body/i.test(document.getElementById('ai-status').textContent),'Bodyless Describe diagnosis missing');
  assert(document.querySelector('#ai-proposal').hidden,'Bodyless Describe unexpectedly produced a proposal');click('ai-cancel');
  let quick;const receiveQuick=window.xmlDocWorkbench.receiveQuickDoc;window.xmlDocWorkbench.receiveQuickDoc=data=>{quick=data;receiveQuick(data);};
  for(const [marker,local] of [['review-local-call',true],['review-self-call',false]]){
   quick=undefined;window.__reviewQuickReady=false;send('review-quick',{marker});await until(()=>window.__reviewQuickReady,'Quick cursor missing');await pause(200);
   window.bridge.sendToHost({type:'requestQuickDoc'});await until(()=>quick,'Quick result missing');
   if(local)assert(quick.resolved&&quick.matches.length===1&&quick.matches[0].symbolId.toLowerCase().includes('scopeprobe'),'Wrong lexical target: '+JSON.stringify(quick));
   else {
    assert(quick.resolved&&quick.matches.length===1&&quick.matches[0].symbolId.toLowerCase().endsWith(':tdocumented.run(integer):'),'Self literal overload did not resolve to the overriding method: '+JSON.stringify(quick));
   }
  }
  await checkSource('procedure TDocumented.ScopeProbe;','Quick Documentation lexical target and explicit Self candidates');
  await select('Calculate','Integer');click('ai-review');await until(()=>!document.querySelector('#ai-proposal').hidden,'Review operation did not return a proposal');
  assert(document.querySelector('#ai-changes').textContent.includes('Value + Other'),'Review explanation missing');
  for(const id of ['ai-accept-summary','ai-accept-remarks']){const check=document.getElementById(id);check.checked=false;check.dispatchEvent(new Event('change'));}
  const other=document.querySelector('#ai-parameters textarea[data-name=Other]');assert(other,'Review did not expose an existing parameter');
  const otherCheck=other.parentElement.querySelector('input[type=checkbox]');otherCheck.checked=false;otherCheck.dispatchEvent(new Event('change'));
  await capture('ai-proposal');
  click('ai-apply');await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.returns==='The sum of Value and Other.','Selected sections not acknowledged');
  send('review-calculate-checked');await until(()=>window.__reviewCalculateChecked,'Native section check missing');
  send('review-queue-start');await until(()=>!document.querySelector('#ai-proposal').hidden&&!document.querySelector('#ai-queue').hidden,'Queue did not prepare the first method');
  click('ai-queue-next');await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TSecond','Queue did not open the second method');
  await until(()=>!document.querySelector('#ai-proposal').hidden,'Queue did not request the second method');click('ai-queue-cancel');
  send('review-queue-checked');await until(()=>window.__reviewQueueChecked,'Native queue check missing');
  send('ai-close-pending');
 }catch(e){send('fail',{message:e.message+' status='+window.bridge.status+' summary='+window.xmlDocEditor.get().doc.summary,stack:e.stack});}
})();
