import type { DocModel, ElementInfo, TreeElementInfo } from './types';
import { escapeXml } from './xmlCodec';
export interface Issue { code:string; message:string; fix:string; line:number; column:number; }
const clone=<T>(v:T):T=>JSON.parse(JSON.stringify(v));
const same=(a:string,b:string)=>a.toLocaleLowerCase()===b.toLocaleLowerCase();
export function synchronize(element:ElementInfo,doc:DocModel,renames:Record<string,string>={}):DocModel {
 const result=clone(doc);const names=[...(element.params??[]).map(p=>p.name),...(element.genericParams??[])];
 const targets=new Set<string>();
 const mappings=new Map<string,string>();
 for(const [old,name] of Object.entries(renames)){
  if(!names.some(n=>same(n,name)) || targets.has(name.toLowerCase()) || mappings.has(old.toLowerCase()))throw Error('Invalid or ambiguous rename mapping');
  targets.add(name.toLowerCase());mappings.set(old.toLowerCase(),name);
 }
 for(const key of ['params','typeParams'] as const)for(const p of result[key]??[])p.name=mappings.get(p.name.toLowerCase())??p.name;
 const replace=(text:string)=>text.replace(/<(paramref|typeparamref)\b([^>]*?)name=["']([^"']+)["']/g,(all,tag,attrs,n)=>mappings.has(n.toLowerCase())?`<${tag}${attrs}name="${escapeXml(mappings.get(n.toLowerCase())!)}"`:all);
 for(const key of ['summary','remarks','returns','value'] as const)if(result[key])result[key]=replace(result[key]!);
 for(const key of ['params','typeParams','exceptions','examples','seeAlso'] as const)for(const entry of result[key]??[])if(entry.description)entry.description=replace(entry.description);
 if(mappings.size)result.renameMappings={...result.renameMappings,...renames};
 const order=(expected:string[],old:{name:string;description:string}[])=>[
  ...expected.map(name=>old.find(p=>same(p.name,name))??{name,description:''}),
  ...old.filter(p=>!expected.some(n=>same(n,p.name)))];
 result.params=order((element.params??[]).map(p=>p.name),result.params??[]);
 result.typeParams=order(element.genericParams??[],result.typeParams??[]);
 if(element.kind==='method' && element.returnType && !result.returns)result.returns='TODO: Describe the result.';
 if(element.kind==='property' && !result.value)result.value='TODO: Describe the property value.';
 return result;
}
export function modelXml(doc:DocModel):string {
 if(doc.xmlEdited)return doc.rawXml??'';
 const fragments:string[]=[];
 for(const key of ['summary','remarks'] as const)if(doc[key])fragments.push(`<${key}>${doc[key]}</${key}>`);
 for(const [key,tag,attr] of [['params','param','name'],['typeParams','typeparam','name'],['exceptions','exception','cref'],['seeAlso','seealso','cref']] as const){
  for(const p of doc[key]??[]) {const name='name' in p?p.name:'typeRef' in p?p.typeRef:p.cref;fragments.push(`<${tag} ${attr}="${escapeXml(name)}">${p.description??''}</${tag}>`);}
 }
 for(const key of ['returns','value'] as const)if(doc[key])fragments.push(`<${key}>${doc[key]}</${key}>`);
 for(const ex of doc.examples??[])fragments.push(`<example${ex.title?` title="${escapeXml(ex.title)}"`:''}${ex.source?` source="${escapeXml(ex.source)}"`:''}${ex.region?` region="${escapeXml(ex.region)}"`:''}>${ex.description}${ex.code?`<code>${escapeXml(ex.code)}</code>`:''}</example>`);
 if(doc.sourceXml){
  const d=parseXml(doc.sourceXml);if(!d.querySelector('parsererror')){
   const known=['summary','remarks','param','typeparam','exception','seealso','returns','value','example'];
   for(const node of Array.from(d.documentElement.childNodes))if(node.nodeType!==1 || !known.includes((node as Element).tagName))fragments.push(new XMLSerializer().serializeToString(node));
  }
 }
 const generated=fragments.join('\n');
 if(!doc.sourceXml)return generated;
 const old=parseXml(doc.sourceXml),fresh=parseXml(generated);if(old.querySelector('parsererror') || fresh.querySelector('parsererror'))return generated;
 const counts=new Map<string,number>();
 for(const node of Array.from(fresh.documentElement.children)){
  const key=node.tagName+'|'+(node.getAttribute('name')??node.getAttribute('cref')??'');const ordinal=counts.get(key)??0;counts.set(key,ordinal+1);
  const matches=Array.from(old.documentElement.children).filter(n=>{
   if(n.tagName!==node.tagName)return false;const name=n.getAttribute('name');const mapped=name?(doc.renameMappings?.[name]??name):n.getAttribute('cref')??'';
   return mapped===(node.getAttribute('name')??node.getAttribute('cref')??'');
  });const source=matches[ordinal];if(!source)continue;
  for(const attribute of Array.from(source.attributes))if(!node.hasAttribute(attribute.name))node.setAttribute(attribute.name,attribute.value);
 }
 return Array.from(fresh.documentElement.childNodes).map(n=>new XMLSerializer().serializeToString(n)).join('');
}
export function parseXml(xml:string):Document { return new DOMParser().parseFromString('<doc>'+xml+'</doc>','application/xml'); }
export function analyze(element:ElementInfo,doc:DocModel,catalog:TreeElementInfo[]=[]):Issue[]{
 const issues:Issue[]=[];const xml=modelXml(doc);const d=parseXml(xml);
 const add=(code:string,message:string,fix:string,token='')=>{
  const offset=token?Math.max(0,xml.indexOf(token)):0;const prefix=xml.slice(0,offset).split('\n');
  issues.push({code,message,fix,line:Math.max(1,element.commentStartLine??element.lineNumber??1)+prefix.length-1,column:prefix[prefix.length-1].length+1});
 };
 if(d.querySelector('parsererror') || doc.parseError){add('XD001',doc.parseError??'Invalid XML','XML');return issues;}
 for(const [tag,names] of [['param',(element.params??[]).map(p=>p.name)],['typeparam',element.genericParams??[]]] as const){
  const nodes=Array.from(d.querySelectorAll(`doc > ${tag}`));
  const seen=new Set<string>();
  for(const node of nodes){const name=node.getAttribute('name')??'';if(!names.some(n=>same(n,name)))add('XD002',`Unknown ${tag} ${name}`,'Map name',`<${tag}`);if(seen.has(name.toLowerCase()))add('XD003',`Duplicate ${tag} ${name}`,'XML');seen.add(name.toLowerCase());}
  for(const name of names)if(!seen.has(name.toLowerCase()))add('XD004',`Missing ${tag} ${name}`,'Synchronize');
 }
 for(const node of Array.from(d.querySelectorAll('paramref,typeparamref'))){const name=node.getAttribute('name')??'';const names=node.tagName==='paramref'?(element.params??[]).map(p=>p.name):element.genericParams??[];if(!names.some(n=>same(n,name)))add('XD005',`Unknown ${node.tagName} ${name}`,'Map name',`<${node.tagName}`);}
 for(const node of Array.from(d.querySelectorAll('[cref]'))){
  const ref=node.getAttribute('cref')!;if(!catalog.length)continue;
  const matches=new Set(catalog.filter(e=>[e.symbolId,e.fullName,e.canonicalName,e.name].some(n=>same(n??'',ref)) || (e.fullName??'').toLowerCase().endsWith('.'+ref.toLowerCase())).map(e=>e.symbolId??e.fullName));
  if(matches.size===0)add('XD006',`Unknown reference ${ref}`,'Choose reference','cref=');
  if(matches.size>1)add('XD007',`Ambiguous reference ${ref}`,'Choose reference','cref=');
 }
 if(!doc.summary?.trim())add('XD000','Missing summary description','Edit');
 if(/\bTODO\b/i.test(xml))add('XD008','Unfinished TODO documentation','Edit');
 if(doc.returns && (element.kind!=='method' || !element.returnType))add('XD009','Returns is not valid for this declaration','XML');
 if(doc.value && element.kind!=='property')add('XD009','Value is only valid for a property','XML');
 if(element.kind==='unit' && doc.exceptions?.length)add('XD009','Exceptions are not valid for a unit','XML');
 if(element.kind==='method' && element.returnType && !doc.returns)add('XD010','Missing result description','Synchronize');
 if(element.kind==='property' && !doc.value)add('XD010','Missing property value description','Synchronize');
 return issues;
}
export function inheritDoc(local:DocModel,source:DocModel):DocModel {
 const result=clone(local);
 for(const key of ['summary','remarks','returns','value'] as const)if(!result[key] && source[key])result[key]=source[key]!;
 for(const key of ['params','typeParams'] as const){
  result[key]=[...(result[key]??[])];for(const entry of source[key]??[]){const item=result[key]!.find(p=>same(p.name,entry.name));if(!item)result[key]!.push(clone(entry));else if(!item.description)item.description=entry.description;}
 }
 for(const key of ['exceptions','examples','seeAlso'] as const)if(!result[key]?.length)(result as any)[key]=clone(source[key]??[]);
 return result;
}
export function ready(element:ElementInfo,doc:DocModel,catalog:TreeElementInfo[]=[]):boolean { return !!doc.summary?.trim() && analyze(element,doc,catalog).length===0; }
export function issueKey(element:ElementInfo,issue:Issue):string {return JSON.stringify([element.symbolId??element.fullName,issue.code,issue.code==='XD001'?'Invalid XML':issue.message]);}

