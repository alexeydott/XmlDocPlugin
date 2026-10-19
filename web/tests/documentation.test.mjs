import {JSDOM} from 'jsdom';const dom=new JSDOM();globalThis.DOMParser=dom.window.DOMParser;globalThis.XMLSerializer=dom.window.XMLSerializer;
import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';import {Schema} from '@tiptap/pm/model';
const {serializeNode}=load('xmlCodec.ts');const {synchronize,inheritDoc}=load('docTools.ts');
const schema=new Schema({nodes:{doc:{content:'block+'},paragraph:{group:'block',content:'inline*'},text:{group:'inline'},hardBreak:{group:'inline',inline:true},bulletList:{group:'block',content:'listItem+'},listItem:{content:'paragraph+'},opaqueXml:{group:'inline',inline:true,atom:true,attrs:{xml:{default:''}}}},marks:{bold:{},italic:{},seeRef:{attrs:{cref:{}}}}});
test('real ProseMirror content retains bold, italic, hard breaks, lists and opaque XML',()=>{
 const doc=schema.nodeFromJSON({type:'doc',content:[{type:'paragraph',content:[{type:'text',text:'a & b',marks:[{type:'bold'},{type:'italic'}]},{type:'hardBreak'},{type:'opaqueXml',attrs:{xml:'<unknown key="value"/>'}}]},{type:'bulletList',content:[{type:'listItem',content:[{type:'paragraph',content:[{type:'text',text:'item'}]}]}]}]});
 const xml=serializeNode(doc);assert.match(xml,/<i><b>a &amp; b<\/b><\/i>/);assert.match(xml,/<br\/>/);assert.match(xml,/<list type="bullet">/);assert.match(xml,/<unknown key="value"\/>/);
});
test('synchronization does not infer a rename by position and preserves orphan descriptions',()=>{
 const e={kind:'method',params:[{name:'NewName'},{name:'Extra'}],returnType:'Boolean'};
 const old={summary:'See <paramref name="OldName"/>',params:[{name:'OldName',description:'Keep'}]};
 const plain=synchronize(e,old);assert.equal(plain.params[0].description,'');assert.equal(plain.params[2].name,'OldName');
 const mapped=synchronize(e,old,{OldName:'NewName'});assert.equal(mapped.params[0].description,'Keep');assert.match(mapped.summary,/name="NewName"/);assert.equal(old.params[0].name,'OldName');
 assert.throws(()=>synchronize(e,old,{OldName:'Missing'}));
});
test('inheritance overlays individual local sections and parameters',()=>{
 const local={summary:'',remarks:'Local remarks',params:[{name:'Value',description:''}]};
 const merged=inheritDoc(local,{summary:'Base',remarks:'Base remarks',params:[{name:'Value',description:'Base input'}]});
 assert.equal(merged.summary,'Base');assert.equal(merged.remarks,'Local remarks');assert.equal(merged.params[0].description,'Base input');assert.equal(local.summary,'');
});
test('seeded rich text fuzz keeps text and all unsupported XML atoms',()=>{
 let seed=0x17abc;
 for(let i=0;i<3000;i++){
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;const text='Unicode Пример '+seed+' < & >';const atom='<x value="'+seed+'"/>';
  const doc=schema.node('doc',null,[schema.node('paragraph',null,[schema.text(text,[schema.mark(seed%2?'bold':'italic')]),schema.node('hardBreak'),schema.node('opaqueXml',{xml:atom})])]);
  const xml=serializeNode(doc);assert.ok(xml.includes(atom),'seed '+seed);assert.ok(xml.includes('&lt; &amp; &gt;'));assert.ok(xml.includes('Пример'));
 }
});

test('constructed generic inheritance matches full types and parameter modifiers',()=>{
 const {genericArguments,compatibleInheritedMember}=load('docTools.ts');
 assert.deepEqual(genericArguments('IBase<TPair<string,Integer>,TArray<Boolean>>'),['TPair<string,Integer>','TArray<Boolean>']);
 const target={kind:'method',name:'Run',params:[{name:'Value',type:'TArray<Integer>',isConst:true}]};
 const source={kind:'method',name:'Run',params:[{name:'Source',type:'T',isConst:true}]};
 assert.equal(compatibleInheritedMember(target,source,{genericParams:['T']},'IBase<TArray<Integer>>'),true);
 assert.equal(compatibleInheritedMember(target,{...source,params:[{name:'Source',type:'T'}]},{genericParams:['T']},'IBase<TArray<Integer>>'),false);
});

test('wording defaults to all names and respects type and literal name patterns',()=>{
 const {wordingMatches}=load('docTools.ts');
 assert.equal(wordingMatches('Value','Integer'),true);assert.equal(wordingMatches('Value','Integer','','string'),false);
 assert.equal(wordingMatches('StartIndex','Integer','*Index','INTEGER'),true);
 assert.equal(wordingMatches('Value','Integer','Other'),false);assert.equal(wordingMatches('A+B','Integer','A+B'),true);
});

test('recovered XML drafts take precedence over the original source, including empty XML',()=>{
 const {editableXml}=load('docTools.ts');
 assert.equal(editableXml({summary:'Original',sourceXml:'<summary>Original</summary>',xmlEdited:true,rawXml:'<summary>unfinished'}),'<summary>unfinished');
 assert.equal(editableXml({summary:'Original',sourceXml:'<summary>Original</summary>',xmlEdited:true,rawXml:''}),'');
 assert.equal(editableXml({summary:'Original',sourceXml:'<summary custom="keep">Original</summary>'}),'<summary custom="keep">Original</summary>');
});

