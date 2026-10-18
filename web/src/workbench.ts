import { bridge } from './bridge';
import { analyze, synchronize, modelXml, parseXml, inheritDoc, ready, issueKey, replaceProse, compatibleInheritedMember, wordingMatches, editableXml } from './docTools';
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
 <input id="reference-label" placeholder="Reference display text (optional)" aria-label="Reference display text"><input id="catalog-query" placeholder="Find symbol or documentation" aria-label="Find symbol or documentation"><select id="catalog-filter" aria-label="Documentation filter"><option value="all">All symbols</option><option value="public">Public API</option><option value="missing">No documentation</option><option value="todo">TODO drafts</option><option value="incomplete">Incomplete signature</option><option value="links">Reference problems</option><option value="review">New problems</option></select>
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
 let applyPreview:(()=>void)|null=null;let preview:DocModel|null=null;let baseline=new Set<string>();let publicBaseline: {symbolId:string;name:string;file:string;line:number}[]=[];let history:{fileName?:string;symbolId?:string;line?:number}[]=[];let index=-1;let navigating=false;
 const current=()=>hooks.get();
 const open=(element:ElementInfo)=>{
  if(!element.fileName || !element.symbolId)return;
  bridge.sendToHost({type:'openSymbol',fileName:element.fileName,symbolId:element.symbolId,line:element.lineNumber??1});
 };
 const viewXml=()=>{
  $('doc-design').classList.add('hidden');$('doc-preview').classList.add('hidden');raw.classList.remove('hidden');
  xml.value=editableXml(current().doc);xml.focus();
 };
 const review=(doc:DocModel)=>{
  preview=doc;const target=current().element;applyPreview=()=>{if(current().element?.declarationId!==target?.declarationId || current().element?.sourceRevision!==target?.sourceRevision){bridge.setStatus('Source changed — review again');return;}hooks.apply(doc);};$('xml-before').textContent=editableXml(current().doc);$('xml-after').textContent=modelXml(doc);$('operation-preview').hidden=false;
 };
 const issues=()=>{const c=current();return c.element?analyze(c.element,c.doc,catalog):[];};
 const showProblems=()=>{
  const container=$('documentation-problems');container.replaceChildren();
  for(const issue of issues()){
   const row=document.createElement('div');row.className='documentation-issue';
   const text=document.createElement('span');text.textContent=`${issue.code} (${issue.line}:${issue.column}) ${issue.message}`;row.append(text);
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
  for(const param of old){const label=document.createElement('label');label.textContent=`Map ${param.name}: `;const select=document.createElement('select');select.innerHTML='<option value="">Keep unmatched description</option>'+expected.map(n=>`<option>${escapeXml(n)}</option>`).join('');select.onchange=()=>{if(select.value)mappings[param.name]=select.value;else delete mappings[param.name];};label.append(select);panel.append(label);}
  const next=document.createElement('button');next.textContent='Preview synchronization';setWorkbenchIcon(next,'preview-change');next.onclick=()=>{try{review(synchronize(c.element!,c.doc,mappings));panel.remove();}catch(e){bridge.setStatus(String(e));}};panel.append(next);
  $('documentation-problems').replaceChildren(panel);if(!old.length)next.click();
 };
 $('quick-documentation').onclick=()=>bridge.sendToHost({type:'requestQuickDoc'} as any);
 $('sync-document').onclick=sync;$('show-problems').onclick=showProblems;$('open-xml').onclick=viewXml;
 $('apply-operation').onclick=()=>{applyPreview?.();applyPreview=null;preview=null;$('operation-preview').hidden=true;};
 $('cancel-operation').onclick=()=>{applyPreview=null;preview=null;$('operation-preview').hidden=true;};
 $('fold-documentation').onclick=()=>bridge.sendToHost({type:'foldDocumentation'} as any);
 $('format-document').onclick=()=>{const text=editableXml(current().doc);const parsed=parseXml(text);if(parsed.querySelector('parsererror')){viewXml();return;}review({...current().doc,rawXml:Array.from(parsed.documentElement.childNodes).map(n=>new XMLSerializer().serializeToString(n)).join('\n'),xmlEdited:true});};
 $('apply-xml').onclick=()=>{
  const parsed=parseXml(xml.value);const error=parsed.querySelector('parsererror');
  $('xml-error').textContent=error?.textContent??'';
  if(!error)hooks.apply({...current().doc,rawXml:xml.value,xmlEdited:true,parseError:undefined});
 };
 document.querySelectorAll('#doc-tabs .tab').forEach(tab=>tab.addEventListener('click',()=>raw.classList.add('hidden')));
 $('pin-document').onclick=()=>{const pinned=!bridge.pinned;bridge.setPinned(pinned);$('pin-document').setAttribute('aria-pressed',String(pinned));bridge.sendToHost({type:'pin',pinned});};
 $('compact-document').onclick=()=>{document.body.classList.toggle('compact');$('compact-document').setAttribute('aria-pressed',String(document.body.classList.contains('compact')));};
 $('focus-source').onclick=()=>{const e=current().element;if(e)open(e);};
 $('recover-drafts').onclick=()=>bridge.sendToHost({type:'listDrafts'} as any);
 $('reload-document').onclick=()=>{bridge.cancelPending();bridge.drafts.clear();bridge.setPinned(false);bridge.sendToHost({type:'requestRefresh'});};
 const move=(delta:number)=>{const next=index+delta;if(next>=0 && next<history.length){index=next;navigating=true;const e=history[index];if(e.fileName && e.symbolId)bridge.sendToHost({type:'openSymbol',fileName:e.fileName,symbolId:e.symbolId,line:e.line??1});}};
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
   if(!`${e.signature} ${e.fullName} ${modelXml(e.doc)}`.toLowerCase().includes(q))return false;
   const problems=analyze(e,e.doc,catalog);
   switch(filter){case 'public':return !e.visibility || ['public','published'].includes(e.visibility);case 'missing':return !e.doc.summary;case 'todo':return /\bTODO\b/i.test(modelXml(e.doc));case 'incomplete':return problems.some(p=>['XD002','XD003','XD004','XD005','XD009','XD010'].includes(p.code));case 'links':return problems.some(p=>p.code==='XD006'||p.code==='XD007');case 'review':return problems.some(p=>!baseline.has(issueKey(e,p)));default:return true;}
  });
 };
 let queueIndex=-1;
 const renderCatalog=()=>{
  const results=$('catalog-results');results.replaceChildren();
  for(const old of publicBaseline)if(!catalog.some(e=>e.symbolId===old.symbolId)){const row=document.createElement('div');row.className='documentation-issue';row.textContent=`XD011 Public declaration removed or signature changed: ${old.name}`;results.append(row);}
  for(const element of filtered()){
   const row=document.createElement('div');row.className='catalog-row';row.tabIndex=0;row.setAttribute('role','option');
   const button=document.createElement('button');button.textContent=`${element.fileName?.split(/[\\/]/).pop()} · ${element.signature??element.fullName??element.name}`;const caption=document.createElement('span');caption.className='symbol-caption';caption.textContent=button.textContent;row.append(caption);button.title='Open source: '+button.textContent;button.textContent='Open source';setWorkbenchIcon(button,'open-source');button.onclick=()=>open(element);row.append(button);
   const insert=document.createElement('button');insert.textContent='Reference';insert.title='Insert a reference to this exact overload';setWorkbenchIcon(insert,'reference');insert.onclick=()=>window.dispatchEvent(new CustomEvent('insertReference',{detail:{cref:element.symbolId,text:$<HTMLInputElement>('reference-label').value||element.name}}));row.append(insert);
   const copy=document.createElement('button');copy.textContent='Copy documentation';setWorkbenchIcon(copy,'copy-documentation');copy.onclick=()=>{
    const target=current().element;if(!target)return;const mapping:Record<string,string>={};const panel=document.createElement('div');
    const expected=[...target.params.map(p=>p.name),...(target.genericParams??[])];
    for(const parameter of [...element.params.map(p=>p.name),...(element.genericParams??[])]){const label=document.createElement('label');label.textContent=parameter+' → ';const select=document.createElement('select');
     const unmatched=document.createElement('option');unmatched.value='';unmatched.textContent='Keep unmatched description';select.append(unmatched);
     for(const name of expected){const option=document.createElement('option');option.value=name;option.textContent=name;select.append(option);}const exact=expected.find(n=>n.toLowerCase()===parameter.toLowerCase());if(exact)select.value=exact;
     select.onchange=()=>{if(select.value && select.value!==parameter)mapping[parameter]=select.value;else delete mapping[parameter];};label.append(select);panel.append(label);
    }
    const next=document.createElement('button');next.textContent='Preview copy';setWorkbenchIcon(next,'preview-change');next.onclick=()=>{try{const source=element.effectiveDoc??element.doc;const independent=synchronize(target,source,mapping);independent.inheritedFrom=undefined;
     if(independent.sourceXml){const parsed=parseXml(independent.sourceXml);parsed.querySelectorAll('inheritdoc').forEach(n=>n.remove());independent.sourceXml=Array.from(parsed.documentElement.childNodes).map(n=>new XMLSerializer().serializeToString(n)).join('');}
     review(independent);panel.remove();}catch(e){bridge.setStatus(String(e));}};panel.append(next);$('documentation-problems').replaceChildren(panel);
   };row.append(copy);
   row.onkeydown=event=>{if(event.key==='Enter')open(element);if(event.key==='ArrowDown')row.nextElementSibling instanceof HTMLElement&&row.nextElementSibling.focus();if(event.key==='ArrowUp')row.previousElementSibling instanceof HTMLElement&&row.previousElementSibling.focus();};
   const summary=document.createElement('span');summary.textContent=element.doc.summary;row.append(summary);results.append(row);
  }
  const members=$('member-summaries');members.replaceChildren();
  const owner=current().element?.qualifiedParent || current().element?.name;
  for(const element of filtered().filter(e=>e.qualifiedParent===owner && e.fileName===current().element?.fileName)){
   const row=document.createElement('label');const selected=document.createElement('input');selected.type='checkbox';selected.dataset.id=element.symbolId;selected.disabled=!!element.readOnly;selected.dataset.sourceLocked=String(!!element.readOnly);
   const name=document.createElement('span');name.textContent=element.signature??element.name;
   const input=document.createElement('textarea');input.value=element.doc.summary;input.dataset.id=element.symbolId;input.readOnly=!!element.readOnly;input.dataset.sourceLocked=String(!!element.readOnly);input.setAttribute('aria-label',`Summary for ${element.signature??element.name}`);row.append(selected,name,input);members.append(row);
  }
 };
 $('catalog-query').oninput=renderCatalog;$('catalog-filter').onchange=renderCatalog;$('catalog-kind').onchange=renderCatalog;
 const refresh=()=>bridge.sendToHost({type:'requestCatalog',scope:$<HTMLSelectElement>('catalog-scope').value as 'module'|'project'|'group'});
 $('refresh-catalog').onclick=refresh;$('next-problem').onclick=()=>{const list=filtered().filter(e=>!ready(e,e.doc,catalog));if(list.length)open(list[(++queueIndex)%list.length]);};
 $('apply-summaries').onclick=()=>{
  const changes=Array.from($('member-summaries').querySelectorAll<HTMLInputElement>('input:checked')).map(check=>{
   const e=catalog.find(e=>e.symbolId===check.dataset.id)!;const input=Array.from($('member-summaries').querySelectorAll<HTMLTextAreaElement>('textarea')).find(t=>t.dataset.id===check.dataset.id)!;return {element:e,doc:{...e.doc,summary:escapeXml(input.value)}};
  });
  if(!changes.length)return;
  $('xml-before').textContent=changes.map(c=>c.element.signature+'\n'+modelXml(c.element.doc)).join('\n');$('xml-after').textContent=changes.map(c=>c.element.signature+'\n'+modelXml(c.doc)).join('\n');$('operation-preview').hidden=false;
  applyPreview=()=>window.dispatchEvent(new CustomEvent('applyDocumentationBatch',{detail:changes}));
 };
 $('save-baseline').onclick=()=>{
  const keys=catalog.flatMap(e=>analyze(e,e.doc,catalog).map(i=>issueKey(e,i)));baseline=new Set(keys);
  const link=document.createElement('a');const url=URL.createObjectURL(new Blob([JSON.stringify({version:1,issues:keys,symbols:catalog.map(e=>e.symbolId),publicSymbols:catalog.filter(e=>!e.visibility || ['public','published','protected'].includes(e.visibility)).map(e=>({symbolId:e.symbolId,name:e.canonicalName??e.fullName,file:e.fileName,line:e.lineNumber}))},null,2)],{type:'application/json'}));link.href=url;link.download='xmldoc-baseline.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
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
 const spell=()=>{document.documentElement.lang=$<HTMLSelectElement>('spell-language').value;document.querySelectorAll<HTMLElement>('.tiptap').forEach(e=>e.spellcheck=$<HTMLInputElement>('spell-enabled').checked);document.querySelectorAll<HTMLElement>('code,pre,.param-ref,.typeparam-ref,.see-ref').forEach(e=>e.spellcheck=false);};
 $('spell-language').onchange=spell;$('spell-enabled').onchange=spell;
 $('link-example').onclick=()=>{const source=$<HTMLInputElement>('example-source').value.trim(),region=$<HTMLInputElement>('example-region').value.trim();if(!source || /^[\\/]|:|(^|[\\/])\.\.([\\/]|$)/.test(source)){bridge.setStatus('Choose a relative project source file');return;}review({...current().doc,xmlEdited:true,rawXml:modelXml(current().doc)+`\n<example source="${escapeXml(source)}"${region?` region="${escapeXml(region)}"`:''}><para>Linked example: ${escapeXml(source)}</para></example>`});};
 $('insert-selection').onclick=()=>bridge.sendToHost({type:'copySelection'});
 $('replace-all').onclick=()=>{try{review(replaceProse(current().doc,$<HTMLInputElement>('find-doc').value,$<HTMLInputElement>('replace-doc').value));}catch(e){bridge.setStatus(String(e));}};
 let catalogRevision='';
 const inheritance=()=>{
  const c=current();const container=$('inheritance-sources');container.replaceChildren();if(!c.element)return;
  const effective=catalog.find(e=>e.symbolId===c.element!.symbolId && e.fileName===c.element!.fileName)?.effectiveDoc;
  if(effective?.inheritedFrom){const info=document.createElement('div');info.textContent='Inherited from '+effective.inheritedFrom;container.append(info);for(const section of ['summary','remarks','returns','value'] as const)if(!c.doc[section] && effective[section]){const text=document.createElement('pre');text.textContent=section+': '+effective[section];container.append(text);}}
  const type=catalog.find(e=>e.name===c.element!.qualifiedParent && e.fileName===c.element!.fileName && ['class','interface'].includes(e.kind));
  const ancestors=[type?.ancestor,...(type?.implements??[])].filter(Boolean) as string[];
  for(const ancestor of ancestors){const name=ancestor.replace(/<.*>/,'').split('.').pop();
   const parents=catalog.filter(e=>e.name===name && ['class','interface'].includes(e.kind));const sameUnit=parents.filter(e=>e.unitName===c.element!.unitName);const candidatesOfType=sameUnit.length?sameUnit:parents;
   const candidates=catalog.filter(e=>e.qualifiedParent===name && candidatesOfType.some(parent=>parent.fileName===e.fileName && compatibleInheritedMember(c.element!,e,parent,ancestor)));
   for(const source of candidates){const row=document.createElement('div');row.textContent=`Source: ${source.fileName} · ${source.signature}`;const copy=document.createElement('button');copy.textContent='Copy missing sections';setWorkbenchIcon(copy,'copy-documentation');copy.onclick=()=>review(inheritDoc(c.doc,source.doc));const jump=document.createElement('button');jump.textContent='Open source';setWorkbenchIcon(jump,'open-source');jump.onclick=()=>open(source);row.append(copy,jump);container.append(row);}
  }
 };
 (window as any).xmlDocWorkbench={receiveDrafts(data:{drafts:any[]}){
    const panel=$('documentation-problems');panel.replaceChildren();
    for(const draft of data.drafts){const row=document.createElement('div');const label=document.createElement('span');label.textContent=`${draft.fileName} · ${draft.symbolId} · saved draft`;
      const recover=document.createElement('button');recover.textContent='Review against current documentation';setWorkbenchIcon(recover,'review-draft');recover.onclick=()=>review(draft.doc);row.append(label,recover);panel.append(row);}
    if(!data.drafts.length)panel.textContent='No recoverable drafts for this project.';
   },receiveAuthoring(data:any){
    authoring={project:data.project??{},global:data.global??{}};showWording();$<HTMLTextAreaElement>('project-terms').value=(authoring.project.terminology??[]).join('\n');
    (window as any).xmlDocTerminology=[...(authoring.project.terminology??[]),...(authoring.global.terminology??[])];window.dispatchEvent(new CustomEvent('terminologyChanged'));
   },receiveCatalog(data:{elements:TreeElementInfo[];errors?:string[]}){catalog=data.elements.sort((a,b)=>`${a.unitName}.${a.qualifiedParent}.${a.kind}.${a.signature}`.localeCompare(`${b.unitName}.${b.qualifiedParent}.${b.kind}.${b.signature}`));renderCatalog();inheritance();if(data.errors?.length)bridge.setStatus(data.errors.join('; '));},receiveQuickDoc(data:{query:string;matches:TreeElementInfo[];resolved:boolean}){
   const panel=$('documentation-problems');panel.replaceChildren();
   const heading=document.createElement('strong');heading.textContent=data.resolved?'Quick documentation':`Choose a declaration for ${data.query}`;panel.append(heading);
   for(const e of data.matches){const row=document.createElement('div');const title=document.createElement('button');title.textContent=e.signature??e.name;const caption=document.createElement('span');caption.textContent=title.textContent;row.append(caption);title.title='Open source: '+title.textContent;title.textContent='Open source';setWorkbenchIcon(title,'open-source');title.onclick=()=>open(e);const prose=document.createElement('pre');prose.textContent=e.doc.summary+'\n'+(e.doc.params??[]).map(p=>p.name+': '+p.description).join('\n')+'\n'+(e.doc.returns??'');row.append(title,prose);panel.append(row);}
   if(!data.matches.length)panel.append(document.createTextNode('The symbol at the cursor could not be resolved. Use the project symbol picker.'));
  },receiveSelection(code:string){const doc=current().doc;review({...doc,examples:[...(doc.examples??[]),{title:'Selected source',description:'',code}]});}};
 window.addEventListener('documentationLoaded',(event)=>{
  const {element,doc}=(event as CustomEvent).detail;
  if(element){const last=history[index];if(!navigating && (last?.symbolId!==element.symbolId || last?.fileName!==element.fileName)){history=history.slice(0,index+1);history.push({fileName:element.fileName,symbolId:element.symbolId,line:element.lineNumber});index=history.length-1;}navigating=false;}
  xml.value=editableXml(doc);$('xml-error').textContent=doc.parseError??'';if(doc.parseError || doc.xmlEdited)viewXml();showProblems();inheritance();showWording();spell();
  bridge.sendToHost({type:'loadAuthoring'} as any);
  const revision=element?.fileName+'|'+element?.sourceRevision;if(revision!==catalogRevision){catalogRevision=revision;refresh();}
 });
 window.addEventListener('documentationChanged',()=>{showProblems();spell();});
 window.addEventListener('docStatus',event=>{$('edit-status').textContent=(event as CustomEvent).detail;});
 window.addEventListener('requestReferencePicker',()=>{$('catalog-query').focus();refresh();});
 window.addEventListener('applyDocumentationBatch',event=>bridge.sendToHost({type:'batchUpdated',changes:(event as CustomEvent).detail} as any));
}
