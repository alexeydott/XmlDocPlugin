import {setLanguage,translate} from './i18n';
import {mergeRenderedDoc,sameDocContent} from './docTools';
import { applySourceAccess } from './sourceAccess';
import { Editor,Extension } from '@tiptap/core';
import { Plugin } from '@tiptap/pm/state';
import { Decoration,DecorationSet } from '@tiptap/pm/view';
import { OpaqueXml, DocumentationTable, DocumentationTableRow, DocumentationTableCell, serializeNode, textToHtml } from './xmlCodec';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import { CodeInline } from './nodes/codeInline';
import { SeeRef } from './nodes/seeRef';
import { ParamRef } from './nodes/paramRef';
import { TypeParamRef } from './nodes/typeParamRef';
import { bridge } from './bridge';
import type { DocModel, ElementInfo, ParamDoc, TypeParamDoc } from './types';
import { initToolbar, setActiveEditor, updateToolbarState } from './toolbar';
import { renderPreview } from './preview';
import { initWorkbench } from './workbench';

// ────────────────────────────────────────────
// State
// ────────────────────────────────────────────
let currentElement: ElementInfo | null = null;
let currentDoc: DocModel = { summary: '' };
let summaryEditor: Editor | null = null;
let remarksEditor: Editor | null = null;
let returnsEditor: Editor | null = null;
let valueEditor: Editor | null = null;
const positions=new Map<string,{scroll:number;fields:{from:number;to:number;focus:boolean}[]}>();
const Terminology=Extension.create({name:'projectTerminology',addProseMirrorPlugins(){return [new Plugin({props:{decorations(state){
 const known=new Set(((window as any).xmlDocTerminology??[]).map((s:string)=>s.toLowerCase()));const decorations:Decoration[]=[];
 state.doc.descendants((node,pos)=>{if(!node.isText || node.marks.some(m=>['codeInline','code','seeRef','paramRef','typeParamRef'].includes(m.type.name)))return;
  for(const match of (node.text??'').matchAll(/[\p{L}\p{N}_]+/gu))if(known.has(match[0].toLowerCase()))decorations.push(Decoration.inline(pos+match.index!,pos+match.index!+match[0].length,{spellcheck:'false'}));
 });return DecorationSet.create(state.doc,decorations);
 }}})];}});
const editors=()=>[summaryEditor,remarksEditor,returnsEditor,valueEditor,...fieldEditors.values()].filter((e):e is Editor=>!!e);

const sharedExtensions = [
  StarterKit.configure({ code: false }),Terminology,
  OpaqueXml,DocumentationTable,DocumentationTableRow,DocumentationTableCell,
  CodeInline,
  SeeRef,
  ParamRef,
  TypeParamRef,
];

// ────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────
function $(selector: string): HTMLElement | null {
  return document.querySelector(selector);
}

function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ────────────────────────────────────────────
// Serialization: TipTap → XML-aware text
// ────────────────────────────────────────────
function serializeContent(editor: Editor):string { return serializeNode(editor.state.doc); }
let baseline:DocModel={summary:''};
let original:DocModel={summary:''};
let loading=false;
const fieldEditors=new Map<HTMLElement,Editor>();
function readField(row:Element,selector:string):string {
 const field=row.querySelector<HTMLElement>(selector);
 return field ? (fieldEditors.has(field) ? serializeContent(fieldEditors.get(field)!) : field.innerText) : '';
}
function attachField(row:HTMLElement,selector:string):void {
 const field=row.querySelector<HTMLElement>(selector);if(!field)return;
 const text=field.textContent??'';field.innerHTML='';field.contentEditable='false';
 fieldEditors.set(field,createEditor(field,text,'Description...'));
}

