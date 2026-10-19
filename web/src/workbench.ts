import { bridge } from './bridge';
import { analyze, synchronize, modelXml, parseXml, inheritDoc, ready, issueKey, replaceProse, compatibleInheritedMember, genericArguments, isPublicApi, wordingMatches, editableXml } from './docTools';
import type { DocModel, ElementInfo, TreeElementInfo } from './types';
import { escapeXml } from './xmlCodec';
import { initWorkbenchIcons, setWorkbenchIcon } from './workbenchIcons';
interface Hooks { get:()=>{element:ElementInfo|null;doc:DocModel}; apply:(doc:DocModel)=>void; }
let catalog:TreeElementInfo[]=[];
export function initWorkbench(hooks:Hooks):void {
 const box=document.createElement('details');box.id='workbench';box.open=true;
 box.innerHTML=`<summary>Documentation tools <output id="edit-status" aria-live="polite">Applied</output></summary>
 <div class="workbench-actions"><button id="history-back" title="Back (Alt+Left)">Back</button><button id="history-forward" title="Forward (Alt+Right)">Forward</button>
 <button id="pin-document" aria-pressed="false">Pin</button><button id="compact-document" aria-pressed="false">Compact</button><button id="focus-source">Source</button><button id="reload-document">Reload source</button><button id="recover-drafts">Recover drafts</button>
 <button id="quick-documentation">Quick documentation</button><button id="sync-document">Synchronize signature</button><button id="open-xml">XML</button><button id="format-document">Format</button><button id="fold-documentation">Fold source comments</button><button id="show-problems">Problems</button></div>
 <details><summary>Project workspace</summary><div class="workbench-actions"><select id="catalog-scope" aria-label="Documentation scope"><option value="module">Module</option><option value="project" selected>Project</option><option value="group">Project group</option></select><button id="refresh-catalog">Refresh</button>
 <output id="analysis-state" aria-live="polite"></output><button id="cancel-analysis" hidden title="Cancel analysis">Cancel analysis</button><input id="reference-label" placeholder="Reference display text (optional)" aria-label="Reference display text"><input id="catalog-query" placeholder="Find symbol or documentation" aria-label="Find symbol or documentation"><select id="catalog-filter" aria-label="Documentation filter"><option value="all">All symbols</option><option value="public">Public API</option><option value="missing">No documentation</option><option value="todo">TODO drafts</option><option value="incomplete">Incomplete signature</option><option value="links">Reference problems</option><option value="review">New problems</option></select>
 <select id="catalog-kind" aria-label="Symbol kind"><option value="">All kinds</option>${['unit','class','record','interface','method','property','field','type','constant'].map(k=>`<option>${k}</option>`).join('')}</select>
 <button id="next-problem">Next problem</button><button id="save-baseline">Save baseline</button><button id="load-baseline">Load baseline</button><input type="file" id="baseline-file" accept="application/json" hidden></div><div id="catalog-results" role="listbox" aria-label="Project symbols"></div>
 <details><summary>Member summaries</summary><button id="apply-summaries">Preview selected summaries</button><div id="member-summaries"></div></details></details>
 <details><summary>Inheritance and reusable text</summary><div id="inheritance-sources"></div><div class="workbench-actions"><select id="template-section"><option>summary</option><option>remarks</option><option>returns</option><option>value</option><option>param</option><option>typeparam</option></select><select id="template-scope"><option value="project">Project wording</option><option value="global">Global wording</option></select><select id="template-kind" aria-label="Element kind for wording"><option value="">Any element kind</option>${['unit','class','interface','method','property','field','type','constant'].map(k=>`<option>${k}</option>`).join('')}</select><input id="template-name" placeholder="Parameter name pattern (optional)"><input id="template-type" placeholder="Parameter type (optional)"><textarea id="template-text" placeholder="Reusable description"></textarea><button id="save-template">Save wording</button><select id="template-choice" aria-label="Saved wording"></select><button id="apply-template">Fill empty section</button></div>
 <label>Project terminology<textarea id="project-terms" placeholder="Known words, one per line"></textarea><button id="save-terms">Save terminology</button></label><label>Spell-check language <select id="spell-language"><option value="en">English</option><option value="ru">Russian</option></select></label><label><input id="spell-enabled" type="checkbox" checked> Spell check prose</label></details>
 <details><summary>Examples and search</summary><button id="insert-selection">Insert selected source as example</button><input id="example-source" placeholder="Relative example source file"><input id="example-region" placeholder="Region name (optional)"><button id="link-example">Preview linked example</button><input id="find-doc" aria-label="Find in documentation" placeholder="Find text"><input id="replace-doc" aria-label="Replacement" placeholder="Replacement"><button id="replace-all">Preview replacement</button></details>
 <div id="documentation-problems" aria-live="polite"></div><div id="operation-preview" hidden><h4>Review documentation changes</h4><div class="xml-diff"><pre id="xml-before"></pre><pre id="xml-after"></pre></div><button id="apply-operation">Apply changes</button><button id="cancel-operation">Cancel</button></div>`;
 initWorkbenchIcons(box);
 document.getElementById('doc-toolbar')?.before(box);
 const raw=document.createElement('section');raw.id='doc-xml';raw.className='hidden';raw.innerHTML='<label for="xml-source">Documentation XML</label><textarea id="xml-source" spellcheck="false" aria-label="Documentation XML"></textarea><button id="apply-xml">Validate and apply XML</button><output id="xml-error" aria-live="polite"></output>';
 initWorkbenchIcons(raw);document.getElementById('doc-preview')?.after(raw);
 const $=<T extends HTMLElement=HTMLElement>(id:string)=>document.getElementById(id) as T;
 const xml=$<HTMLTextAreaElement>('xml-source');
 xml.oninput=()=>{const error=parseXml(xml.value).querySelector('parsererror');$('xml-error').textContent=error?.textContent??'XML is valid';const e=hooks.get().element;if(e)bridge.saveDraft({...hooks.get().doc,rawXml:xml.value,xmlEdited:true});};
 let applyPreview:(()=>void)|null=null;let preview:DocModel|null=null;let baseline=new Set<string>();let publicBaseline: {symbolId:string;name:string;file:string;line:number}[]=[];let history:{projectFile?:string;fileName?:string;symbolId?:string;line?:number;locationId?:string}[]=[];let index=-1;let navigating=false;
 const current=()=>hooks.get();
 const open=(element:ElementInfo)=>{
  if(!element.fileName || !element.symbolId)return;
  bridge.sendToHost({type:'openSymbol',locationId:element.locationId,projectFile:element.projectFile,fileName:element.fileName,symbolId:element.symbolId,line:element.lineNumber??1});
 };
 const visibleXml=()=> (bridge.unappliedXml()??current().doc.unappliedXml)?.xml??editableXml(current().doc);
 const viewXml=(focus=true)=>{
  $('doc-design').classList.add('hidden');$('doc-preview').classList.add('hidden');raw.classList.remove('hidden');
  xml.value=visibleXml();if(focus)xml.focus();
 };
 let recovery:any=null;
 const showRecovery=()=>{
  if(!recovery)return;const target=current().element;
  if(!target || target.fileName!==recovery.fileName || target.locationId!==recovery.locationId || target.sourceRevision!==recovery.currentRevision)return;
  const data=recovery;recovery=null;const panel=$('documentation-problems');panel.replaceChildren();
  const heading=document.createElement('h4');heading.textContent='Recover documentation draft';panel.append(heading);
  const explanation=document.createElement('p');explanation.textContent=data.readOnly?'The source is read-only. The draft can be viewed but cannot be applied.':data.conflict?'Conflict: the source comment changed after this draft was created. Review all three versions before applying.':'The source comment matches the original version. Review the saved draft before applying.';panel.append(explanation);
  const versions=document.createElement('div');versions.className='draft-comparison';
  for(const [label,text] of [['Original comment',data.baseXml??'(Original version unavailable)'],['Current source comment',data.currentXml??''],['Saved draft',editableXml(data.doc)]]){const section=document.createElement('section');const title=document.createElement('h5');title.textContent=label;const code=document.createElement('pre');code.textContent=text;section.append(title,code);versions.append(section);}panel.append(versions);
  const apply=document.createElement('button');apply.textContent=data.conflict?'Apply draft over current comment':'Apply recovered draft';setWorkbenchIcon(apply,'apply-operation');apply.disabled=!!data.readOnly || bridge.readOnly;
  apply.onclick=()=>{const now=current().element;if(!now || now.fileName!==target.fileName || now.locationId!==target.locationId || now.sessionId!==target.sessionId || now.sourceRevision!==target.sourceRevision){bridge.setStatus('Source changed — recover the draft again');return;}bridge.prepareRecovery(now);hooks.apply({...data.doc,unappliedXml:undefined});panel.replaceChildren();};
  const cancel=document.createElement('button');cancel.textContent='Keep draft and close';setWorkbenchIcon(cancel,'cancel-operation');cancel.onclick=()=>panel.replaceChildren();panel.append(apply,cancel);
 };
 const review=(doc:DocModel)=>{
  preview=doc;const target=current().element;applyPreview=()=>{if(current().element?.declarationId!==target?.declarationId || current().element?.sourceRevision!==target?.sourceRevision){bridge.setStatus('Source changed — review again');return;}hooks.apply(doc);};$('xml-before').textContent=editableXml(current().doc);$('xml-after').textContent=modelXml(doc);$('operation-preview').hidden=false;
 };
 const issues=()=>{const c=current();return c.element?analyze(c.element,c.doc,catalog):[];};
 const showProblems=()=>{
  const container=$('documentation-problems');container.replaceChildren();
  for(const issue of issues()){
   const row=document.createElement('div');row.className='documentation-issue';
   const text=document.createElement('span');text.textContent=`${issue.code} (${issue.line}:${issue.column}) `;const message=document.createElement('span');message.textContent=issue.message;text.append(message);row.append(text);
   const button=document.createElement('button');button.textContent=issue.fix;setWorkbenchIcon(button,issue.fix==='Choose reference'?'reference':(issue.fix==='Synchronize'||issue.fix==='Map name')?'sync-document':'open-xml');button.onclick=()=>{
    if(issue.fix==='Synchronize')sync();else if(issue.fix==='Choose reference'){$('catalog-query').focus();refresh();}
    else if(issue.fix==='Map name')sync();else viewXml();
   };row.append(button);container.append(row);
  }
  if(!container.childElementCount)container.textContent=current().doc.summary?'Documentation checks passed.':'No summary yet.';
 };
 const sync=()=>{
  const c=current();if(!c.element)return;
  const expected=c.element.params.map(p=>p.name);const old=(c.doc.params??[]).filter(p=>!expected.some(n=>n.toLowerCase()===p.name.toLowerCase()));
  const mappings:Record<string,string>={};
  const panel=document.createElement('div');panel.id='rename-mapping';
  for(const param of old){const label=document.createElement('label');label.textContent=`Map ${param.name}: `;const select=document.createElement('select');select.innerHTML='<option value="">Keep unmatched description</option>'+expected.map(n=>`<option data-code>${escapeXml(n)}</option>`).join('');select.onchange=()=>{if(select.value)mappings[param.name]=select.value;else delete mappings[param.name];};label.append(select);panel.append(label);}
  const next=document.createElement('button');next.textContent='Preview synchronization';setWorkbenchIcon(next,'preview-change');next.onclick=()=>{try{review(synchronize(c.element!,c.doc,mappings));panel.remove();}catch(e){bridge.setStatus(String(e));}};panel.append(next);
  $('documentation-problems').replaceChildren(panel);if(!old.length)next.click();
 };
 $('cancel-analysis').onclick=()=>bridge.sendToHost({type:'cancelAnalysis'} as any);
 $('quick-documentation').onclick=()=>bridge.sendToHost({type:'requestQuickDoc'} as any);
 $('sync-document').onclick=sync;$('show-problems').onclick=showProblems;$('open-xml').onclick=()=>viewXml();
 $('apply-operation').onclick=()=>{applyPreview?.();applyPreview=null;preview=null;$('operation-preview').hidden=true;};
 $('cancel-operation').onclick=()=>{applyPreview=null;preview=null;$('operation-preview').hidden=true;};
 $('fold-documentation').onclick=()=>bridge.sendToHost({type:'foldDocumentation'} as any);
 $('format-document').onclick=()=>{const text=editableXml(current().doc);const parsed=parseXml(text);if(parsed.querySelector('parsererror')){viewXml();return;}review({...current().doc,rawXml:Array.from(parsed.documentElement.childNodes).map(n=>new XMLSerializer().serializeToString(n)).join('\n'),xmlEdited:true});};
 $('apply-xml').onclick=()=>{
  const parsed=parseXml(xml.value);const error=parsed.querySelector('parsererror');
  $('xml-error').textContent=error?.textContent??'';
  if(!error){bridge.approveXml();hooks.apply({...current().doc,unappliedXml:undefined,rawXml:xml.value,xmlEdited:true,parseError:undefined});}
 };
 document.querySelectorAll('#doc-tabs .tab').forEach(tab=>tab.addEventListener('click',()=>raw.classList.add('hidden')));
 $('pin-document').onclick=()=>{const pinned=!bridge.pinned;bridge.setPinned(pinned);$('pin-document').setAttribute('aria-pressed',String(pinned));bridge.sendToHost({type:'pin',pinned});};
 $('compact-document').onclick=()=>{document.body.classList.toggle('compact');$('compact-document').setAttribute('aria-pressed',String(document.body.classList.contains('compact')));};
 $('focus-source').onclick=()=>{const e=current().element;if(e)open(e);};
 $('recover-drafts').onclick=()=>bridge.sendToHost({type:'listDrafts'} as any);
 $('reload-document').onclick=()=>{bridge.discardDrafts();bridge.setPinned(false);bridge.sendToHost({type:'requestRefresh'});};
 const move=(delta:number)=>{const next=index+delta;if(next>=0 && next<history.length){index=next;navigating=true;const e=history[index];if(e.fileName && e.symbolId)bridge.sendToHost({type:'openSymbol',locationId:e.locationId,projectFile:e.projectFile,fileName:e.fileName,symbolId:e.symbolId,line:e.line??1});}};
 $('history-back').onclick=()=>move(-1);$('history-forward').onclick=()=>move(1);
 document.addEventListener('keydown',event=>{
  if(event.altKey && ['ArrowLeft','ArrowRight'].includes(event.key)){event.preventDefault();move(event.key==='ArrowLeft'?-1:1);}
  if(event.ctrlKey && event.altKey && event.key.toLowerCase()==='x'){event.preventDefault();viewXml();}
  if(event.key==='Escape' && !raw.classList.contains('hidden')){$('doc-design').classList.remove('hidden');raw.classList.add('hidden');}
 });
 const filtered=()=>{
  const q=$<HTMLInputElement>('catalog-query').value.toLowerCase(),filter=$<HTMLSelectElement>('catalog-filter').value,kind=$<HTMLSelectElement>('catalog-kind').value;
  return catalog.filter(e=>{
   if(kind && e.kind!==kind)return false;
   if(q && !`${e.signature} ${e.fullName}`.toLowerCase().includes(q) && !(e.searchText??(e.doc.xmlEdited?e.doc.rawXml:e.doc.sourceXml)??modelXml(e.doc)).toLowerCase().includes(q))return false;
   const problems=['todo','incomplete','links','review'].includes(filter)?analyze(e,e.doc,catalog):[];
   switch(filter){case 'public':return !e.visibility || ['public','published'].includes(e.visibility);case 'missing':return !e.doc.summary;case 'todo':return problems.some(p=>p.code==='XD008');case 'incomplete':return problems.some(p=>['XD002','XD003','XD004','XD005','XD009','XD010'].includes(p.code));case 'links':return problems.some(p=>p.code==='XD006'||p.code==='XD007');case 'review':return problems.some(p=>!baseline.has(issueKey(e,p)));default:return true;}
  });
 };
 let queueIndex=-1,catalogLimit=100;
 // Pending bulk changes belong to declarations, not to their currently visible rows.
 const bulkKey=(e:ElementInfo)=>JSON.stringify([e.projectFile,e.fileName,e.locationId??e.declarationId??e.symbolId]);
 const bulkEdits=new Map<string,{element:TreeElementInfo;summary:string;selected:boolean}>();
 const captureGrid=()=>{
  for(const input of $('member-summaries').querySelectorAll<HTMLTextAreaElement>('textarea')){
   const edit=bulkEdits.get(input.dataset.key!);if(!edit)continue;edit.summary=input.value;
   const check=input.parentElement?.querySelector<HTMLInputElement>('input[type=checkbox]');if(check)edit.selected=check.checked;
  }
 };
 type BatchChange={element:TreeElementInfo;doc:DocModel};
 const batches=new Map<string,{changes:BatchChange[];applied:boolean;sourceRevisions?:Record<string,string>}>();let batchSerial=0;
 const sameBase=(a:TreeElementInfo,b:TreeElementInfo)=>JSON.stringify([a.signature,a.params,a.genericParams,a.doc])===JSON.stringify([b.signature,b.params,b.genericParams,b.doc]);
 const canonicalSummary=(text:string)=>new XMLSerializer().serializeToString(parseXml('<summary>'+text+'</summary>').documentElement);
 const reconcileBatches=()=>{
  for(const [id,batch] of batches){
   if(!batch.applied)continue;let waiting=false;
   for(const change of batch.changes){
    const key=bulkKey(change.element),edit=bulkEdits.get(key),live=catalog.find(e=>bulkKey(e)===key);
    if(!live)continue;
    const expected=batch.sourceRevisions?.[String(live.fileName).replace(/\\/g,'/').toLowerCase()];
    if(expected && live.sourceRevision!==expected){if(live.sourceRevision===change.element.sourceRevision)waiting=true;continue;}
    if(!expected && live.sourceRevision===change.element.sourceRevision && canonicalSummary(live.doc.summary)!==canonicalSummary(change.doc.summary)){waiting=true;continue;}
    if(edit && canonicalSummary(live.doc.summary)===canonicalSummary(change.doc.summary)){
     edit.element=live;
     if(edit.summary===change.doc.summary){edit.summary=live.doc.summary;edit.selected=false;}
    }
   }
   if(!waiting)batches.delete(id);
  }
  for(const edit of bulkEdits.values()){
   const live=catalog.find(e=>bulkKey(e)===bulkKey(edit.element));
   if(live && sameBase(live,edit.element))edit.element=live;
  }
  $<HTMLButtonElement>('apply-summaries').disabled=batches.size>0;
 };
 const renderCatalog=(preserveGrid=false,capture=true)=>{
  if(capture)captureGrid();
  const matches=filtered();
  const results=$('catalog-results');results.replaceChildren();
  for(const old of publicBaseline)if(!catalog.some(e=>e.symbolId===old.symbolId && isPublicApi(e,catalog))){const row=document.createElement('div');row.className='documentation-issue';row.textContent=`XD011 Public declaration removed or signature changed: ${old.name}`;results.append(row);}
  for(const element of matches.slice(0,catalogLimit)){
   const row=document.createElement('div');row.className='catalog-row';row.tabIndex=0;row.setAttribute('role','option');
   const button=document.createElement('button');button.textContent=`${element.fileName?.split(/[\\/]/).pop()} · ${element.signature??element.fullName??element.name}`;const caption=document.createElement('span');caption.className='symbol-caption';caption.textContent=button.textContent;row.append(caption);button.title='Open source: '+button.textContent;button.textContent='Open source';setWorkbenchIcon(button,'open-source');button.onclick=()=>open(element);row.append(button);
   const insert=document.createElement('button');insert.textContent='Reference';insert.title='Insert a reference to this exact overload';setWorkbenchIcon(insert,'reference');insert.onclick=()=>window.dispatchEvent(new CustomEvent('insertReference',{detail:{cref:element.symbolId,text:$<HTMLInputElement>('reference-label').value||element.name}}));row.append(insert);
   const copy=document.createElement('button');copy.textContent='Copy documentation';setWorkbenchIcon(copy,'copy-documentation');copy.onclick=()=>{
    const target=current().element;if(!target)return;const mapping:Record<string,string>={};const panel=document.createElement('div');
    const expected=[...target.params.map(p=>p.name),...(target.genericParams??[])];
    for(const parameter of [...element.params.map(p=>p.name),...(element.genericParams??[])]){const label=document.createElement('label');label.textContent=parameter+' → ';const select=document.createElement('select');
     const unmatched=document.createElement('option');unmatched.value='';unmatched.textContent='Keep unmatched description';select.append(unmatched);
     for(const name of expected){const option=document.createElement('option');option.value=name;option.textContent=name;option.dataset.code='';select.append(option);}const exact=expected.find(n=>n.toLowerCase()===parameter.toLowerCase());if(exact)select.value=exact;
     select.onchange=()=>{if(select.value && select.value!==parameter)mapping[parameter]=select.value;else delete mapping[parameter];};label.append(select);panel.append(label);
    }
    const next=document.createElement('button');next.textContent='Preview copy';setWorkbenchIcon(next,'preview-change');next.onclick=()=>{try{const source=element.effectiveDoc??element.doc;const independent=synchronize(target,source,mapping);independent.inheritedFrom=undefined;
     if(independent.sourceXml){const parsed=parseXml(independent.sourceXml);parsed.querySelectorAll('inheritdoc').forEach(n=>n.remove());independent.sourceXml=Array.from(parsed.documentElement.childNodes).map(n=>new XMLSerializer().serializeToString(n)).join('');}
     review(independent);panel.remove();}catch(e){bridge.setStatus(String(e));}};panel.append(next);$('documentation-problems').replaceChildren(panel);
   };row.append(copy);
   row.onkeydown=event=>{if(event.key==='Enter')open(element);if(event.key==='ArrowDown')row.nextElementSibling instanceof HTMLElement&&row.nextElementSibling.focus();if(event.key==='ArrowUp')row.previousElementSibling instanceof HTMLElement&&row.previousElementSibling.focus();};
   const summary=document.createElement('span');summary.textContent=element.doc.summary;summary.dataset.code='';row.append(summary);results.append(row);
  }
  if(matches.length>catalogLimit){const more=document.createElement('button');more.textContent='Show more results';setWorkbenchIcon(more,'history-forward');more.onclick=()=>{catalogLimit+=100;renderCatalog(true);};results.append(more);}
  if(preserveGrid)return;
  const members=$('member-summaries');members.replaceChildren();
  const owner=current().element?.qualifiedParent || current().element?.name;
  const gridElements=matches.filter(e=>e.qualifiedParent===owner && e.fileName===current().element?.fileName);let gridLimit=0;
  const appendGrid=()=>{
  for(const element of gridElements.slice(gridLimit,gridLimit+100)){
   const key=bulkKey(element);let edit=bulkEdits.get(key);if(!edit || (!edit.selected && edit.summary===edit.element.doc.summary)){edit={element,summary:element.doc.summary,selected:false};bulkEdits.set(key,edit);}
   const row=document.createElement('label');const selected=document.createElement('input');selected.type='checkbox';selected.checked=edit.selected;selected.onchange=()=>{edit!.selected=selected.checked;};selected.dataset.id=element.symbolId;selected.disabled=!!element.readOnly;selected.dataset.sourceLocked=String(!!element.readOnly);
   const name=document.createElement('span');name.textContent=element.signature??element.name;name.dataset.code='';
   const input=document.createElement('textarea');input.value=edit.summary;input.dataset.key=key;input.oninput=()=>{edit!.summary=input.value;};input.title='Summary XML fragment';input.dataset.id=element.symbolId;input.readOnly=!!element.readOnly;input.dataset.sourceLocked=String(!!element.readOnly);input.setAttribute('aria-label',`Summary for ${element.signature??element.name}`);row.append(selected,name,input);
   if(element.sourceRevision!==edit.element.sourceRevision || !sameBase(element,edit.element)){
    const rebase=document.createElement('button');rebase.type='button';rebase.textContent='Review current source';setWorkbenchIcon(rebase,'reload-document');
    rebase.onclick=event=>{event.preventDefault();captureGrid();const base=element;
     $('xml-before').textContent=modelXml(base.doc);$('xml-after').textContent=modelXml({...base.doc,summary:edit!.summary});$('operation-preview').hidden=false;
     applyPreview=()=>{const live=catalog.find(e=>bulkKey(e)===key);if(!live || live.sourceRevision!==base.sourceRevision || !sameBase(live,base)){bridge.setStatus('Source changed — review again');return;}
      edit!.element=live;bridge.setStatus('Baseline updated — preview selected summaries before applying');renderCatalog();};
    };row.append(rebase);
   }
   members.append(row);
  }
  gridLimit+=100;
  if(gridLimit<gridElements.length){const more=document.createElement('button');more.textContent='Show more results';setWorkbenchIcon(more,'history-forward');more.onclick=()=>{more.remove();appendGrid();};members.append(more);}
  };appendGrid();
 };
 const resetCatalog=()=>{catalogLimit=100;renderCatalog();};
 $('catalog-query').oninput=resetCatalog;$('catalog-filter').onchange=resetCatalog;$('catalog-kind').onchange=resetCatalog;
 const refresh=()=>bridge.sendToHost({type:'requestCatalog',scope:$<HTMLSelectElement>('catalog-scope').value as 'module'|'project'|'group'});
 $('refresh-catalog').onclick=refresh;$('next-problem').onclick=()=>{const list=filtered().filter(e=>!ready(e,e.doc,catalog));if(list.length)open(list[(++queueIndex)%list.length]);};
 $('apply-summaries').onclick=()=>{
  try {
  if(batches.size){bridge.setStatus('Waiting for the previous bulk update');return;}
  captureGrid();
  const changes=Array.from(bulkEdits.values()).filter(edit=>edit.selected).map(edit=>{
   const e=catalog.find(e=>bulkKey(e)===bulkKey(edit.element));
   if(!e || e.readOnly || e.sourceRevision!==edit.element.sourceRevision || JSON.stringify(e.doc)!==JSON.stringify(edit.element.doc))throw Error('Source changed — review selected summaries again');
   if(parseXml('<summary>'+edit.summary+'</summary>').querySelector('parsererror'))throw Error('Invalid summary XML');
   const doc={...e.doc,summary:edit.summary};delete doc.rawXml;delete doc.xmlEdited;delete doc.parseError;
   return {element:e,doc};
  });
  if(!changes.length)return;
  $('xml-before').textContent=changes.map(c=>c.element.signature+'\n'+modelXml(c.element.doc)).join('\n');$('xml-after').textContent=changes.map(c=>c.element.signature+'\n'+modelXml(c.doc)).join('\n');$('operation-preview').hidden=false;
  applyPreview=()=>{
   if(changes.some(c=>{const now=catalog.find(e=>bulkKey(e)===bulkKey(c.element));return !now || now.readOnly || now.sourceRevision!==c.element.sourceRevision || JSON.stringify(now.doc)!==JSON.stringify(c.element.doc);})){bridge.setStatus('Source changed — review selected summaries again');return;}
   const batchId=`bulk-${Date.now()}-${++batchSerial}`;
   batches.set(batchId,{changes:JSON.parse(JSON.stringify(changes)),applied:false});$<HTMLButtonElement>('apply-summaries').disabled=true;
   window.dispatchEvent(new CustomEvent('applyDocumentationBatch',{detail:{batchId,changes}}));
  };
  }catch(error){bridge.setStatus(String(error));}
 };
 $('save-baseline').onclick=()=>{
  const keys=catalog.flatMap(e=>analyze(e,e.doc,catalog).map(i=>issueKey(e,i)));baseline=new Set(keys);
  const link=document.createElement('a');const url=URL.createObjectURL(new Blob([JSON.stringify({version:1,issues:keys,symbols:catalog.map(e=>e.symbolId),publicSymbols:catalog.filter(e=>isPublicApi(e,catalog)).map(e=>({symbolId:e.symbolId,name:e.canonicalName??e.fullName,file:e.fileName,line:e.lineNumber}))},null,2)],{type:'application/json'}));link.href=url;link.download='xmldoc-baseline.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 };
 $('load-baseline').onclick=()=>$<HTMLInputElement>('baseline-file').click();$<HTMLInputElement>('baseline-file').onchange=async()=>{
  try{const file=$<HTMLInputElement>('baseline-file').files?.[0];if(file){const data=JSON.parse(await file.text());if(data.version!==1 || !Array.isArray(data.issues))throw Error('Unsupported baseline');baseline=new Set(data.issues);publicBaseline=data.publicSymbols??[];renderCatalog();}}catch(e){bridge.setStatus(String(e));}
 };
 type Wording={kind?:string;section:string;name?:string;type?:string;text:string;language?:string};
 let authoring:{project:{templates?:Wording[];terminology?:string[]};global:{templates?:Wording[];terminology?:string[]}}={project:{},global:{}};
 const words=()=>[...(authoring.project.templates??[]).map(word=>({...word,origin:'Project'})),...(authoring.global.templates??[]).map(word=>({...word,origin:'Global'}))];
 const showWording=()=>{$<HTMLSelectElement>('template-choice').replaceChildren(...words().map((word,index)=>{const option=document.createElement('option');option.textContent=`${word.origin} · ${word.section} · ${word.name??'*'}: ${word.text}`;option.value=String(index);return option;}));};
 const saveAuthoring=(scope:'project'|'global')=>bridge.sendToHost({type:'saveAuthoring',scope,data:authoring[scope]} as any);
 $('save-template').onclick=()=>{
  const text=$<HTMLTextAreaElement>('template-text').value.trim();if(!text)return;
  const scope=$<HTMLSelectElement>('template-scope').value as 'project'|'global';
  const word={kind:$<HTMLSelectElement>('template-kind').value,section:$<HTMLSelectElement>('template-section').value,name:$<HTMLInputElement>('template-name').value,type:$<HTMLInputElement>('template-type').value,text,language:$<HTMLSelectElement>('spell-language').value};
  authoring[scope].templates=[...(authoring[scope].templates??[]),word];saveAuthoring(scope);
 };
 $('apply-template').onclick=()=>{
  const word=words()[Number($<HTMLSelectElement>('template-choice').value)];if(!word)return;
  const c=current();if(word.kind && word.kind!==c.element?.kind){bridge.setStatus('Wording is for a different element kind');return;}const doc=JSON.parse(JSON.stringify(c.doc)) as DocModel;
  if(word.section==='param' || word.section==='typeparam'){
   const key=word.section==='param'?'params':'typeParams';const expected=word.section==='param'?(c.element?.params??[]).map(p=>({name:p.name,type:p.type})):(c.element?.genericParams??[]).map(name=>({name,type:''}));
   doc[key]=[...(doc[key]??[])];
   for(const param of expected)if(wordingMatches(param.name,param.type,word.name,word.type)){
    const item=doc[key]!.find(p=>p.name.toLowerCase()===param.name.toLowerCase());if(!item)doc[key]!.push({name:param.name,description:escapeXml(word.text)});else if(!item.description)item.description=escapeXml(word.text);
   }
  }else{const key=word.section as 'summary'|'remarks'|'returns'|'value';if(doc[key]){bridge.setStatus('Section is not empty — wording was not replaced');return;}doc[key]=escapeXml(word.text);}
  review(doc);
 };
 $('save-terms').onclick=()=>{authoring.project.terminology=$<HTMLTextAreaElement>('project-terms').value.split(/\r?\n/).map(t=>t.trim()).filter(Boolean);saveAuthoring('project');};
 const spell=()=>{document.querySelectorAll<HTMLElement>('.tiptap').forEach(e=>{e.spellcheck=$<HTMLInputElement>('spell-enabled').checked;e.lang=$<HTMLSelectElement>('spell-language').value;});document.querySelectorAll<HTMLElement>('code,pre,.param-ref,.typeparam-ref,.see-ref').forEach(e=>e.spellcheck=false);};
 $('spell-language').onchange=spell;$('spell-enabled').onchange=spell;
 $('link-example').onclick=()=>{const source=$<HTMLInputElement>('example-source').value.trim(),region=$<HTMLInputElement>('example-region').value.trim();if(!source || /^[\\/]|:|(^|[\\/])\.\.([\\/]|$)/.test(source)){bridge.setStatus('Choose a relative project source file');return;}review({...current().doc,xmlEdited:true,rawXml:modelXml(current().doc)+`\n<example source="${escapeXml(source)}"${region?` region="${escapeXml(region)}"`:''}><para>Linked example: ${escapeXml(source)}</para></example>`});};
 $('insert-selection').onclick=()=>bridge.sendToHost({type:'copySelection'});
 $('replace-all').onclick=()=>{try{review(replaceProse(current().doc,$<HTMLInputElement>('find-doc').value,$<HTMLInputElement>('replace-doc').value));}catch(e){bridge.setStatus(String(e));}};
 let catalogRevision='';
 const inheritance=()=>{
  const c=current();const container=$('inheritance-sources');container.replaceChildren();if(!c.element)return;
  const effective=catalog.find(e=>e.symbolId===c.element!.symbolId && e.fileName===c.element!.fileName)?.effectiveDoc;
  if(effective?.inheritedFrom){const info=document.createElement('div');info.textContent='Inherited from '+effective.inheritedFrom;container.append(info);for(const section of ['summary','remarks','returns','value'] as const)if(!c.doc[section] && effective[section]){const text=document.createElement('pre');text.textContent=section+': '+effective[section];container.append(text);}}
  const typeName=(e:ElementInfo)=>(e.qualifiedParent?e.qualifiedParent+'.':'')+e.name+(e.genericParams?.length?'<'+e.genericParams.join(',')+'>':'');
  const type=catalog.find(e=>typeName(e)===c.element!.qualifiedParent && e.fileName===c.element!.fileName && ['class','interface'].includes(e.kind));
  const ancestors=[type?.ancestor,...(type?.implements??[])].filter(Boolean) as string[];
  for(const ancestor of ancestors){const name=ancestor.replace(/<.*>/,'').split('.').pop();
   const parents=catalog.filter(e=>e.name===name && (e.genericParams?.length??0)===genericArguments(ancestor).length && ['class','interface'].includes(e.kind));const sameUnit=parents.filter(e=>e.unitName===c.element!.unitName);const candidatesOfType=sameUnit.length?sameUnit:parents;
   const candidates=catalog.filter(e=>candidatesOfType.some(parent=>e.qualifiedParent===typeName(parent) && parent.fileName===e.fileName && compatibleInheritedMember(c.element!,e,parent,ancestor)));
   for(const source of candidates){const row=document.createElement('div');row.textContent=`Source: ${source.fileName} · ${source.signature}`;const copy=document.createElement('button');copy.textContent='Copy missing sections';setWorkbenchIcon(copy,'copy-documentation');copy.onclick=()=>review(inheritDoc(c.doc,source.doc));const jump=document.createElement('button');jump.textContent='Open source';setWorkbenchIcon(jump,'open-source');jump.onclick=()=>open(source);row.append(copy,jump);container.append(row);}
  }
 };
 (window as any).xmlDocWorkbench={receiveAnalysis(data:{state:string;completed:number;total:number;parsed:number;reused:number}){
 $('analysis-state').textContent=`Analysis ${data.state}: ${data.completed}/${data.total}; parsed ${data.parsed}, reused ${data.reused}`;$('cancel-analysis').hidden=data.state!=='running';
 },receiveDrafts(data:{drafts:any[]}){
    const panel=$('documentation-problems');panel.replaceChildren();
    for(const draft of data.drafts){const row=document.createElement('div');const label=document.createElement('span');label.textContent=`${draft.fileName} · ${draft.symbolId} · saved draft`;
      const recover=document.createElement('button');recover.textContent='Review against current documentation';setWorkbenchIcon(recover,'review-draft');recover.onclick=()=>{bridge.cancelPending();bridge.sendToHost({type:'recoverDraft',draftId:draft.draftId} as any);};row.append(label,recover);panel.append(row);}
    if(!data.drafts.length)panel.textContent='No recoverable drafts for this project.';
   },receiveRecovery(data:any){recovery=data;},receiveAuthoring(data:any){
    authoring={project:data.project??{},global:data.global??{}};showWording();$<HTMLTextAreaElement>('project-terms').value=(authoring.project.terminology??[]).join('\n');
    (window as any).xmlDocTerminology=[...(authoring.project.terminology??[]),...(authoring.global.terminology??[])];window.dispatchEvent(new CustomEvent('terminologyChanged'));
   },receiveBatchResult(data:{batchId:string;status:string;sourceRevisions?:Record<string,string>}){captureGrid();const batch=batches.get(data.batchId);if(!batch)return;if(data.status==='applied'){batch.applied=true;if(data.sourceRevisions)batch.sourceRevisions=Object.fromEntries(Object.entries(data.sourceRevisions).map(([file,revision])=>[file.replace(/\\/g,'/').toLowerCase(),revision]));}else batches.delete(data.batchId);reconcileBatches();renderCatalog(false,false);},receiveCatalog(data:{elements:TreeElementInfo[];errors?:string[]}){captureGrid();catalogLimit=100;catalog=data.elements.sort((a,b)=>`${a.unitName}.${a.qualifiedParent}.${a.kind}.${a.signature}`.localeCompare(`${b.unitName}.${b.qualifiedParent}.${b.kind}.${b.signature}`));reconcileBatches();renderCatalog(false,false);inheritance();if(data.errors?.length)bridge.setStatus(data.errors.join('; '));},receiveQuickDoc(data:{query:string;matches:TreeElementInfo[];resolved:boolean;reason?:string}){
   const panel=$('documentation-problems');panel.replaceChildren();
   const heading=document.createElement('strong');heading.textContent=data.resolved?'Quick documentation':`Choose a declaration for ${data.query}`;panel.append(heading);if(data.reason){const reason=document.createElement("p");reason.textContent=data.reason;panel.append(reason);}
   for(const e of data.matches){const row=document.createElement('div');const title=document.createElement('button');title.textContent=e.signature??e.name;const caption=document.createElement('span');caption.dataset.code='';caption.textContent=title.textContent;row.append(caption);title.title='Open source: '+title.textContent;title.textContent='Open source';setWorkbenchIcon(title,'open-source');title.onclick=()=>open(e);const prose=document.createElement('pre');prose.textContent=e.doc.summary+'\n'+(e.doc.params??[]).map(p=>p.name+': '+p.description).join('\n')+'\n'+(e.doc.returns??'');row.append(title,prose);panel.append(row);}
   if(!data.matches.length)panel.append(document.createTextNode('The symbol at the cursor could not be resolved. Use the project symbol picker.'));
  },receiveSelection(code:string){const doc=current().doc;review({...doc,examples:[...(doc.examples??[]),{title:'Selected source',description:'',code}]});}};
 window.addEventListener('documentationLoaded',(event)=>{
  const {element,doc}=(event as CustomEvent).detail;
  if(element){const last=history[index];if(!navigating && (last?.symbolId!==element.symbolId || last?.fileName!==element.fileName || last?.locationId!==element.locationId)){history=history.slice(0,index+1);history.push({locationId:element.locationId,projectFile:element.projectFile,fileName:element.fileName,symbolId:element.symbolId,line:element.lineNumber});index=history.length-1;}navigating=false;}
  xml.value=visibleXml();$('xml-error').textContent=doc.parseError??'';if(doc.parseError || doc.xmlEdited)viewXml(false);showProblems();inheritance();showWording();spell();showRecovery();
  bridge.sendToHost({type:'loadAuthoring'} as any);
  const revision=element?.fileName+'|'+element?.sourceRevision;if(revision!==catalogRevision){catalogRevision=revision;refresh();}
 });
 window.addEventListener('documentationQualityChanged',()=>{showProblems();renderCatalog();});
 window.addEventListener('documentationChanged',()=>{showProblems();spell();});
 window.addEventListener('docStatus',event=>{$('edit-status').textContent=(event as CustomEvent).detail;});
 window.addEventListener('requestReferencePicker',()=>{$('catalog-query').focus();refresh();});
 window.addEventListener('applyDocumentationBatch',event=>bridge.sendToHost({type:'batchUpdated',...(event as CustomEvent).detail} as any));
}
