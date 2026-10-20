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
 <select id="ai-profile" aria-label="AI profile" title="AI profile"></select><select id="ai-operation" aria-label="AI operation" title="AI operation"><option value="describe">Describe method from code</option><option value="rephrase">Rephrase summary</option></select><select id="ai-template" aria-label="Prompt template" title="Prompt template"></select>
 <button id="ai-settings">AI profiles and prompts</button><button id="ai-check">Test connection</button></div>
 <textarea id="ai-instruction" placeholder="Additional instructions (optional)" aria-label="Additional instructions"></textarea>
 <div class="workbench-actions"><button id="ai-describe">Describe method from code</button><button id="ai-rephrase">Rephrase summary</button><button id="ai-prepare">Preview AI request</button><button id="ai-send" disabled>Send reviewed request</button><button id="ai-cancel">Cancel</button><output id="ai-status" aria-live="polite"></output></div>
 <div id="ai-wait" hidden role="status" aria-live="polite"><progress aria-label="AI request running"></progress><span>Waiting for AI response</span></div>
 <details id="ai-request-preview" hidden><summary>Request preview</summary><output id="ai-url" data-code></output><pre id="ai-request"></pre></details>
 <section id="ai-proposal" hidden><label>Suggested summary<textarea id="ai-summary" aria-label="Suggested summary"></textarea></label><div id="ai-parameters"></div><p>Keep protected XML tokens unchanged.</p><ul id="ai-uncertainties"></ul><div class="xml-diff"><pre id="ai-before"></pre><pre id="ai-after"></pre></div><button id="ai-apply" disabled>Apply reviewed summary</button></section>`;
 document.querySelector('#workbench')?.after(panel);
 const $=<T extends HTMLElement=HTMLElement>(id:string)=>panel.querySelector('#'+id) as T;
 for(const [id,icon] of [['ai-settings','ai-settings'],['ai-check','refresh-catalog'],['ai-describe','ai-describe'],['ai-rephrase','ai-rephrase'],['ai-prepare','preview-change'],['ai-send','next-problem'],['ai-cancel','cancel-operation'],['ai-apply','apply-operation']])setWorkbenchIcon($(id),icon);
 let templates:any[]=[],requestId='',stamp:Stamp|null=null,base:{element:ElementInfo|null;doc:DocModel}|null=null,fresh=false;
 let fragments:{token:string;xml:string}[]=[];let inputVersion=0,requestVersion=0;
 const busy=(value:boolean)=>{panel.setAttribute('aria-busy',String(value));$('ai-wait').hidden=!value;for(const id of ['ai-profile','ai-operation','ai-template','ai-instruction','ai-settings','ai-check','ai-describe','ai-rephrase','ai-prepare'])($<HTMLInputElement>(id)).disabled=value;};
 let previewRequests=false;
 const parameterEdits=()=>Array.from(panel.querySelectorAll<HTMLTextAreaElement>('#ai-parameters textarea')).map(field=>({name:field.dataset.name!,description:field.value}));
 const mergeParameters=(doc:DocModel,parameters:{name:string;description:string}[])=>{const result={...doc,params:(doc.params??[]).map(p=>({...p}))};for(const p of parameters){const existing=result.params.find(item=>item.name===p.name);if(existing){if(!meaningful(existing.description))existing.description=p.description;}else result.params.push({...p});}return result;};
 const status=(text:string)=>{$('ai-status').textContent=text;};
 const snapshot=()=>JSON.parse(JSON.stringify(hooks.get())) as typeof base;
 const rawDraft=()=>!!hooks.get().doc.parseError||!!hooks.get().doc.xmlEdited||!!bridge.unappliedXml()||!!hooks.get().doc.unappliedXml;
 const current=()=>inputVersion===requestVersion&&!!stamp&&bridge.isCurrentStamp(stamp)&&!!base&&JSON.stringify(hooks.get())===JSON.stringify(base)&&!rawDraft()&&!bridge.readOnly;
 const send=(type:string,extra:any={})=>bridge.sendToHost({type,requestId,...stamp,...extra} as any);
 const invalidate=()=>{inputVersion++;fresh=false;$<HTMLButtonElement>('ai-send').disabled=true;$<HTMLButtonElement>('ai-apply').disabled=true;if(requestId)status('Documentation changed — rebuild the AI proposal');};
 const reload=()=>{if(requestId){send('aiCancel');busy(false);invalidate();requestId='';stamp=null;}send('aiLoad');};
 const options=()=>{const operation=$<HTMLSelectElement>('ai-operation').value;const select=$<HTMLSelectElement>('ai-template');const selected=select.value;select.replaceChildren();for(const t of templates.filter(t=>t.operation===operation)){const option=document.createElement('option');option.value=t.id;option.textContent=(t.id==='describe'||t.id==='rephrase')?translate(t.name):t.name;option.dataset.code='';select.append(option);}if(Array.from(select.options).some(o=>o.value===selected))select.value=selected;select.hidden=select.options.length<2;};
 const xml=()=>{let text=$<HTMLTextAreaElement>('ai-summary').value;for(const f of fragments){if(text.split(f.token).length!==2)throw Error('Protected XML token was lost or duplicated');}let rest=text;for(const f of fragments)rest=rest.replace(f.token,'');if(rest.includes('__XMLDOC_'))throw Error('Unknown protected XML token');text=proseXml(text);for(const f of fragments)text=text.replace(f.token,f.xml);if(parseXml('<summary>'+text+'</summary>').querySelector('parsererror'))throw Error('Invalid summary XML');return text;};
 const refreshDiff=()=>{try{const fragment=xml();if(base?.element){const before=analyze(base.element,base.doc,[]);const after=analyze(base.element,mergeParameters({...base.doc,summary:fragment},parameterEdits().map(p=>({...p,description:proseXml(p.description)}))),[]);if(after.some(i=>!before.some(old=>old.code===i.code&&old.message===i.message)))throw Error('AI proposal introduces documentation errors');}$('ai-after').textContent=editableXml(mergeParameters({...base!.doc,summary:fragment},parameterEdits().map(p=>({...p,description:proseXml(p.description)}))));$<HTMLButtonElement>('ai-apply').disabled=!fresh||!current();}catch(error){status((error as Error).message);$<HTMLButtonElement>('ai-apply').disabled=true;}};
 const prepare=(operation?:string,forcePreview=false)=>{
  panel.open=true;
  if(bridge.readOnly||rawDraft()){status('Resolve the XML draft before using AI');return;}
  const c=hooks.get();if(c.element?.kind!=='method'){status('Select a method');return;}
  if(operation){$<HTMLSelectElement>('ai-operation').value=operation;options();}
  if(requestId)send('aiCancel');requestId=globalThis.crypto?.randomUUID?.()??('ai-'+Date.now()+Math.random());stamp=bridge.captureStamp();base=snapshot();requestVersion=inputVersion;fresh=false;
  $('ai-proposal').hidden=true;$<HTMLButtonElement>('ai-apply').disabled=true;$<HTMLButtonElement>('ai-send').disabled=true;
  busy(true);$('ai-request-preview').hidden=true;send('aiPrepare',{...c.element,forcePreview,profileId:$<HTMLSelectElement>('ai-profile').value,templateId:$<HTMLSelectElement>('ai-template').value,operation:$<HTMLSelectElement>('ai-operation').value,summary:c.doc.summary,instruction:$<HTMLTextAreaElement>('ai-instruction').value});status('Preparing AI request');
 };
 $('ai-settings').onclick=()=>send('aiSettings');$('ai-check').onclick=()=>{if(requestId)send('aiCancel');requestId=globalThis.crypto?.randomUUID?.()??('check-'+Date.now());fresh=false;stamp=null;base=null;send('aiCheck',{profileId:$<HTMLSelectElement>('ai-profile').value});busy(true);status('Checking connection');};
 $('ai-describe').onclick=()=>prepare('describe');$('ai-rephrase').onclick=()=>prepare('rephrase');$('ai-prepare').onclick=()=>prepare(undefined,true);
 $('ai-send').onclick=()=>{if(!current()){invalidate();return;}busy(true);send('aiSend');$<HTMLButtonElement>('ai-send').disabled=true;};
 $('ai-cancel').onclick=()=>{send('aiCancel');busy(false);requestId='';fresh=false;stamp=null;invalidate();status('Cancelled');};
 $('ai-apply').onclick=()=>{if(!fresh||!current()){invalidate();return;}try{xml();send('aiApply',{...base!.element,summary:$<HTMLTextAreaElement>('ai-summary').value,parameters:parameterEdits()});$<HTMLButtonElement>('ai-apply').disabled=true;}catch(error){status((error as Error).message);}};
 $('ai-summary').oninput=refreshDiff;$('ai-operation').onchange=()=>{invalidate();options();};
 for(const id of ['ai-profile','ai-template','ai-instruction'])$(id).addEventListener(id==='ai-instruction'?'input':'change',invalidate);
 const receive=(data:any)=>{
  if(data.state==='configurationError'){busy(false);invalidate();status(data.message);return;}
  if(data.state==='configuration'){
   previewRequests=data.previewRequests===true;const select=$<HTMLSelectElement>('ai-profile');const selected=select.value;select.replaceChildren();for(const p of data.profiles){const option=document.createElement('option');option.value=p.id;option.textContent=p.name;option.dataset.code='';select.append(option);}if(Array.from(select.options).some(o=>o.value===selected))select.value=selected;templates=data.templates;options();return;
  }
  if(!requestId||data.requestId!==requestId)return;
  if(data.state==='checked'){busy(false);status('Connection OK');return;}
  if(data.state==='error'){busy(false);fresh=false;status(data.message);return;}
  if(data.state==='prepared'){
   busy(false);fragments=data.fragments??[];if(data.previewRequired===false&&!previewRequests){if(current()){busy(true);send('aiSend');status('AI request running');}else invalidate();return;}
$('ai-url').textContent=data.url;$('ai-request').textContent=data.request;$('ai-request-preview').hidden=false;($('ai-request-preview') as HTMLDetailsElement).open=true;
   $<HTMLButtonElement>('ai-send').disabled=!current();status(current()?'Review the request before sending':'Documentation changed — rebuild the AI proposal');return;
  }
  if(data.state==='running'){busy(true);status('AI request running');return;}
  if(data.state==='proposal'){
   busy(false);$('ai-parameters').replaceChildren();for(const p of data.parameters??[]){if(!base?.element?.params.some(item=>item.name===p.name)||(base.doc.params??[]).some(item=>item.name===p.name&&meaningful(item.description)))continue;const label=document.createElement('label');const name=document.createElement('code');name.textContent=p.name;label.append(name);const field=document.createElement('textarea');field.dataset.name=p.name;field.value=p.description;field.setAttribute('aria-label',p.name);field.dataset.code='';field.oninput=refreshDiff;label.append(field);$('ai-parameters').append(label);}
   fresh=!!data.fresh&&current();$('ai-proposal').hidden=false;$<HTMLTextAreaElement>('ai-summary').value=data.summary;
   $('ai-before').textContent=base?editableXml(base.doc):'';$('ai-uncertainties').replaceChildren();for(const text of data.uncertainties??[]){const li=document.createElement('li');li.textContent=text;li.dataset.code='';$('ai-uncertainties').append(li);}refreshDiff();
   status(fresh?'Review and edit the AI proposal before applying':'Documentation changed — rebuild the AI proposal');return;
  }
  if(data.state==='approved'){
   if(!fresh||!current()){invalidate();return;}
   const doc=mergeParameters({...hooks.get().doc,summary:data.summaryXml},data.parameters??[]);delete doc.rawXml;delete doc.xmlEdited;delete doc.parseError;
   const oldIssues=analyze(base!.element!,base!.doc,[]),newIssues=analyze(base!.element!,doc,[]);
   if(newIssues.some(i=>!oldIssues.some(old=>old.code===i.code&&old.message===i.message))){status('AI proposal introduces documentation errors');return;}
   fresh=false;hooks.apply(doc);$('ai-proposal').hidden=true;status('AI proposal applied');
  }
 };
 (window as any).xmlDocAI={receive,reload};
 window.addEventListener('documentationChanged',invalidate);window.addEventListener('documentationLoaded',()=>{if(stamp&&!current())invalidate();});
 window.addEventListener('sourceReadOnlyChanged',()=>{if(bridge.readOnly)invalidate();});
 window.addEventListener('uiLanguageChanged',options);
 window.addEventListener('pagehide',()=>{if(requestId)send('aiCancel');});
 reload();
}