// ────────────────────────────────────────────
// Collect Document
// ────────────────────────────────────────────
export function collectDoc(): DocModel {
  const doc: DocModel = {
    summary: summaryEditor ? serializeContent(summaryEditor) : '',
    sourceXml: original.sourceXml,
    parseError: original.parseError,
  };

  doc.params=[];doc.typeParams=[];doc.examples=[];doc.exceptions=[];doc.seeAlso=[];
  const remarksText = remarksEditor ? serializeContent(remarksEditor) : '';
  doc.remarks = remarksText;

  const returnsText = returnsEditor ? serializeContent(returnsEditor) : '';
  doc.returns = returnsText;

  const valueText = valueEditor ? serializeContent(valueEditor) : '';
  doc.value = valueText;

  // Params
  const paramRows = document.querySelectorAll('#params-body tr');
  if (paramRows.length > 0) {
    doc.params = [];
    paramRows.forEach(row => {
      const name = row.querySelector('.td-name')?.textContent ?? '';
      const desc = readField(row,'.td-desc');
      doc.params!.push({ name, description: desc });
    });
  }

  // TypeParams
  const tpRows = document.querySelectorAll('#typeparams-body tr');
  if (tpRows.length > 0) {
    doc.typeParams = [];
    tpRows.forEach(row => {
      const name = row.querySelector('.td-name')?.textContent ?? '';
      const desc = readField(row,'.td-desc');
      doc.typeParams!.push({ name, description: desc });
    });
  }

  // Examples
  const exampleRows = document.querySelectorAll<HTMLElement>('.example-row');
  if (exampleRows.length > 0) {
    doc.examples = [];
    exampleRows.forEach(row => {
      const description = readField(row,'.example-desc');
      const code = (row.querySelector('.example-code') as HTMLTextAreaElement)?.value ?? '';
      const title=(row.querySelector('.example-title') as HTMLInputElement)?.value??'';
      doc.examples!.push({source:row.dataset.source||undefined,region:row.dataset.region||undefined,title,description,code});
    });
  }

  // Exceptions
  const exRows = document.querySelectorAll('.exception-row');
  if (exRows.length > 0) {
    doc.exceptions = [];
    exRows.forEach(row => {
      const typeRef = (row.querySelector('.exception-type') as HTMLTextAreaElement)?.value ?? '';
      const desc = readField(row,'.exception-desc');
      doc.exceptions!.push({ typeRef, description: desc });
    });
  }

  // SeeAlso
  const seeRows = document.querySelectorAll('.seealso-row');
  if (seeRows.length > 0) {
    doc.seeAlso = [];
    seeRows.forEach(row => {
      const cref = (row.querySelector('.seealso-cref') as HTMLTextAreaElement)?.value ?? '';
      doc.seeAlso!.push({ cref, description:readField(row,'.seealso-description') });
    });
  }

  return doc;
}

function notifyChanged(): void {
  if(loading || bridge.readOnly)return;
  const rendered=collectDoc();
  const next=mergeRenderedDoc(original,baseline,rendered);
  if(JSON.stringify(next)===JSON.stringify(currentDoc))return;
  currentDoc=next;
  bridge.notifyDocChanged(currentDoc);
  window.dispatchEvent(new CustomEvent('documentationChanged',{detail:{element:currentElement,doc:currentDoc}}));
}

// ────────────────────────────────────────────
// Member Signature
// ────────────────────────────────────────────
function renderSignature(el: ElementInfo): void {
  const sig = $('#member-signature')!;
  const kind = el.methodKind ?? el.kind;
  const parent = el.qualifiedParent ? escapeHtml(el.qualifiedParent) : '';
  const name = escapeHtml(el.name);
  const generics = el.genericParams?.length
    ? `<span class="sig-generic">&lt;${el.genericParams.map(escapeHtml).join(', ')}&gt;</span>`
    : '';

  // Build parameter signature
  let paramSig = '';
  if (el.params?.length) {
    const params = el.params.map(p => escapeHtml(p.name)).join(', ');
    paramSig = `(${params})`;
  }

  const kindLabel = `<span class="sig-kind"> ${escapeHtml(kind.charAt(0).toUpperCase() + kind.slice(1))}</span>`;

  if (parent) {
    sig.innerHTML = `<span class="sig-parent">${parent}.</span>${name}${generics}${paramSig}${kindLabel}`;
  } else {
    sig.innerHTML = `${name}${generics}${paramSig}${kindLabel}`;
  }
}

