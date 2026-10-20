(async()=>{
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));const assert=(value,message)=>{if(!value)throw Error(message);};
 const until=async(f,label)=>{for(let i=0;i<400;i++){if(f())return;await pause(50);}throw Error(label+'; status='+window.bridge.status);};
 let catalog=null;const receive=window.xmlDocWorkbench.receiveCatalog;
 window.xmlDocWorkbench.receiveCatalog=data=>{catalog=data;receive(data);};
 const poll=setInterval(()=>send('parser-poll-state'),100);
 try{
  send('parser-break-source');
  await until(()=>window.__nativeParseErrors&&window.bridge.readOnly&&window.xmlDocEditor.get().element?.fileName?.endsWith('ParserRecovery.pas'),'Failure details or read-only card did not appear automatically');
  assert(!document.querySelector('#reload-document').disabled,'Reload is disabled');assert(!document.querySelector('#refresh-catalog').disabled,'Workspace navigation is disabled');
  window.bridge.sendToHost({type:'docUpdated',fileName:window.xmlDocEditor.get().element.fileName,sessionId:'',symbolId:'forged',doc:{summary:'FORBIDDEN AFTER PARSE FAILURE'}});
  await pause(100);send('parser-error-observed');
  catalog=null;document.querySelector('#refresh-catalog').click();
  await until(()=>catalog?.errors?.some(e=>e.includes('ParserRecovery.pas')),'Project catalog did not publish healthy modules with error details');
  assert(catalog.elements.length>0,'Healthy modules were lost');assert(!catalog.elements.some(e=>e.fileName.endsWith('ParserRecovery.pas')),'Incomplete module was published as valid');
  assert(document.querySelector('#catalog-errors pre').textContent.includes('Line: 9'),'Detailed catalog diagnostic is missing');
  send('parser-fix-source');
  await until(()=>window.__nativeParseRecovered&&!window.bridge.readOnly&&window.xmlDocEditor.get().doc.summary==='Recovered automatically','Corrected unsaved buffer did not restore the Inspector automatically');
  catalog=null;document.querySelector('#refresh-catalog').click();
  await until(()=>catalog&&!catalog.errors?.length&&catalog.elements.some(e=>e.fileName.endsWith('ParserRecovery.pas')&&e.name==='Healthy'),'Corrected module did not rejoin project analysis');
  send('parser-recovery-complete');
 }catch(error){send('fail',{message:error.message,stack:error.stack});}
 finally{clearInterval(poll);window.xmlDocWorkbench.receiveCatalog=receive;}
})();
