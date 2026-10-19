import ru from '../../resources/locales/ru.json';
import zh from '../../resources/locales/zh.json';
const packs:Record<string,Record<string,string>>={en:{},ru,zh};
let language='en';
let observer:MutationObserver|null=null;
const texts=new WeakMap<Text,{source:string;translated:string}>();
const attrs=new WeakMap<Element,Map<string,{source:string;translated:string}>>();
export function resolveLanguage(code:string):string {
 const base=(code==='auto'?(globalThis.navigator?.language??'en'):code).toLowerCase().replace('_','-').split('-')[0];
 return base in packs?base:'en';
}
export function translate(text:string):string {return packs[language][text]??text;}
const protectedContent=(e:Element)=>!!e.closest('.tiptap,[contenteditable],[data-code],[translate="no"],pre,code,#member-signature,#doc-preview,#tree-content,#template-choice,.td-name');
export function localizeUi():void {
 observer?.disconnect();
 const walker=document.createTreeWalker(document.body,5,{acceptNode(node){return node.nodeType===1 && protectedContent(node as Element)?2:node.nodeType===3?1:3;}});let node:Node|null;
 while((node=walker.nextNode())){
  const text=node as Text,parent=text.parentElement;if(!parent || protectedContent(parent) || !parent.closest('button,th,.doc-heading,summary,label,.tab,output,option,h4,h5'))continue;
  const saved=texts.get(text),value=text.data;const source=saved && value===saved.translated?saved.source:value;
  const trimmed=source.trim();if(parent.tagName==='OPTION' && !parent.hasAttribute('value'))parent.setAttribute('value',(parent as HTMLOptionElement).value);
  const result=source.replace(trimmed,translate(trimmed));if(result!==value)text.data=result;texts.set(text,{source,translated:result});
 }
 for(const e of document.body.querySelectorAll('[title],[aria-label],[placeholder]')){
  if(protectedContent(e))continue;let records=attrs.get(e);if(!records){records=new Map();attrs.set(e,records);}
  for(const name of ['title','aria-label','placeholder']){const value=e.getAttribute(name);if(value===null)continue;const saved=records.get(name),source=saved && value===saved.translated?saved.source:value,result=translate(source);if(value!==result)e.setAttribute(name,result);records.set(name,{source,translated:result});}
 }
 observer?.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['title','aria-label','placeholder']});
}
export function setLanguage(code:string):void {
 const previous=language;language=resolveLanguage(code);document.documentElement.lang=language;
 if(!observer)observer=new MutationObserver(records=>{if(records.some(r=>{const e=r.target.nodeType===1?r.target as Element:r.target.parentElement;return e && !protectedContent(e);}))localizeUi();});if(previous!==language || !document.body.dataset.localized){localizeUi();document.body.dataset.localized='true';}if(previous!==language)window.dispatchEvent(new CustomEvent('uiLanguageChanged'));
}