test('XML mode reflects unsaved design fields while retaining source attributes',()=>{
 const {editableXml}=load('docTools.ts');
 assert.equal(editableXml({summary:'New text',sourceXml:'<summary custom="keep">Original text</summary>'}),'<summary custom="keep">New text</summary>');
});

test('clearing optional fields and last collection entries is an explicit deletion',()=>{
 const {mergeRenderedDoc}=load('docTools.ts');
 for(const key of ['remarks','returns','value','examples','exceptions','seeAlso','params','typeParams']){
  const value=['remarks','returns','value'].includes(key)?'old':[{description:'old'}];const original={summary:'Keep',[key]:value};
  const result=mergeRenderedDoc(original,original,{summary:'Keep'});
  assert.deepEqual(result[key],typeof value==='string'?'':[]);assert.deepEqual(original[key],value);
 }
});

test('rename collision is rejected without losing descriptions and plain synchronization keeps duplicates',()=>{
 const element={kind:'method',params:[{name:'Current'}]};
 const old={summary:'Keep',params:[{name:'Old',description:'old text'},{name:'Current',description:'current text'}]};
 assert.throws(()=>synchronize(element,old,{Old:'Current'}),/conflicts/);assert.equal(old.params.length,2);
 const duplicated={summary:'Keep',params:[{name:'Current',description:'first'},{name:'Current',description:'second'}]};
 assert.deepEqual(synchronize(element,duplicated).params,duplicated.params);
});
test('list items serialize distinct paragraphs without joining words',()=>{
 const doc=schema.node('doc',null,[schema.node('bulletList',null,[schema.node('listItem',null,[schema.node('paragraph',null,[schema.text('First')]),schema.node('paragraph',null,[schema.text('Second')])])])]);
 assert.match(serializeNode(doc),/<para>First<\/para><para>Second<\/para>/);
});

test('nested XML attributes survive prose edits and table cells keep paragraphs',()=>{
 const {modelXml}=load('docTools.ts');const {textToHtml}=load('xmlCodec.ts');
 const xml=modelXml({summary:'<b>After</b>',sourceXml:'<summary><b custom="keep">Before</b></summary>'});assert.match(xml,/custom="keep"/);
 const html=textToHtml('<list type="table"><item><term>A</term><description><para>First</para><para>Second</para></description></item></list>');
 assert.match(html,/<td><p>First<\/p><p>Second<\/p><\/td>/);assert.ok(!html.startsWith('<p><table'));
 assert.match(textToHtml('<code language="pascal">Code;</code>'),/data-xml=/);
});

test('generic substitutions use original tokens rather than cascading mapped arguments',()=>{
 const {compatibleInheritedMember}=load('docTools.ts');
 assert.equal(compatibleInheritedMember({kind:'method',name:'Run',params:[{name:'V',type:'U'}],returnType:'U'}, {kind:'method',name:'Run',params:[{name:'V',type:'T'}],returnType:'T'}, {genericParams:['T','U']},'TBase<U,Integer>'),true);
 assert.equal(compatibleInheritedMember({kind:'method',name:'Run',params:[],returnType:'U'}, {kind:'method',name:'Run',params:[],returnType:'Тип'}, {genericParams:['Тип','U']},'TBase<U,Integer>'),true);
});

test('public API comparison excludes private members, hidden containing types and implementations',()=>{
 const {isPublicApi}=load('docTools.ts');const outer={kind:'class',name:'Outer',fileName:'A.pas',params:[],visibility:'private',genericParams:['T']};const inner={kind:'class',name:'Inner',qualifiedParent:'Outer<T>',fileName:'A.pas',params:[],visibility:'public'};const method={kind:'method',name:'Run',qualifiedParent:'Outer<T>.Inner',fileName:'A.pas',params:[],visibility:'public'};
 assert.equal(isPublicApi(method,[outer,inner,method]),false);assert.equal(isPublicApi({...method,qualifiedParent:undefined,visibility:'private'},[]),false);assert.equal(isPublicApi({...method,qualifiedParent:undefined,locationId:'run@implementation'},[]),false);assert.equal(isPublicApi({...method,qualifiedParent:undefined},[]),true);
});


test('a visible Design edit serializes Design rather than hidden restored raw XML',()=>{
 const {mergeRenderedDoc,modelXml}=load('docTools.ts');
 const original={summary:'Old design',rawXml:'<summary>UNAPPLIED RAW</summary>',xmlEdited:true};
 const next=mergeRenderedDoc(original,{summary:'Old design'},{summary:'NEW DESIGN TEXT'});
 assert.equal(modelXml(next),'<summary>NEW DESIGN TEXT</summary>');
 assert.equal(original.xmlEdited,true);
});

 test('Design Undo back to baseline cannot reauthorize an unapplied raw draft',()=>{
 const {mergeRenderedDoc,modelXml}=load('docTools.ts');
 const original={summary:'Original Design',sourceXml:'<summary>Original Design</summary>',rawXml:'<summary>UNAPPLIED RAW</summary>',xmlEdited:true};
 const baseline={summary:'Original Design'};
 const changed=mergeRenderedDoc(original,baseline,{summary:'NEW DESIGN TEXT'});
 const undone=mergeRenderedDoc(original,baseline,baseline);
 assert.equal(modelXml(changed),'<summary>NEW DESIGN TEXT</summary>');assert.equal(modelXml(undone),original.sourceXml);
 assert.equal(undone.xmlEdited,undefined);assert.equal(undone.rawXml,undefined);assert.equal(original.rawXml,'<summary>UNAPPLIED RAW</summary>');
 });