// ────────────────────────────────────────────
// Render Sections
// ────────────────────────────────────────────
function refreshRows(body:HTMLElement,render:()=>void):void {
 const oldRows=Array.from(body.children) as HTMLElement[];
 render();
 for(const row of Array.from(body.children) as HTMLElement[]){
  const name=row.querySelector('.td-name')?.textContent;
  const old=oldRows.find(r=>r.querySelector('.td-name')?.textContent===name);
  if(!old)continue;
  const oldName=old.querySelector<HTMLElement>('.td-name'),newName=row.querySelector<HTMLElement>('.td-name');
  if(oldName && newName)oldName.title=newName.title;
  for(const [field,editor] of fieldEditors)if(row.contains(field)){editor.destroy();fieldEditors.delete(field);}
  row.replaceWith(old);oldRows.splice(oldRows.indexOf(old),1);
 }
 for(const row of oldRows)for(const [field,editor] of fieldEditors)if(row.contains(field)){editor.destroy();fieldEditors.delete(field);}
}
function renderParams(params: ParamDoc[], elementParams: ElementInfo['params']): void {
  const tbody = $('#params-body')!;
  tbody.innerHTML = '';

  const sigParams = elementParams ?? [];
  if (sigParams.length === 0) {
    $('#params-section')!.classList.add('hidden');
    return;
  }
  $('#params-section')!.classList.remove('hidden');

  sigParams.forEach(sp => {
    const docParam = params.find(p => p.name === sp.name);
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="td-name" title="${escapeHtml(sp.type ?? '')}">${escapeHtml(sp.name)}</td>
      <td class="td-desc" contenteditable="true">${escapeHtml(docParam?.description ?? '')}</td>
    `;
    const owner = currentElement;
    if (owner?.kind === 'method' && (owner.lineNumber ?? 0) > 0) {
      const nameCell = tr.querySelector<HTMLElement>('.td-name')!;
      nameCell.title = `${sp.type ?? ''}${sp.type ? '\n' : ''}Double-click to go to method`;
      nameCell.style.cursor = 'pointer';
      nameCell.addEventListener('dblclick', event => {
        event.preventDefault();
        if(currentElement?.lineNumber)bridge.sendToHost({ type: 'jumpToLine', line: currentElement.lineNumber });
      });
    }
    attachField(tr,'.td-desc');
    tbody.appendChild(tr);
  });
}

function renderTypeParams(typeParams: TypeParamDoc[], genericParams: string[] | undefined): void {
  const tbody = $('#typeparams-body')!;
  tbody.innerHTML = '';

  const sigTypeParams = genericParams ?? [];
  if (sigTypeParams.length === 0) {
    $('#typeparams-section')!.classList.add('hidden');
    return;
  }
  $('#typeparams-section')!.classList.remove('hidden');

  sigTypeParams.forEach(name => {
    const docTP = typeParams.find(tp => tp.name === name);
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="td-name">${escapeHtml(name)}</td>
      <td class="td-desc" contenteditable="true">${escapeHtml(docTP?.description ?? '')}</td>
    `;
    attachField(tr,'.td-desc');
    tbody.appendChild(tr);
  });
}

function renderExamples(examples: DocModel['examples']): void {
  const container = $('#examples-body')!;
  container.innerHTML = '';
  (examples ?? []).forEach(ex=>{addExampleRow(container,ex.description,ex.code,ex.title);const row=container.lastElementChild as HTMLElement;row.dataset.source=ex.source??'';row.dataset.region=ex.region??'';if(ex.source){const label=document.createElement('div');label.textContent='Source: '+ex.source+(ex.region?' · '+ex.region:'');row.prepend(label);}});
}

function addExampleRow(container: HTMLElement, description = '', code = '', title = ''): void {
  const row = document.createElement('div');
  row.className = 'example-row';
  row.innerHTML = `
    <div class="example-header">
      <input class="example-title" aria-label="Example title" placeholder="Example title" value="${escapeHtml(title)}">
      <button class="btn-remove" title="Remove">&times;</button>
    </div>
    <div class="example-desc" contenteditable="true" data-placeholder="Description (optional)...">${escapeHtml(description)}</div>
    <textarea class="example-code" placeholder="Code example..." rows="3">${escapeHtml(code)}</textarea>
  `;
  attachField(row,'.example-desc');
  row.querySelector('.example-title')!.addEventListener('input',()=>notifyChanged());
  row.querySelector('.example-code')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  container.appendChild(row);
}

function renderExceptions(exceptions: DocModel['exceptions']): void {
  const container = $('#exceptions-body')!;
  container.querySelectorAll('textarea').forEach(field => referenceFieldObserver.unobserve(field));
  container.innerHTML = '';
  (exceptions ?? []).forEach(ex => addExceptionRow(container, ex.typeRef, ex.description));
}

function resizeReferenceField(field: HTMLTextAreaElement): void {
  field.style.height = 'auto';
  const borderHeight = field.offsetHeight - field.clientHeight;
  field.style.height = `${field.scrollHeight + borderHeight}px`;
}

const referenceFieldObserver = new ResizeObserver(entries => {
  entries.forEach(entry => resizeReferenceField(entry.target as HTMLTextAreaElement));
});

