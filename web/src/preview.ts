import type { DocModel, ElementInfo } from './types';

function esc(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** inline XML 태그를 Preview용 HTML로 변환 */
export function inlineToPreviewHtml(text:string):string {
 const doc=new DOMParser().parseFromString('<doc>'+text+'</doc>','application/xml');
 if(doc.querySelector('parsererror'))return esc(text);
 const render=(node:Node):string=>{
  if(node.nodeType===3 || node.nodeType===4)return esc(node.textContent??'');
  if(node.nodeType!==1)return '';
  const e=node as Element;const content=()=>Array.from(e.childNodes).map(render).join('');
  switch(e.tagName){
   case 'para':return `<p>${content()}</p>`;
   case 'b':case 'strong':return `<strong>${content()}</strong>`;
   case 'i':case 'em':return `<em>${content()}</em>`;
   case 'c':return `<code>${content()}</code>`;
   case 'code':return `<pre><code>${esc(e.textContent??'')}</code></pre>`;
   case 'br':return '<br>';
   case 'paramref':case 'typeparamref':return `<strong>${esc(e.getAttribute('name')??'')}</strong>`;
   case 'see':return `<span class="preview-see-ref">${content()||esc(e.getAttribute('cref')??'')}</span>`;
   case 'list':{
    if(e.getAttribute('type')==='table')return `<table>${Array.from(e.children).map(row=>`<tr>${Array.from(row.children).map(cell=>`<${row.tagName==='listheader'?'th':'td'}>${Array.from(cell.childNodes).map(render).join('')}</${row.tagName==='listheader'?'th':'td'}>`).join('')}</tr>`).join('')}</table>`;
    const tag=e.getAttribute('type')==='number'?'ol':'ul';return `<${tag}>${Array.from(e.children).map(row=>`<li>${Array.from(row.childNodes).map(render).join('')}</li>`).join('')}</${tag}>`;
   }
   case 'term':return `<strong>${content()}</strong> `;
   case 'description':return content();
   case 'img':case 'image':{
    const src=e.getAttribute('src')??'';const base=(window as any).xmlDocResourceBase;
    if(base && !/^(?:[a-z]+:|[\\/])|(?:^|[\\/])\.\.(?:[\\/]|$)/i.test(src))return `<img src="${esc(new URL(src.replace(/\\/g,'/'),base).href)}" alt="${esc(e.getAttribute('alt')??'')}" style="max-width:100%">`;
    return `<span>${esc(e.getAttribute('alt')??src)}</span>`;
   }
   default:return content();
  }
 };
 return Array.from(doc.documentElement.childNodes).map(render).join('');
}
function textToPreviewP(text:string):string {return inlineToPreviewHtml(text).replace(/\r?\n/g,'<br>');}

export function renderPreview(
  container: HTMLElement,
  doc: DocModel,
  element: ElementInfo | null,
): void {
  let html = doc.inheritedFrom?`<p>Inherited from ${esc(doc.inheritedFrom)}</p>`:'';

  // Summary
  if (doc.summary) {
    html += `<h2>Summary</h2>`;
    html += textToPreviewP(doc.summary);
  }

  // Parameters
  if (doc.params?.length) {
    html += `<h2>Parameters</h2>`;
    html += `<table><thead><tr><th>Parameter</th><th>Description</th></tr></thead><tbody>`;
    doc.params.forEach(p => {
      html += `<tr><td><strong>${esc(p.name)}</strong></td><td>${inlineToPreviewHtml(p.description)}</td></tr>`;
    });
    html += `</tbody></table>`;
  }

  // Type Parameters
  if (doc.typeParams?.length) {
    html += `<h2>Type Parameters</h2>`;
    html += `<table><thead><tr><th>Type Parameter</th><th>Description</th></tr></thead><tbody>`;
    doc.typeParams.forEach(tp => {
      html += `<tr><td><em>${esc(tp.name)}</em></td><td>${inlineToPreviewHtml(tp.description)}</td></tr>`;
    });
    html += `</tbody></table>`;
  }

  // Returns
  if (doc.returns) {
    html += `<h2>Return Value</h2>`;
    if (element?.returnType) {
      html += `<p>Type: <strong>${esc(element.returnType)}</strong></p>`;
    }
    html += textToPreviewP(doc.returns);
  }

  // Value
  if (doc.value) {
    html += `<h2>Value</h2>`;
    html += textToPreviewP(doc.value);
  }

  // Remarks
  if (doc.remarks) {
    html += `<h2>Remarks</h2>`;
    html += textToPreviewP(doc.remarks);
  }

  // Examples
  if (doc.examples?.length) {
    html += `<h2>Examples</h2>`;
    doc.examples.forEach(ex => {
      if(ex.source)html+=`<p>Source: ${esc(ex.source)}${ex.region?' · '+esc(ex.region):''}</p>`;
      if(ex.title)html+=`<h3>${esc(ex.title)}</h3>`;
      if (ex.description) {
        html += `<p>${inlineToPreviewHtml(ex.description)}</p>`;
      }
      if (ex.code) {
        html += `<pre>${esc(ex.code)}</pre>`;
      }
    });
  }

  // Exceptions
  if (doc.exceptions?.length) {
    html += `<h2>Exceptions</h2>`;
    html += `<table><thead><tr><th>Exception</th><th>Condition</th></tr></thead><tbody>`;
    doc.exceptions.forEach(ex => {
      html += `<tr><td><strong>${esc(ex.typeRef)}</strong></td><td>${inlineToPreviewHtml(ex.description)}</td></tr>`;
    });
    html += `</tbody></table>`;
  }

  // See Also
  if (doc.seeAlso?.length) {
    html += `<h2>See Also</h2>`;
    html += `<ul>`;
    doc.seeAlso.forEach(sa => {
      html += `<li><span class="preview-see-ref">${esc(sa.cref)}</span> ${inlineToPreviewHtml(sa.description??'')}</li>`;
    });
    html += `</ul>`;
  }

  container.innerHTML = html || '<p style="color: var(--text-muted)">No documentation content.</p>';
}
