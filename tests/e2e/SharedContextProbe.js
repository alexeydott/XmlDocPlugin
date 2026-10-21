window.runSharedContextAcceptance=async()=>{
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const assert=(v,m)=>{if(!v)throw Error(m);};const until=async(f,m)=>{for(let i=0;i<300;i++){if(f())return;await pause(50);}throw Error(m);};
 send('shared-context-arm');await until(()=>window.__sharedContextReady,'Shared project setup failed');send('shared-progress',{message:'JavaScript resumed after setup'});
 for(const target of window.__sharedTargets){
  send('shared-progress',{message:'Navigate '+target.projectFile});window.bridge.sendToHost(target);await until(()=>window.xmlDocEditor.get().element.fileName===target.fileName,'Shared source did not load');await pause(500);
  const element=window.xmlDocEditor.get().element;assert(element.projectFile?.toLowerCase()===target.projectFile.toLowerCase(),'Shared source loaded the wrong project: '+JSON.stringify(element));
  document.getElementById('ai-prepare').click();await until(()=>!document.getElementById('ai-send').disabled,'Shared AI capture failed: '+document.getElementById('ai-status').textContent);
  const request=JSON.parse(document.getElementById('ai-request').textContent),text=request.messages.map(m=>m.content).join('\n');const expected=target.projectFile.includes('SharedB')?'B':'A';
  assert(text.includes('SHARED_TERM_'+expected)&&!text.includes('SHARED_TERM_'+(expected==='A'?'B':'A')),'AI terms belong to another project: '+target.projectFile);
  const match=text.match(/defines\[\d+\]: ([^\n]+)/);assert(match&&match[1].split(',').includes('SHARED_'+expected),'AI defines belong to another project');
  document.getElementById('ai-cancel').click();
 }
 send('shared-context-finish');await until(()=>window.__sharedContextChecked,'Shared context source check missing');
};