function setupReferenceField(row: HTMLElement, selector: string): void {
  const field = row.querySelector<HTMLTextAreaElement>(selector)!;
  field.addEventListener('input', () => {
    field.value = field.value.replace(/[\r\n]+/g, '');
    resizeReferenceField(field);
    notifyChanged();
  });
  field.addEventListener('keydown', event => {
    if (event.key === 'Enter') event.preventDefault();
  });
  referenceFieldObserver.observe(field);
  row.querySelector('.btn-remove')!.addEventListener('click', () => referenceFieldObserver.unobserve(field));
  resizeReferenceField(field);
}

function addExceptionRow(container: HTMLElement, typeRef = '', description = ''): void {
  const row = document.createElement('div');
  row.className = 'exception-row';
  row.innerHTML = `
    <textarea class="exception-type" rows="1" placeholder="Exception type (e.g. EArgumentException)">${escapeHtml(typeRef)}</textarea>
    <span class="exception-desc" contenteditable="true" data-placeholder="Description...">${escapeHtml(description)}</span>
    <button class="btn-remove" title="Remove">&times;</button>
  `;
  attachField(row,'.exception-desc');
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  container.appendChild(row);
  setupReferenceField(row, '.exception-type');
}

function renderSeeAlso(seeAlso: DocModel['seeAlso']): void {
  const container = $('#seealso-body')!;
  container.querySelectorAll('textarea').forEach(field => referenceFieldObserver.unobserve(field));
  container.innerHTML = '';
  (seeAlso ?? []).forEach(sa => addSeeAlsoRow(container, sa.cref, sa.description));
}

function addSeeAlsoRow(container: HTMLElement, cref = '', description = ''): void {
  const row = document.createElement('div');
  row.className = 'seealso-row';
  row.innerHTML = `
    <textarea class="seealso-cref" rows="1" placeholder="Reference (e.g. TMyClass.DoWork)">${escapeHtml(cref)}</textarea>
    <span class="seealso-description" contenteditable="true">${escapeHtml(description)}</span>
    <button class="btn-remove" title="Remove">&times;</button>
  `;
  attachField(row,'.seealso-description');
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  container.appendChild(row);
  setupReferenceField(row, '.seealso-cref');
}

// ────────────────────────────────────────────
// Section Collapsing
// ────────────────────────────────────────────
function setupCollapsible(): void {
  const states: Record<string, boolean> = {};
  (window as any).xmlDocSections = {
    restore(saved: Record<string, boolean>) {
      document.querySelectorAll<HTMLElement>('.doc-section[id]').forEach(section => {
        if (typeof saved?.[section.id] === 'boolean') {
          states[section.id] = saved[section.id];
          section.classList.toggle('collapsed', saved[section.id]);
        }
      });
    },
  };
  document.querySelectorAll('.doc-heading').forEach(heading => {
    heading.addEventListener('click', () => {
      const section = heading.parentElement!;
      section.classList.toggle('collapsed');
      states[section.id] = section.classList.contains('collapsed');
      bridge.sendToHost({ type: 'sectionStateChanged', sections: { ...states } });
    });
  });
}

function setupAddButtons(): void {
  $('#btn-add-example')?.addEventListener('click', () => {
    addExampleRow($('#examples-body')!);
    notifyChanged();
  });

  $('#btn-add-exception')?.addEventListener('click', () => {
    addExceptionRow($('#exceptions-body')!);
    notifyChanged();
  });

  $('#btn-add-seealso')?.addEventListener('click', () => {
    addSeeAlsoRow($('#seealso-body')!);
    notifyChanged();
  });
}

// ────────────────────────────────────────────
// Tab Switching
// ────────────────────────────────────────────
function setupTabs(): void {
  document.querySelectorAll('#doc-tabs .tab').forEach(tab => {
    tab.addEventListener('click', () => {
      const target = (tab as HTMLElement).dataset.tab;

      document.querySelectorAll('#doc-tabs .tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      if (target === 'design') {
        $('#doc-design')!.classList.remove('hidden');
        $('#doc-preview')!.classList.add('hidden');
      } else {
        $('#doc-design')!.classList.add('hidden');
        $('#doc-preview')!.classList.remove('hidden');
        renderPreview($('#doc-preview')!, collectDoc(), currentElement);
      }
    });
  });
}

