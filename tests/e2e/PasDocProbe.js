(async()=>{
 const send=(action,extra={})=>chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const wait=ms=>new Promise(r=>setTimeout(r,ms));
 const assert=(value,message)=>{if(!value)throw Error(message);};
 const until=async(test,label)=>{for(let n=0;n<1800;n++){if(test())return;await wait(100);}throw Error(label+'; status='+window.bridge.status+' '+JSON.stringify(window.xmlDocEditor.get()));};
 try{
  send('pasdoc-open',{name:'TPasDocSample'});
  await until(()=>window.xmlDocEditor.get().element?.name==='TPasDocSample'&&window.xmlDocEditor.get().doc.summary.includes('Sample class for legacy documentation import'),'TPasDocSample abstract');
  send('real-ai-observation',{phase:'pasdoc-class',document:window.xmlDocEditor.get()});
  send('pasdoc-open',{name:'ConvertValue'});
  await until(()=>window.xmlDocEditor.get().element?.name==='ConvertValue','ConvertValue selected');
  const imported=window.xmlDocEditor.get().doc;
  assert(imported.summary.includes('Convert a value using a scale factor'),'Method abstract missing');
  assert(JSON.stringify(imported).includes('The input value to convert'),'Value sidecar description missing');
  assert(JSON.stringify(imported).includes('The scale factor applied to the input'),'Scale sidecar description missing');
  assert(imported.returns.includes('The converted value'),'Sidecar return missing');
  assert(imported.params.length===2&&!JSON.stringify(imported).includes('This parameter must be ignored'),'Unknown sidecar parameter was imported');
  send('real-ai-observation',{phase:'pasdoc-method',document:window.xmlDocEditor.get()});
  send('pasdoc-includes');
  await until(()=>JSON.stringify(window.xmlDocEditor.get().doc).includes('Imported include marker'),'include content');
  assert(JSON.stringify(window.xmlDocEditor.get().doc).includes('Result := Value + 17;'),'includeCode content');
  await wait(500);send('pasdoc-refresh');
  await until(()=>window.__pasdocFreshRevision&&window.xmlDocEditor.get().element.sourceRevision===window.__pasdocFreshRevision,'Settled source revision');
  send('real-ai-observation',{phase:'pasdoc-includes',document:window.xmlDocEditor.get()});
  const editor=document.querySelector('#summary-editor .tiptap').editor;
  editor.chain().focus().selectAll().insertContent('PasDoc OTA applied marker').run();
  await until(()=>window.bridge.status==='Applied','IDE Apply ACK');
  send('pasdoc-written');await until(()=>window.__pasdocUndone,'Native Undo');
  send('finish');
 }catch(e){send('fail',{message:e.message,stack:e.stack});}
})();