/** Replace prose text nodes only. XML names, references and example code remain intact. */
export function replaceProse(doc:DocModel,find:string,replacement:string):DocModel {
 const result=clone(doc);if(!find)return result;
 const change=(xml:string)=>{const root=parseXml(xml);if(root.querySelector('parsererror'))throw Error('Repair XML before replacing text');
  const walk=(node:Node)=>{if(node.nodeType===1 && ['code','c','see','paramref','typeparamref','image','img'].includes((node as Element).tagName))return;
   if(node.nodeType===3 || node.nodeType===4)node.textContent=(node.textContent??'').split(find).join(replacement);else Array.from(node.childNodes).forEach(walk);
  };walk(root.documentElement);return Array.from(root.documentElement.childNodes).map(n=>new XMLSerializer().serializeToString(n)).join('');};
 for(const key of ['summary','remarks','returns','value'] as const)if(result[key])result[key]=change(result[key]!);
 for(const key of ['params','typeParams','exceptions','examples','seeAlso'] as const)for(const entry of result[key]??[])if(entry.description)entry.description=change(entry.description);
 return result;
}

export function genericArguments(name:string):string[]{
 const start=name.indexOf('<');if(start<0)return [];let depth=0,part='';const args:string[]=[];
 for(const c of name.slice(start+1)){if(c==='>' && depth===0){args.push(part.trim());return args;}if(c===',' && depth===0){args.push(part.trim());part='';continue;}if('<(['.includes(c))depth++;if('>)]'.includes(c))depth--;part+=c;}return [];
}
export function compatibleInheritedMember(target:ElementInfo,source:ElementInfo,parent:ElementInfo,ancestor:string):boolean {
 if(target.name.toLowerCase()!==source.name.toLowerCase() || target.kind!==source.kind || target.params.length!==source.params.length)return false;
 const args=genericArguments(ancestor);const substitute=(type:string)=>{
  let result=type;for(let i=0;i<(parent.genericParams?.length??0);i++)if(args[i]){const name=parent.genericParams![i].replace(/[.*+?^${}()|[\]\\]/g,'\\$&');result=result.replace(new RegExp('\\b'+name+'\\b','g'),args[i]);}return result.toLowerCase().replace(/\s+/g,'');
 };
 return target.params.every((p,i)=>p.type.toLowerCase().replace(/\s+/g,'')===substitute(source.params[i].type) && !!p.isVar===!!source.params[i].isVar && !!p.isOut===!!source.params[i].isOut && !!p.isConst===!!source.params[i].isConst);
}

export function wordingMatches(name:string,type:string,namePattern='',typePattern=''):boolean {
 const pattern=(namePattern||'*').replace(/[.+?^${}()|[\]\\]/g,'\\$&').replace(/\*/g,'.*');
 return new RegExp('^'+pattern+'$','i').test(name) && (!typePattern || type.toLowerCase()===typePattern.toLowerCase());
}

export function editableXml(doc:DocModel):string {
 return doc.xmlEdited?(doc.rawXml??''):(doc.sourceXml||modelXml(doc));
}