// ────────────────────────────────────────────
// TipTap Editors
// ────────────────────────────────────────────
function createEditor(element: HTMLElement, content: string, placeholder: string): Editor {
  return new Editor({
    element,
    extensions: [
      ...sharedExtensions,
      Placeholder.configure({ placeholder:()=>translate(placeholder) }),
    ],
    content: textToHtml(content),
    onUpdate: () => notifyChanged(),
    onFocus: ({ editor }) => setActiveEditor(editor),
  });
}

function initEditors(doc: DocModel): void {
  summaryEditor?.destroy();
  summaryEditor = createEditor($('#summary-editor')!, doc.summary, 'Enter a summary description...');

  remarksEditor?.destroy();
  remarksEditor = createEditor($('#remarks-editor')!, doc.remarks ?? '', 'Additional remarks...');

  returnsEditor?.destroy();
  returnsEditor = createEditor($('#returns-editor')!, doc.returns ?? '', 'Return value description...');

  valueEditor?.destroy();
  valueEditor = createEditor($('#value-editor')!, doc.value ?? '', 'Property value description...');
}

// ────────────────────────────────────────────
// Load Document
// ────────────────────────────────────────────
export function loadDocument(element: ElementInfo, doc: DocModel): void {
  const oldMetadata=JSON.stringify([currentElement?.params,currentElement?.genericParams,currentElement?.returnType,currentElement?.kind]);
  const key=(e:ElementInfo)=>`${e.fileName}|${e.locationId??e.declarationId??e.symbolId}`;
  const oldKey=currentElement?key(currentElement):'';
  if(currentElement)positions.set(oldKey,{scroll:$('#doc-design')?.scrollTop??0,fields:editors().map(e=>({from:e.state.selection.from,to:e.state.selection.to,focus:e.view.dom.contains(document.activeElement)}))});
  if(currentElement && oldKey===key(element) && sameDocContent(currentDoc,doc)){
    currentElement=element;currentDoc=doc;original=JSON.parse(JSON.stringify(doc));renderSignature(element);
    if(oldMetadata!==JSON.stringify([element.params,element.genericParams,element.returnType,element.kind])){
      loading=true;
      refreshRows($('#params-body')!,()=>renderParams(doc.params??[],element.params));
      refreshRows($('#typeparams-body')!,()=>renderTypeParams(doc.typeParams??[],element.genericParams));
      const hasReturn=element.kind==='method' && !!element.returnType;
      $('#returns-section')!.classList.toggle('hidden',!hasReturn);$('#value-section')!.classList.toggle('hidden',element.kind!=='property');
      $('#exceptions-section')!.classList.toggle('hidden',element.kind==='unit');
      $('#return-type')!.textContent=element.returnType?'Type: '+element.returnType:'';
      loading=false;
    }
    updateToolbarState(element);baseline=collectDoc();editors().forEach(e=>e.setEditable(!bridge.readOnly));applySourceAccess(bridge.readOnly,bridge.readOnlyReason);
    window.dispatchEvent(new CustomEvent('documentationLoaded',{detail:{element,doc}}));return;
  }
  loading=true;
  // Context is owned by the bridge for incoming documents. Local preview operations retain it.

  fieldEditors.forEach(editor=>editor.destroy());fieldEditors.clear();
  (window as any).xmlDocResourceBase=element.resourceBase;
  currentElement = element;
  currentDoc = doc;original=JSON.parse(JSON.stringify(doc));

  renderSignature(element);
  initEditors(doc);
  renderParams(doc.params ?? [], element.params);
  renderTypeParams(doc.typeParams ?? [], element.genericParams);

  // Return type display
  const hasReturn = element.kind === 'method' && !!element.returnType;
  const isProperty = element.kind === 'property';
  $('#returns-section')!.classList.toggle('hidden', !hasReturn);
  $('#value-section')!.classList.toggle('hidden', !isProperty);
  $('#exceptions-section')!.classList.toggle('hidden', element.kind === 'unit');

  if (hasReturn && element.returnType) {
    $('#return-type')!.innerHTML = `Type: <strong>${escapeHtml(element.returnType)}</strong>`;
  }

  renderExamples(doc.examples);
  renderExceptions(doc.exceptions);
  renderSeeAlso(doc.seeAlso);
  updateToolbarState(element);
  editors().forEach(e=>e.setEditable(!bridge.readOnly));
  applySourceAccess(bridge.readOnly,bridge.readOnlyReason);
  baseline=collectDoc();loading=false;
  const position=positions.get(key(element));
  if(position){
    editors().forEach((editor,i)=>{const saved=position.fields[i];if(!saved)return;const max=editor.state.doc.content.size;
      editor.commands.setTextSelection({from:Math.min(saved.from,max),to:Math.min(saved.to,max)});
      if(oldKey===key(element) && saved.focus && document.hasFocus())editor.commands.focus();
    });
    $('#doc-design')!.scrollTop=position.scroll;
  }
  window.dispatchEvent(new CustomEvent('documentationLoaded',{detail:{element,doc}}));
}

