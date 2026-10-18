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
