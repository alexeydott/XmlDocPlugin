import {bridge} from './bridge';
import {translate} from './i18n';
import type {DocModel,ElementInfo} from './types';
import {escapeXml} from './xmlCodec';
import {parseXml,editableXml,analyze,meaningful} from './docTools';
import {setWorkbenchIcon} from './workbenchIcons';
interface Hooks {get:()=>{element:ElementInfo|null;doc:DocModel};apply:(doc:DocModel)=>void;}
type Stamp=ReturnType<typeof bridge.captureStamp>;
const proseXml=(text:string)=>{const escaped=escapeXml(text.replace(/\r\n?/g,'\n'));return escaped.includes('\n')?escaped.split('\n\n').filter(Boolean).map(p=>'<para>'+p.replace(/\n/g,'<br/>')+'</para>').join(''):escaped;};
export function initAIAssistant(hooks:Hooks):void {
 const panel=document.createElement('details');panel.id='ai-assistant';
 panel.innerHTML=`<summary>AI assistant</summary><div class="workbench-actions">
 <select id="ai-profile" aria-label="AI profile" title="AI profile"></select><select id="ai-operation" aria-label="AI operation" title="AI operation"><option value="describe">Describe method from code</option><option value="rephrase">Rephrase summary</option><option value="review">Review documentation against code</option></select><select id="ai-template" aria-label="Prompt template" title="Prompt template"></select>
 <button id="ai-settings">AI profiles and prompts</button><button id="ai-check">Test connection</button></div>
 <textarea id="ai-instruction" placeholder="Additional instructions (optional)" aria-label="Additional instructions"></textarea>
 <div id="ai-queue" hidden><output id="ai-queue-status" aria-live="polite"></output><button id="ai-queue-next">Skip and open next method</button><button id="ai-queue-cancel">Cancel AI queue</button></div>
 <div class="workbench-actions"><button id="ai-describe">Describe method from code</button><button id="ai-rephrase">Rephrase summary</button><button id="ai-review">Review documentation against code</button><button id="ai-prepare">Preview AI request</button><button id="ai-send" disabled>Send reviewed request</button><button id="ai-cancel">Cancel</button><output id="ai-status" aria-live="polite"></output></div>
 <div id="ai-wait" hidden role="status" aria-live="polite"><progress aria-label="AI request running"></progress><span>Waiting for AI response</span></div>
 <details id="ai-request-preview" hidden><summary>Request preview</summary><output id="ai-url" data-code></output><pre id="ai-request"></pre></details>
 <section id="ai-proposal" hidden><label><input id="ai-accept-summary" type="checkbox" checked>Accept summary<textarea id="ai-summary" aria-label="Suggested summary"></textarea></label><label id="ai-returns-section" hidden><input id="ai-accept-returns" type="checkbox">Accept return description<textarea id="ai-returns" aria-label="Suggested return description"></textarea></label><label id="ai-remarks-section" hidden><input id="ai-accept-remarks" type="checkbox">Accept remarks<textarea id="ai-remarks" aria-label="Suggested remarks"></textarea></label><div id="ai-parameters"></div><p>Keep protected XML tokens unchanged.</p><ul id="ai-changes" aria-label="Reasons for documentation changes"></ul><ul id="ai-uncertainties"></ul><div class="xml-diff"><pre id="ai-before"></pre><pre id="ai-after"></pre></div><button id="ai-apply" disabled>Apply selected documentation</button></section>`;
 document.querySelector('#workbench')?.after(panel);
 const $=<T extends HTMLElement=HTMLElement>(id:string)=>panel.querySelector('#'+id) as T;
 for(const [id,icon] of [['ai-settings','ai-settings'],['ai-check','refresh-catalog'],['ai-describe','ai-describe'],['ai-rephrase','ai-rephrase'],['ai-review','ai-review'],['ai-prepare','preview-change'],['ai-send','next-problem'],['ai-cancel','cancel-operation'],['ai-apply','apply-operation']])setWorkbenchIcon($(id),icon);
 let templates:any[]=[],requestId='',stamp:Stamp|null=null,base:{element:ElementInfo|null;doc:DocModel}|null=null,fresh=false;
 type Fragment={token:string;xml:string};
 let fragments:Fragment[]=[];let sectionFragments:Record<string,Fragment[]>={};let inputVersion=0,requestVersion=0;
 const busy=(value:boolean)=>{panel.setAttribute('aria-busy',String(value));$('ai-wait').hidden=!value;for(const id of ['ai-profile','ai-operation','ai-template','ai-instruction','ai-settings','ai-check','ai-describe','ai-rephrase','ai-review','ai-prepare'])($<HTMLInputElement>(id)).disabled=value;};
 let previewRequests=false;let pendingApply:string|null=null;let awaitingWrite=false,writeFailed=false,writeId='',writeDoc='';
 const lockWrite=(value:boolean)=>{awaitingWrite=value;for(const id of ['ai-queue-next','ai-queue-cancel','ai-cancel','ai-describe','ai-rephrase','ai-review','ai-prepare','ai-settings','ai-check'])$<HTMLButtonElement>(id).disabled=value;};
 const summarySelected=()=>$<HTMLInputElement>('ai-accept-summary').checked;
 const parameterEdits=()=>Array.from(panel.querySelectorAll<HTMLTextAreaElement>('#ai-parameters textarea')).filter(field=>field.parentElement?.querySelector<HTMLInputElement>('input[type=checkbox]')?.checked).map(field=>({name:field.dataset.name!,description:field.value}));
 const fieldSelected=(name:string)=>!$('ai-'+name+'-section').hidden&&$<HTMLInputElement>('ai-accept-'+name).checked;
 const selection=()=>({summarySelected:summarySelected(),summary:$<HTMLTextAreaElement>('ai-summary').value,returnsSelected:fieldSelected('returns'),returns:$<HTMLTextAreaElement>('ai-returns').value,remarksSelected:fieldSelected('remarks'),remarks:$<HTMLTextAreaElement>('ai-remarks').value,parameters:parameterEdits()});
 let operation='describe';
 const mergeParameters=(doc:DocModel,parameters:{name:string;description:string}[])=>{const result={...doc,params:(doc.params??[]).map(p=>({...p}))};for(const p of parameters){const existing=result.params.find(item=>item.name.toLowerCase()===p.name.toLowerCase());if(existing){if(operation==='review'||!meaningful(existing.description))existing.description=p.description;}else result.params.push({...p});}return result;};
 const status=(text:string)=>{$('ai-status').textContent=text;};
 const snapshot=()=>JSON.parse(JSON.stringify(hooks.get())) as typeof base;
 const rawDraft=()=>!!hooks.get().doc.parseError||!!hooks.get().doc.xmlEdited||!!bridge.unappliedXml()||!!hooks.get().doc.unappliedXml;
 const current=()=>inputVersion===requestVersion&&!!stamp&&bridge.isCurrentStamp(stamp)&&!!base&&JSON.stringify(hooks.get())===JSON.stringify(base)&&!rawDraft()&&!bridge.readOnly;
 const send=(type:string,extra:any={})=>bridge.sendToHost({type,requestId,...stamp,...extra} as any);
 const invalidate=()=>{inputVersion++;fresh=false;$<HTMLButtonElement>('ai-send').disabled=true;$<HTMLButtonElement>('ai-apply').disabled=true;if(requestId)status('Documentation changed — rebuild the AI proposal');};
 const reload=()=>{if(requestId){send('aiCancel');busy(false);invalidate();requestId='';stamp=null;}send('aiLoad');};
 const options=()=>{const operation=$<HTMLSelectElement>('ai-operation').value;const select=$<HTMLSelectElement>('ai-template');const selected=select.value;select.replaceChildren();for(const t of templates.filter(t=>t.operation===operation)){const option=document.createElement('option');option.value=t.id;option.textContent=(t.id==='describe'||t.id==='rephrase'||t.id==='review')?translate(t.name):t.name;option.dataset.code='';select.append(option);}if(Array.from(select.options).some(o=>o.value===selected))select.value=selected;select.hidden=select.options.length<2;};
 const fieldXml=(text:string,slots:Fragment[])=>{for(const f of slots)if(text.split(f.token).length!==2)throw Error('Protected XML token was lost or duplicated');let rest=text;for(const f of slots)rest=rest.replace(f.token,'');if(rest.includes('__XMLDOC_'))throw Error('Unknown protected XML token');text=proseXml(text);for(const f of slots)text=text.replace(f.token,()=>f.xml);if(parseXml('<section>'+text+'</section>').querySelector('parsererror'))throw Error('Invalid summary XML');return text;};
 const xml=()=>summarySelected()?fieldXml($<HTMLTextAreaElement>('ai-summary').value,fragments):base!.doc.summary;
 const proposalDoc=()=>{const doc=mergeParameters({...base!.doc,summary:xml()},parameterEdits().map(p=>({...p,description:fieldXml(p.description,sectionFragments['param:'+p.name.toLowerCase()]??[])})));for(const name of ['returns','remarks'] as const)if(fieldSelected(name))doc[name]=fieldXml($<HTMLTextAreaElement>('ai-'+name).value,sectionFragments[name]??[]);return doc;};
 const anySelected=()=>summarySelected()||fieldSelected('returns')||fieldSelected('remarks')||parameterEdits().length>0;
 const refreshDiff=()=>{try{const doc=proposalDoc();if(base?.element){const before=analyze(base.element,base.doc,[]);const after=analyze(base.element,doc,[]);if(after.some(i=>!before.some(old=>old.code===i.code&&old.message===i.message)))throw Error('AI proposal introduces documentation errors');}$('ai-after').textContent=editableXml(doc);$<HTMLButtonElement>('ai-apply').disabled=!fresh||!current()||!anySelected();}catch(error){status((error as Error).message);$<HTMLButtonElement>('ai-apply').disabled=true;}};
 const prepare=(operation?:string,forcePreview=false)=>{
  panel.open=true;
  if(awaitingWrite)return;
  if(bridge.readOnly||rawDraft()){status('Resolve the XML draft before using AI');return;}
  const c=hooks.get();if(c.element?.kind!=='method'){status('Select a method');return;}
  if(operation){$<HTMLSelectElement>('ai-operation').value=operation;options();}
  if(requestId)send('aiCancel');requestId=globalThis.crypto?.randomUUID?.()??('ai-'+Date.now()+Math.random());stamp=bridge.captureStamp();base=snapshot();pendingApply=null;requestVersion=inputVersion;fresh=false;
  $('ai-proposal').hidden=true;$<HTMLButtonElement>('ai-apply').disabled=true;$<HTMLButtonElement>('ai-send').disabled=true;
  busy(true);$('ai-request-preview').hidden=true;send('aiPrepare',{...c.element,forcePreview,profileId:$<HTMLSelectElement>('ai-profile').value,templateId:$<HTMLSelectElement>('ai-template').value,operation:$<HTMLSelectElement>('ai-operation').value,summary:c.doc.summary,documentation:c.doc,instruction:$<HTMLTextAreaElement>('ai-instruction').value});status('Preparing AI request');
 };
 $('ai-settings').onclick=()=>send('aiSettings');$('ai-check').onclick=()=>{if(requestId)send('aiCancel');requestId=globalThis.crypto?.randomUUID?.()??('check-'+Date.now());fresh=false;stamp=null;base=null;send('aiCheck',{profileId:$<HTMLSelectElement>('ai-profile').value});busy(true);status('Checking connection');};
 $('ai-describe').onclick=()=>prepare('describe');$('ai-rephrase').onclick=()=>prepare('rephrase');$('ai-review').onclick=()=>prepare('review');$('ai-prepare').onclick=()=>prepare(undefined,true);
 $('ai-send').onclick=()=>{if(!current()){invalidate();return;}busy(true);send('aiSend');$<HTMLButtonElement>('ai-send').disabled=true;};
 $('ai-cancel').onclick=()=>{send('aiCancel');busy(false);requestId='';fresh=false;stamp=null;invalidate();status('Cancelled');};
 $('ai-apply').onclick=()=>{if(!fresh||!current()){invalidate();return;}try{proposalDoc();const chosen=selection();pendingApply=JSON.stringify(chosen);writeId='';writeDoc='';lockWrite(true);writeFailed=false;status('Waiting for source write');send('aiApply',{...base!.element,...chosen});$<HTMLButtonElement>('ai-apply').disabled=true;}catch(error){status((error as Error).message);}};
 for(const name of ['returns','remarks']){$('ai-accept-'+name).onchange=refreshDiff;$('ai-'+name).oninput=refreshDiff;}
 $('ai-accept-summary').onchange=refreshDiff;$('ai-summary').oninput=refreshDiff;$('ai-operation').onchange=()=>{invalidate();options();};
 for(const id of ['ai-profile','ai-template','ai-instruction'])$(id).addEventListener(id==='ai-instruction'?'input':'change',invalidate);
 const receive=(data:any)=>{
  if(data.state==='configurationError'){busy(false);invalidate();status(data.message);return;}
  if(data.state==='configuration'){
   previewRequests=data.previewRequests===true;const select=$<HTMLSelectElement>('ai-profile');const selected=select.value;select.replaceChildren();for(const p of data.profiles){const option=document.createElement('option');option.value=p.id;option.textContent=p.name;option.dataset.code='';select.append(option);}if(Array.from(select.options).some(o=>o.value===selected))select.value=selected;templates=data.templates;options();return;
  }
  if(!requestId||data.requestId!==requestId)return;
  if(data.state==='checked'){busy(false);status('Connection OK');return;}
  if(data.state==='error'){busy(false);lockWrite(false);writeFailed=true;$<HTMLButtonElement>('ai-queue-next').disabled=true;fresh=false;status(data.message);return;}
  if(data.state==='prepared'){
   operation=$<HTMLSelectElement>('ai-operation').value;sectionFragments=data.sectionFragments??{};
   busy(false);fragments=data.fragments??[];if(data.previewRequired===false&&!previewRequests){if(current()){busy(true);send('aiSend');status('AI request running');}else invalidate();return;}
$('ai-url').textContent=data.url;$('ai-request').textContent=data.request;$('ai-request-preview').hidden=false;($('ai-request-preview') as HTMLDetailsElement).open=true;
   $<HTMLButtonElement>('ai-send').disabled=!current();status(current()?'Review the request before sending':'Documentation changed — rebuild the AI proposal');return;
  }
  if(data.state==='running'){busy(true);status('AI request running');return;}
  if(data.state==='proposal'){
   busy(false);$('ai-parameters').replaceChildren();for(const p of data.parameters??[]){if(!base?.element?.params.some(item=>item.name.toLowerCase()===p.name.toLowerCase())||(operation!=='review'&&(base.doc.params??[]).some(item=>item.name.toLowerCase()===p.name.toLowerCase()&&meaningful(item.description))))continue;const label=document.createElement('label');const name=document.createElement('code');name.textContent=p.name;const accept=document.createElement('input');accept.type='checkbox';accept.checked=true;accept.setAttribute('aria-label','Accept parameter '+p.name);accept.onchange=refreshDiff;label.append(accept,name);const field=document.createElement('textarea');field.dataset.name=p.name;field.value=p.description;field.setAttribute('aria-label',p.name);field.dataset.code='';field.oninput=refreshDiff;label.append(field);$('ai-parameters').append(label);}
   for(const name of ['returns','remarks']){const offered=typeof data[name]==='string';$('ai-'+name+'-section').hidden=!offered;$<HTMLInputElement>('ai-accept-'+name).checked=offered;$<HTMLTextAreaElement>('ai-'+name).value=offered?data[name]:'';}
   $('ai-changes').replaceChildren();for(const explanation of data.changes??[]){const item=document.createElement('li');item.dataset.code='';item.textContent=explanation;$('ai-changes').append(item);}
   $<HTMLInputElement>('ai-accept-summary').checked=true;fresh=!!data.fresh&&current();$('ai-proposal').hidden=false;$<HTMLTextAreaElement>('ai-summary').value=data.summary;
   $('ai-before').textContent=base?editableXml(base.doc):'';$('ai-uncertainties').replaceChildren();for(const text of data.uncertainties??[]){const li=document.createElement('li');li.textContent=text;li.dataset.code='';$('ai-uncertainties').append(li);}status(fresh?'Review and edit the AI proposal before applying':'Documentation changed — rebuild the AI proposal');refreshDiff();return;
  }
  if(data.state==='approved'){
   if(!fresh||!current()||pendingApply!==JSON.stringify(selection())){lockWrite(false);invalidate();return;}
   pendingApply=null;const doc=mergeParameters({...hooks.get().doc,summary:summarySelected()?data.summaryXml:hooks.get().doc.summary},data.parameters??[]);for(const name of ['returns','remarks'] as const)if(fieldSelected(name)&&typeof data[name+'Xml']==='string')doc[name]=data[name+'Xml'];delete doc.rawXml;delete doc.xmlEdited;delete doc.parseError;
   const oldIssues=analyze(base!.element!,base!.doc,[]),newIssues=analyze(base!.element!,doc,[]);
   if(newIssues.some(i=>!oldIssues.some(old=>old.code===i.code&&old.message===i.message))){lockWrite(false);status('AI proposal introduces documentation errors');return;}
   fresh=false;writeDoc=JSON.stringify(doc);hooks.apply(doc);$('ai-proposal').hidden=true;status('Waiting for source write');bridge.flush();
  }
 };
 let queue:ElementInfo[]=[],queuePosition=-1,queueWaiting=false,queueTimer:ReturnType<typeof setTimeout>|undefined;
 const pathKey=(path?:string)=>path?.replace(/\\/g,'/').toLowerCase();
 const sameTarget=(a:ElementInfo|null,b:ElementInfo|undefined)=>!!a&&!!b&&a.symbolId===b.symbolId&&pathKey(a.fileName)===pathKey(b.fileName)&&(!b.projectFile||pathKey(a.projectFile)===pathKey(b.projectFile))&&(!b.locationId||a.locationId===b.locationId);
 const stopQueue=()=>{clearTimeout(queueTimer);queueWaiting=false;queue=[];queuePosition=-1;$('ai-queue').hidden=true;};
 const dispatchQueued=()=>{
  if(!queueWaiting||!sameTarget(hooks.get().element,queue[queuePosition]))return;
  clearTimeout(queueTimer);queueWaiting=false;
  if(rawDraft()||bridge.readOnly){status('Resolve the XML draft before using AI');return;}
  prepare();
 };
 const nextQueued=()=>{
  if(awaitingWrite||writeFailed)return;
  $('ai-cancel').click();clearTimeout(queueTimer);queuePosition++;
  if(queuePosition>=queue.length){stopQueue();status('AI queue completed');return;}
  const target=queue[queuePosition];queueWaiting=true;$('ai-queue').hidden=false;
  $('ai-queue-status').textContent='AI queue: '+String(queuePosition+1)+'/'+String(queue.length);
  panel.open=true;
  // Opening a target does not apply anything. Capture the actual document after
  // the host loads it; never reuse the catalog's documentation or revision.
  if(sameTarget(hooks.get().element,target)){dispatchQueued();return;}
  bridge.sendToHost({type:'openSymbol',locationId:target.locationId,projectFile:target.projectFile,fileName:target.fileName!,symbolId:target.symbolId!,line:target.lineNumber??1});
  queueTimer=setTimeout(()=>{if(queueWaiting){queueWaiting=false;status('The queued method could not be opened. Skip it or cancel the queue.');}},10000);
 };
 const startQueue=(targets:ElementInfo[])=>{
  if(awaitingWrite)return;writeFailed=false;if(queue.length)stopQueue();const seen=new Set<string>();
  queue=targets.filter(target=>{const key=pathKey(target.projectFile)+'\0'+pathKey(target.fileName)+'\0'+target.symbolId+'\0'+(target.locationId??'');if(target.kind!=='method'||target.readOnly||!target.fileName||!target.symbolId||seen.has(key))return false;seen.add(key);return true;});
  queuePosition=-1;if(queue.length)nextQueued();else status('Select writable methods for the AI queue');
 };
 $('ai-queue-next').onclick=()=>{if(queue.length)nextQueued();};
 $('ai-queue-cancel').onclick=()=>{if(awaitingWrite)return;writeFailed=false;stopQueue();$('ai-cancel').click();};
 setWorkbenchIcon($('ai-queue-next'),'next-problem');setWorkbenchIcon($('ai-queue-cancel'),'cancel-operation');
 (window as any).xmlDocAI={receive,reload,startQueue};
 window.addEventListener('documentationWriteStarted',((event:CustomEvent)=>{if(awaitingWrite&&pendingApply===null&&writeDoc===JSON.stringify(event.detail.doc))writeId=event.detail.editId;}) as EventListener);
 window.addEventListener('documentationWriteResult',((event:CustomEvent)=>{if(!awaitingWrite||!writeId||event.detail.editId!==writeId)return;const result=event.detail;if(!stamp||result.context.sessionId!==stamp.sessionId||result.context.symbolId!==stamp.symbolId||result.context.fileName!==stamp.fileName)return;lockWrite(false);writeFailed=!result.applied;$<HTMLButtonElement>('ai-queue-next').disabled=writeFailed;status(result.applied?'AI proposal applied':result.message);}) as EventListener);
 window.addEventListener('documentationChanged',invalidate);window.addEventListener('documentationLoaded',()=>{if(stamp&&!current())invalidate();});
 window.addEventListener('documentationLoaded',()=>{if(queueWaiting)queueMicrotask(dispatchQueued);});
 window.addEventListener('sourceReadOnlyChanged',()=>{if(bridge.readOnly)invalidate();});
 window.addEventListener('uiLanguageChanged',options);
 window.addEventListener('pagehide',()=>{stopQueue();if(requestId)send('aiCancel');});
 reload();
}
