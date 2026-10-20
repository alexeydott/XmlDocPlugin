(async()=>{
const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
const $=id=>document.getElementById(id), pause=ms=>new Promise(r=>setTimeout(r,ms));
const until=async(f,label)=>{for(let i=0;i<5000;i++){if(f())return;await pause(50);}throw Error(label);};
const observations=[];
try{
send('live-review-arm');await until(()=>window.__liveArmed&&$('ai-profile').options.length===1,'arm');
const initial=JSON.stringify(window.xmlDocEditor.get().doc);
const phase=async name=>{window.__livePhase='';send('live-review-phase',{phase:name});await until(()=>window.__livePhase===name,'phase');};
const observe=async name=>{await until(()=>$('ai-assistant').getAttribute('aria-busy')==='false','response');await pause(150);const offered=!$('ai-proposal').hidden;const o={phase:name,offered,status:$('ai-status').textContent,summary:offered?$('ai-summary').value:'',parameters:offered?Array.from(document.querySelectorAll('#ai-parameters textarea')).map(p=>({name:p.dataset.name,text:p.value})):[],returns:offered&&!$('ai-returns-section').hidden?$('ai-returns').value:null,remarks:offered&&!$('ai-remarks-section').hidden?$('ai-remarks').value:null,changes:$('ai-changes').textContent};observations.push(o);send('real-ai-observation',o);};
for(const [name,button] of [['describe','ai-describe'],['review','ai-review']]){await phase(name);$(button).click();await pause(250);await observe(name);$('ai-cancel').click();}
if(JSON.stringify(window.xmlDocEditor.get().doc)!==initial)throw Error('Review changed document');
await phase('queue-first');send('review-queue-start');await pause(500);await observe('queue-first');
await phase('queue-second');$('ai-queue-next').click();await until(()=>window.xmlDocEditor.get().element.qualifiedParent==='TSecond','queue navigation');await pause(500);await observe('queue-second');$('ai-queue-cancel').click();
send('real-ai-observation',{phase:'live-summary',observations});send('live-review-finish');
}catch(e){send('fail',{message:e.message,stack:e.stack});}
})();
