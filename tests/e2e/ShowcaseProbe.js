(async()=>{
 const send=(action,extra={})=>chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const until=async(f,label)=>{for(let n=0;n<400;n++){if(f())return;await pause(50);}throw Error(label+'; '+document.querySelector('#ai-status')?.textContent);};
 const shot=async(name)=>{window.__aiScreenshot='';await pause(300);send('ai-screenshot',{name});await until(()=>window.__aiScreenshot===name,'Capture '+name);};
 try{
  send('showcase-open');
  await until(()=>window.xmlDocEditor.get().element?.name==='Run'&&window.xmlDocEditor.get().doc.summary.includes('surrounding whitespace'),'Showcase source');
  document.querySelector('#ai-assistant').open=false;
  document.querySelector('#member-signature').scrollIntoView({block:'start'});
  await shot('inspector');await shot('explorer');
  document.querySelector('#ai-assistant').open=true;
  await until(()=>document.querySelector('#ai-profile').options.length===1,'Example profile');
  document.querySelector('#ai-prepare').click();
  await until(()=>!document.querySelector('#ai-send').disabled,'Prepared example request');
  document.querySelector('#ai-send').click();
  await until(()=>!document.querySelector('#ai-proposal').hidden,'Example AI proposal');
  document.querySelector('#ai-request-preview').open=false;
  document.querySelector('#workbench').open=false;
  document.querySelector('#ai-assistant').scrollIntoView({block:'start'});
  await shot('ai-proposal');
  send('finish');
 }catch(e){send('fail',{message:e.message,stack:e.stack});}
})();