// ────────────────────────────────────────────
// Init
// ────────────────────────────────────────────
export function init(): void {
  let theme = 'light';
  const darkMode = window.matchMedia('(prefers-color-scheme: dark)');
  const applyTheme = () => {
    document.documentElement.dataset.theme =
      theme === 'auto' ? (darkMode.matches ? 'dark' : 'light') : theme;
  };
  darkMode.addEventListener('change', applyTheme);
  (window as any).xmlDocSettings = {
    apply(settings: { theme: string; fontSize: number; showSignatureHeader: boolean; language?:string; saveDebounceMs?:number }) {
      setLanguage(settings.language??'en');
      bridge.saveDebounceMs=Math.max(0,settings.saveDebounceMs??500);
      theme = ['light', 'dark', 'auto'].includes(settings.theme) ? settings.theme : 'light';
      applyTheme();
      document.body.style.fontSize = `${Math.max(8, Math.min(40, settings.fontSize))}px`;
      const signature = $('#member-signature');
      if (signature) signature.style.display = settings.showSignatureHeader ? '' : 'none';
    },
  };
  window.addEventListener('uiLanguageChanged',()=>editors().forEach(e=>e.view.dispatch(e.state.tr)));
  window.addEventListener('terminologyChanged',()=>editors().forEach(e=>e.view.dispatch(e.state.tr)));
  initToolbar();
  setupCollapsible();
  setupAddButtons();
  setupTabs();
  (window as any).xmlDocEditor={
    get:()=>({element:currentElement,doc:currentDoc}),
    apply:(doc:DocModel)=>{if(currentElement && !bridge.readOnly){loadDocument(currentElement,doc);bridge.notifyDocChanged(doc);}},
  };
  initWorkbench({get:()=>({element:currentElement,doc:currentDoc}),apply:(doc)=>{
    if(!currentElement || bridge.readOnly)return;
    const element=currentElement;loadDocument(element,doc);bridge.notifyDocChanged(doc);
  }});

  const access=document.createElement('div');access.id='source-access-status';access.setAttribute('role','status');access.hidden=true;document.getElementById('doc-toolbar')?.before(access);
  const refreshAccess=()=>{editors().forEach(e=>{if(e.isEditable===bridge.readOnly)e.setEditable(!bridge.readOnly);});applySourceAccess(bridge.readOnly,bridge.readOnlyReason);};
  window.addEventListener('sourceReadOnlyChanged',refreshAccess);
  const accessObserver=new MutationObserver(refreshAccess);
  for(const id of ['doc-design','workbench','doc-xml']){const root=document.getElementById(id);if(root)accessObserver.observe(root,{childList:true,subtree:true});}
  bridge.onElementLoaded((element, doc) => {
    loadDocument(element, doc);
  });

  // 디버깅용: 샘플 데이터 로드
  if (!((window as any).chrome?.webview)) {
    loadDocument(
      {
        kind: 'method',
        name: 'GetValueOrDefault',
        qualifiedParent: 'Nullable<T>',
        methodKind: 'function',
        params: [
          { name: 'defaultValue', type: 'T' },
        ],
        returnType: 'T',
        genericParams: ['T'],
      },
      {
        summary: 'Retrieves the value of the current <c>Nullable{T}</c> object, or the specified default value.',
        params: [
          { name: 'defaultValue', description: 'A value to return if the <see cref="HasValue">HasValue</see> property is false.' },
        ],
        typeParams: [
          { name: 'T', description: 'The underlying value type of the nullable type.' },
        ],
        returns: 'The value of the <see cref="Value">Value</see> property if the <see cref="HasValue">HasValue</see> property is true; otherwise, the <paramref name="defaultValue"/> parameter.',
        examples: [
          { description: 'Basic usage', code: 'var result = nullable.GetValueOrDefault(0);' },
        ],
        exceptions: [
          { typeRef: 'EInvalidOperation', description: 'Thrown when the value cannot be retrieved.' },
        ],
        seeAlso: [{ cref: 'Nullable<T>.HasValue' }],
      }
    );
  }
}
