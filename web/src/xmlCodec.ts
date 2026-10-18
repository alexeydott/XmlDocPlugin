import { Node as TipTapNode } from '@tiptap/core';
export function escapeXml(text: string): string {
 return text.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
export const OpaqueXml = TipTapNode.create({
 name: 'opaqueXml', group: 'inline', inline: true, atom: true,
 addAttributes() { return { xml: { default: '' } }; },
 parseHTML() { return [{ tag: 'span[data-xml]', getAttrs: el => ({ xml: (el as HTMLElement).dataset.xml }) }]; },
 renderHTML({ node }) {
  const attrs={ 'data-xml':node.attrs.xml,class:'opaque-xml',title:node.attrs.xml,contenteditable:'false' };
  const doc=new DOMParser().parseFromString(node.attrs.xml,'application/xml');const e=doc.documentElement;
  if(['image','img'].includes(e.tagName)){
   const src=e.getAttribute('src')??'';const base=(window as any).xmlDocResourceBase;
   if(base && !/^(?:[a-z]+:|[\\/])|(?:^|[\\/])\.\.(?:[\\/]|$)/i.test(src)) return ['span',attrs,['img',{src:new URL(src.replace(/\\/g,'/'),base).href,alt:e.getAttribute('alt')??'',style:'max-width:100%'}]];
  }
  return ['span',attrs,'XML'];
 },
});
export const DocumentationTable=TipTapNode.create({name:'docTable',group:'block',content:'docTableRow+',parseHTML(){return [{tag:'table[data-doc-table]'}];},renderHTML(){return ['table',{'data-doc-table':''},['tbody',0]];}});
export const DocumentationTableRow=TipTapNode.create({name:'docTableRow',content:'docTableCell+',addAttributes(){return {header:{default:false}};},parseHTML(){return [{tag:'tr',getAttrs:el=>({header:(el as HTMLElement).dataset.header==='true'})}];},renderHTML({node}){return ['tr',{'data-header':String(node.attrs.header)},0];}});
export const DocumentationTableCell=TipTapNode.create({name:'docTableCell',content:'paragraph+',parseHTML(){return [{tag:'td'},{tag:'th'}];},renderHTML(){return ['td',0];}});
export function serializeNode(node: any): string {
 const paragraphs=()=>{let s='';node.forEach((child:any)=>{const xml=serializeNode(child);s+=node.childCount>1 && child.type.name==='paragraph'?`<para>${xml}</para>`:xml;});return s;};
 const content = () => { let s=''; node.forEach((child: any) => s+=serializeNode(child)); return s; };
 if (node.isText) {
   let text=escapeXml(node.text ?? '');
   for (const mark of node.marks ?? []) {
     switch(mark.type.name) {
       case 'bold': text=`<b>${text}</b>`; break;
       case 'italic': text=`<i>${text}</i>`; break;
       case 'codeInline': text=`<c>${text}</c>`; break;
       case 'seeRef': text=`<see cref="${escapeXml(mark.attrs.cref || node.text)}">${text}</see>`; break;
       case 'paramRef': text=`<paramref name="${escapeXml(mark.attrs.name)}"/>`; break;
       case 'typeParamRef': text=`<typeparamref name="${escapeXml(mark.attrs.name)}"/>`; break;
     }
   }
   return text;
 }
 switch(node.type.name) {
   case 'doc': { const parts:string[]=[];node.forEach((c:any)=>parts.push(serializeNode(c)));return parts.join('\n'); }
   case 'paragraph': return content();
   case 'docTable':return `<list type="table">${content()}</list>`;
   case 'docTableRow':{let cells='';node.forEach((cell:any,index:number)=>{const tag=index===0?'term':'description';cells+=`<${tag}>${serializeNode(cell)}</${tag}>`;});const tag=node.attrs.header?'listheader':'item';return `<${tag}>${cells}</${tag}>`;}
   case 'docTableCell':return paragraphs();
   case 'hardBreak': return '<br/>';
   case 'bulletList': return `<list type="bullet">${content()}</list>`;
   case 'orderedList': return `<list type="number">${content()}</list>`;
   case 'listItem': return `<item><description>${paragraphs()}</description></item>`;
   case 'codeBlock': return `<code>${escapeXml(node.textContent)}</code>`;
   case 'heading': return `<b>${content()}</b>`;
   case 'blockquote': return `<para>${content()}</para>`;
   case 'opaqueXml': return node.attrs.xml;
   default: return content();
 }
}
export function textToHtml(text:string):string {
 if (!text) return '';
 const xml=new DOMParser().parseFromString('<doc>'+text+'</doc>','application/xml');
 if (xml.querySelector('parsererror')) return '<p>'+escapeXml(text)+'</p>';
 const asBlocks=(html:string)=>/<(?:p|pre|table|ul|ol)\b/.test(html)?html:`<p>${html}</p>`;
 const opaque=(n:globalThis.Node)=>`<span data-xml="${escapeXml(new XMLSerializer().serializeToString(n))}">XML</span>`;
 const convert=(node:globalThis.Node):string=>{
   if(node.nodeType===3 || node.nodeType===4) return escapeXml(node.textContent ?? '').replace(/\r?\n/g,'<br>');
   if(node.nodeType!==1) return opaque(node);
   const e=node as Element;
   const supported:Record<string,string[]>={para:[],b:[],strong:[],i:[],em:[],br:[],c:[],code:[],see:['cref'],paramref:['name'],typeparamref:['name'],list:['type']};
   if(supported[e.tagName] && Array.from(e.attributes).some(a=>!supported[e.tagName].includes(a.name)))return opaque(node);
   const children=()=>Array.from(e.childNodes).map(convert).join('');
   switch(e.tagName){
    case 'para': return `<p>${children()}</p>`;
    case 'list':{
      const type=e.getAttribute('type');
      if(type==='table')return `<table data-doc-table><tbody>${Array.from(e.children).map(row=>`<tr data-header="${row.tagName==='listheader'}">${Array.from(row.children).map(cell=>`<td>${asBlocks(Array.from(cell.childNodes).map(convert).join(''))}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
      if(!e.querySelector('term') && ['bullet','number'].includes(type??'')) {const tag=type==='number'?'ol':'ul';return `<${tag}>${Array.from(e.children).map(row=>`<li>${asBlocks(Array.from(row.querySelector('description')?.childNodes??row.childNodes).map(convert).join(''))}</li>`).join('')}</${tag}>`;}
      return opaque(node);
    }
    case 'b': case 'strong': return `<strong>${children()}</strong>`;
    case 'i': case 'em': return `<em>${children()}</em>`;
    case 'br': return '<br>';
    case 'c': return `<code class="xml-c">${children()}</code>`;
    case 'code': return `<pre><code>${escapeXml(e.textContent ?? '')}</code></pre>`;
    case 'see': { const cref=e.getAttribute('cref')??'';return `<span class="see-ref" data-cref="${escapeXml(cref)}">${children()||escapeXml(cref)}</span>`; }
    case 'paramref': return `<span class="param-ref" data-param="${escapeXml(e.getAttribute('name')??'')}">${escapeXml(e.getAttribute('name')??'')}</span>`;
    case 'typeparamref': return `<span class="typeparam-ref" data-typeparam="${escapeXml(e.getAttribute('name')??'')}">${escapeXml(e.getAttribute('name')??'')}</span>`;
    default: return opaque(node);
   }
 };
 const html=Array.from(xml.documentElement.childNodes).map(convert).join('');
 return asBlocks(html);
}
