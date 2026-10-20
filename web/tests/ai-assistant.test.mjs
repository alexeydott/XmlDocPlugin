import {JSDOM} from 'jsdom';import {readFileSync} from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
function setup(){
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});for(const k of ['window','document','DOMParser','XMLSerializer','HTMLElement','Element','Node','Event','MutationObserver','CustomEvent','getComputedStyle'])globalThis[k]=k==='getComputedStyle'?dom.window.getComputedStyle.bind(dom.window):dom.window[k];Object.defineProperty(globalThis,'navigator',{value:dom.window.navigator,configurable:true});globalThis.ResizeObserver=class{observe(){}disconnect(){}};window.matchMedia=()=>({matches:false,addEventListener(){},removeEventListener(){}});const sent=[];window.chrome={webview:{postMessage:s=>sent.push(JSON.parse(s))}};load('editor.ts').init();const bridge=window.bridge;
 const element={kind:'method',name:'Run',symbolId:'run',locationId:'run@interface',fileName:'Case.pas',sessionId:'session',sourceRevision:'r1',params:[],genericParams:[],lineNumber:5};bridge.receive({type:'loadDoc',data:{element,doc:{summary:'Original',remarks:'Keep remarks'}}});window.xmlDocAI.receive({state:'configuration',profiles:[{id:'p',name:'Profile'}],templates:[{id:'describe',name:'Describe method from code',operation:'describe'},{id:'rephrase',name:'Rephrase summary',operation:'rephrase'}]});
 const click=id=>document.getElementById(id).click();const prepare=()=>{click('ai-describe');return sent.filter(m=>m.type==='aiPrepare').at(-1);};const reply=(request,state,extra={})=>window.xmlDocAI.receive({state,requestId:request.requestId,...extra});
 return {dom,sent,bridge,element,click,prepare,reply,close:()=>{bridge.cancelPending();dom.window.close();}};
}
test('AI suggestions never write before reviewed Apply, allow manual editing and preserve other sections',()=>{
 const s=setup(),req=s.prepare();assert.ok(req);assert.equal(req.summary,'Original');s.reply(req,'prepared',{url:'http://localhost/v1/chat/completions',request:'{"model":"fake"}',fragments:[]});s.click('ai-send');assert.equal(s.sent.at(-1).type,'aiSend');
 s.reply(req,'proposal',{fresh:true,summary:'Proposed',uncertainties:['Ownership is unknown.']});assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);assert.match(document.querySelector('#ai-uncertainties').textContent,/Ownership/);
 const edit=document.querySelector('#ai-summary');edit.value='Manually reviewed';edit.dispatchEvent(new Event('input'));s.click('ai-apply');assert.equal(s.sent.at(-1).type,'aiApply');assert.equal(s.sent.at(-1).summary,'Manually reviewed');assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);
 s.reply(req,'approved',{summaryXml:'Manually reviewed'});s.bridge.flush();const message=s.sent.filter(m=>m.type==='docUpdated').at(-1);assert.equal(message.doc.summary,'Manually reviewed');assert.equal(message.doc.remarks,'Keep remarks');s.close();
});
test('late AI responses, local edits, XML drafts and language switching keep target and local content safe',()=>{
 const s=setup();let request=s.prepare();s.bridge.receive({type:'loadDoc',data:{element:{...s.element,name:'Other',symbolId:'other',locationId:'other@interface'},doc:{summary:'B'}}});s.reply(request,'proposal',{fresh:true,summary:'Late A',uncertainties:[]});assert.equal(document.querySelector('#ai-apply').disabled,true);s.click('ai-apply');assert.equal(s.sent.filter(m=>m.type==='aiApply').length,0);
 s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original'}}});request=s.prepare();document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('Local edit').run();s.reply(request,'proposal',{fresh:true,summary:'Old proposal',uncertainties:[]});assert.equal(document.querySelector('#ai-apply').disabled,true);
 s.click('open-xml');const xml=document.querySelector('#xml-source');xml.value='<summary>Unapproved XML</summary>';xml.dispatchEvent(new Event('input'));const count=s.sent.filter(m=>m.type==='aiPrepare').length;s.click('ai-describe');assert.equal(s.sent.filter(m=>m.type==='aiPrepare').length,count);
 for(const language of ['ru','zh','ko','ja','en']){window.xmlDocSettings.apply({language,fontSize:13,showSignatureHeader:true,theme:'light'});assert.equal(xml.value,'<summary>Unapproved XML</summary>');assert.equal(document.querySelector('#ai-summary').value,'Old proposal');}
 assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);s.close();
});
test('AI cancellation and malformed XML tokens cannot authorize a write',()=>{
 const s=setup(),req=s.prepare();s.reply(req,'prepared',{url:'http://localhost',request:'{}',fragments:[{token:'__XMLDOC_test_0__',xml:'<see cref="Summary"/>'}]});s.reply(req,'proposal',{fresh:true,summary:'Lost token',uncertainties:[]});assert.equal(document.querySelector('#ai-apply').disabled,true);
 s.click('ai-cancel');s.reply(req,'approved',{summaryXml:'Forbidden'});assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);s.close();
});

test('AI operation and template selectors have distinct hints and hide a redundant built-in template',()=>{
 const s=setup();const template=document.getElementById('ai-template'),operation=document.getElementById('ai-operation');
 assert.equal(template.hidden,true);assert.notEqual(template.title,operation.title);
 window.xmlDocAI.receive({state:'configuration',profiles:[{id:'p',name:'Profile'}],templates:[{id:'describe',name:'Describe method from code',operation:'describe'},{id:'custom',name:'Detailed review',operation:'describe'},{id:'rephrase',name:'Rephrase summary',operation:'rephrase'}]});
 assert.equal(template.hidden,false);template.value='custom';let req=s.prepare();assert.equal(req.templateId,'custom');
 operation.value='rephrase';operation.dispatchEvent(new Event('change'));assert.equal(template.hidden,true);assert.equal(template.value,'rephrase');
 operation.value='describe';operation.dispatchEvent(new Event('change'));assert.equal(template.hidden,false);assert.equal(template.value,'describe');
 for(const language of ['ru','zh','ko','ja']){window.xmlDocSettings.apply({language,fontSize:13,theme:'dark'});assert.notEqual(template.title,'Prompt template');assert.notEqual(operation.title,'AI operation');assert.equal(template.options[1].textContent,'Detailed review');}
 s.close();
});

test('AI preview is off by default, automatic sending waits visibly and cancellation or errors end the wait',()=>{
 const s=setup();let req=s.prepare();assert.equal(document.querySelector('#ai-wait').hidden,false);
 s.reply(req,'prepared',{previewRequired:false,fragments:[]});assert.equal(s.sent.at(-1).type,'aiSend');assert.equal(document.querySelector('#ai-request-preview').hidden,true);assert.equal(document.querySelector('#ai-wait').hidden,false);
 s.reply(req,'error',{message:'AI HTTP error 429'});assert.equal(document.querySelector('#ai-wait').hidden,true);assert.equal(document.querySelector('#ai-describe').disabled,false);
 req=s.prepare();s.reply(req,'prepared',{previewRequired:false,fragments:[]});s.click('ai-cancel');assert.equal(document.querySelector('#ai-wait').hidden,true);
 window.xmlDocAI.receive({state:'configuration',previewRequests:true,profiles:[{id:'p',name:'Profile'}],templates:[{id:'describe',name:'Describe method from code',operation:'describe'}]});req=s.prepare();const count=s.sent.filter(m=>m.type==='aiSend').length;s.reply(req,'prepared',{previewRequired:true,url:'https://example.test/v1/chat/completions',request:'{}',fragments:[]});assert.equal(s.sent.filter(m=>m.type==='aiSend').length,count);assert.equal(document.querySelector('#ai-request-preview').hidden,false);assert.equal(document.querySelector('#ai-wait').hidden,true);s.click('ai-send');assert.equal(document.querySelector('#ai-wait').hidden,false);s.close();
});
test('AI parameter proposals fill missing prose after review and preserve existing parameter XML',()=>{
 const s=setup();s.element.params=[{name:'Value',typeName:'string'},{name:'Existing',typeName:'string'}];s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',params:[{name:'Value',description:''},{name:'Existing',description:'<see cref="Keep"/>'}]}}});
 const req=s.prepare();s.reply(req,'prepared',{url:'https://example.test',request:'{}',fragments:[]});s.reply(req,'proposal',{fresh:true,summary:'New summary',parameters:[{name:'Value',description:'Input value'},{name:'Existing',description:'Do not overwrite'}],uncertainties:[]});
 const fields=document.querySelectorAll('#ai-parameters textarea');assert.equal(fields.length,1);fields[0].value='Reviewed <value>';fields[0].dispatchEvent(new Event('input'));s.click('ai-apply');assert.deepEqual(s.sent.at(-1).parameters,[{name:'Value',description:'Reviewed <value>'}]);s.reply(req,'approved',{summaryXml:'New summary',parameters:[{name:'Value',description:'Reviewed &lt;value&gt;'}]});s.bridge.flush();const updated=s.sent.filter(m=>m.type==='docUpdated').at(-1);assert.equal(updated.doc.params[0].description,'Reviewed &lt;value&gt;');assert.equal(updated.doc.params[1].description,'<see cref="Keep"/>');s.close();
});
test('AI icons identify settings, code description and rewriting independently of Format',()=>{
 const s=setup();const buttons=['ai-settings','ai-describe','ai-rephrase','ai-review'].map(id=>document.getElementById(id));
 for(const button of buttons){assert.equal(button.dataset.workbenchIcon,button.id);assert.ok(button.querySelector('svg'));assert.ok(button.title);assert.equal(button.title,button.getAttribute('aria-label'));}
 assert.equal(new Set(buttons.map(b=>b.innerHTML)).size,4);assert.notEqual(buttons[1].innerHTML,document.getElementById('format-document').innerHTML);
 for(const language of ['ru','zh','ko','ja']){window.xmlDocSettings.apply({language,fontSize:13,theme:'dark'});for(const button of buttons){assert.notEqual(button.title,{'ai-settings':'AI profiles and prompts','ai-describe':'Describe method from code','ai-rephrase':'Rephrase summary','ai-review':'Review documentation against code'}[button.id]);}}
 s.close();
});
test('AI proposals replace placeholder parameters and preview XML paragraphs without overwriting completed prose',()=>{
 const s=setup();s.element.params=[{name:'Value',typeName:'string'},{name:'Existing',typeName:'string'}];s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',params:[{name:'Value',description:'TODO: Value description'},{name:'Existing',description:'Keep this description.'}]}}});
 const req=s.prepare();s.reply(req,'prepared',{url:'https://example.test',request:'{}',fragments:[]});s.reply(req,'proposal',{fresh:true,summary:'First paragraph.\n\nSecond paragraph.',parameters:[{name:'Value',description:'Input value'},{name:'Existing',description:'Do not overwrite'}],uncertainties:[]});
 assert.equal(document.querySelectorAll('#ai-parameters textarea').length,1);assert.ok(document.getElementById('ai-after').textContent.includes('<para>First paragraph.</para>'));assert.ok(document.getElementById('ai-after').textContent.includes('Input value'));
 s.click('ai-apply');assert.deepEqual(s.sent.at(-1).parameters,[{name:'Value',description:'Input value'}]);s.reply(req,'approved',{summaryXml:'<para>First paragraph.</para><para>Second paragraph.</para>',parameters:[{name:'Value',description:'Input value'}]});s.bridge.flush();const updated=s.sent.filter(m=>m.type==='docUpdated').at(-1);assert.equal(updated.doc.params[0].description,'Input value');assert.equal(updated.doc.params[1].description,'Keep this description.');s.close();
});
test('AI parameter names follow Delphi case-insensitive identity',()=>{
 for(const description of ['Existing description.','TODO: describe value']){
 const s=setup();s.bridge.receive({type:'loadDoc',data:{element:{...s.element,params:[{name:'Value',typeName:'Integer'}]},doc:{summary:'Original',params:[{name:'value',description}]}}});
 const req=s.prepare();s.reply(req,'prepared',{fragments:[],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'New summary',parameters:[{name:'Value',description:'New parameter description.'}],uncertainties:[]});
 assert.equal(document.querySelector('#ai-apply').disabled,false);
 const after=document.querySelector('#ai-after').textContent;assert.equal((after.match(/<param /g)??[]).length,1);assert.ok(after.includes(description.startsWith('TODO:')?'New parameter description.':'Existing description.'));s.close();
 }
});
test('protected XML replacement preserves literal dollar substitution sequences',()=>{
 const s=setup(),req=s.prepare();s.reply(req,'prepared',{fragments:[{token:'__XMLDOC_x_0__',xml:'<c>$&amp;</c>'}],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'Use __XMLDOC_x_0__',uncertainties:[]});
 assert.match(document.querySelector('#ai-after').textContent,/<c>\$&amp;<\/c>/);assert.equal(document.querySelector('#ai-apply').disabled,false);s.close();
});
test('AI validation explanation is retained after receiving an invalid proposal',()=>{
 const s=setup(),req=s.prepare();s.reply(req,'prepared',{fragments:[{token:'__XMLDOC_x_0__',xml:'<c>code</c>'}],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'Missing token',uncertainties:[]});
 assert.equal(document.querySelector('#ai-apply').disabled,true);assert.match(document.querySelector('#ai-status').textContent,/lost or duplicated/);s.close();
});
test('copy missing inherited sections uses the current local summary',()=>{
 const s=setup();const child={...s.element,qualifiedParent:'TChild',unitName:'Case',signature:'procedure Run;'};
 s.bridge.receive({type:'loadDoc',data:{element:child,doc:{summary:'Original summary'}}});
 const parent={kind:'class',name:'TBase',fileName:'Case.pas',unitName:'Case',params:[],genericParams:[],doc:{}};
 window.xmlDocWorkbench.receiveCatalog({elements:[parent,{...parent,name:'TChild',ancestor:'TBase'},{...child,qualifiedParent:'TBase',symbolId:'baseRun',doc:{summary:'Parent summary',remarks:'Inherited remarks'}}]});
 const copy=document.querySelector('#inheritance-sources button');assert.ok(copy);
 // A local change replaces the document object before the host rebuilds the catalog.
 document.querySelector('#summary-editor .tiptap').editor.chain().selectAll().insertContent('New local summary').run();
 copy.click();assert.match(document.querySelector('#xml-after').textContent,/New local summary/);assert.match(document.querySelector('#xml-after').textContent,/Inherited remarks/);s.click('apply-operation');s.bridge.flush();const updated=s.sent.filter(m=>m.type==='docUpdated').at(-1);assert.equal(updated.doc.summary,'New local summary');assert.equal(updated.doc.remarks,'Inherited remarks');s.close();
});

test('AI sections are accepted independently and unselected invalid summary tokens do not block parameters',()=>{
 const s=setup();s.element.params=[{name:'A',type:'Integer'},{name:'B',type:'Integer'}];
 s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',remarks:'Keep remarks',params:[{name:'A',description:''},{name:'B',description:''}]}}});
 const req=s.prepare();s.reply(req,'prepared',{fragments:[{token:'__XMLDOC_x_0__',xml:'<c>Keep</c>'}],previewRequired:true});
 s.reply(req,'proposal',{fresh:true,summary:'Keep __XMLDOC_x_0__',parameters:[{name:'A',description:'Accept A'},{name:'B',description:'Reject B'}],uncertainties:[]});
 const proposed=document.getElementById('ai-summary');proposed.value='Missing token';proposed.dispatchEvent(new Event('input'));
 const summary=document.getElementById('ai-accept-summary');summary.checked=false;summary.dispatchEvent(new Event('change'));
 const check=document.querySelectorAll('#ai-parameters input[type=checkbox]')[1];check.checked=false;check.dispatchEvent(new Event('change'));
 assert.equal(document.getElementById('ai-apply').disabled,false);s.click('ai-apply');
 const submitted=s.sent.filter(m=>m.type==='aiApply').at(-1);assert.equal(submitted.summarySelected,false);assert.deepEqual(submitted.parameters,[{name:'A',description:'Accept A'}]);
 s.reply(req,'approved',{summaryXml:'Ignored summary',parameters:submitted.parameters});s.bridge.flush();
 const doc=s.sent.filter(m=>m.type==='docUpdated').at(-1).doc;assert.equal(doc.summary,'Original');assert.equal(doc.remarks,'Keep remarks');assert.equal(doc.params[0].description,'Accept A');assert.equal(doc.params[1].description,'');s.close();
});

test('AI rejects an approval when the field selection changes after Apply',()=>{
 const s=setup(),req=s.prepare();s.reply(req,'prepared',{fragments:[],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'Proposed',uncertainties:[]});s.click('ai-apply');
 const check=document.getElementById('ai-accept-summary');check.checked=false;check.dispatchEvent(new Event('change'));s.reply(req,'approved',{summaryXml:'Must not write'});s.bridge.flush();assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);s.close();
});

test('return and remarks proposals have independent review and application',()=>{
 const s=setup();s.element.returnType='Integer';s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',returns:'Original return',remarks:'Keep remarks'}}});
 const req=s.prepare();s.reply(req,'prepared',{fragments:[],sectionFragments:{returns:[{token:'__XMLDOC_ret_0__',xml:'<c>$&amp;</c>'}]},previewRequired:true});
 s.reply(req,'proposal',{fresh:true,summary:'Rejected summary',returns:'Return __XMLDOC_ret_0__',remarks:'Rejected remarks',changes:['Result now includes a checked value.'],uncertainties:[]});
 for(const id of ['ai-accept-summary','ai-accept-remarks']){const field=document.getElementById(id);field.checked=false;field.dispatchEvent(new Event('change'));}
 assert.match(document.querySelector('#ai-after').textContent,/<c>\$&amp;<\/c>/);assert.match(document.querySelector('#ai-changes').textContent,/checked value/);s.click('ai-apply');
 const applied=s.sent.filter(m=>m.type==='aiApply').at(-1);assert.equal(applied.summarySelected,false);assert.equal(applied.returnsSelected,true);assert.equal(applied.remarksSelected,false);
 s.reply(req,'approved',{summaryXml:'Ignored',returnsXml:'Return <c>$&amp;</c>'});s.bridge.flush();const doc=s.sent.filter(m=>m.type==='docUpdated').at(-1).doc;
 assert.equal(doc.summary,'Original');assert.equal(doc.returns,'Return <c>$&amp;</c>');assert.equal(doc.remarks,'Keep remarks');s.close();
});

test('review operation offers existing parameter descriptions without affecting unselected parameters',()=>{
 const s=setup();s.element.params=[{name:'Value',type:'Integer'}];s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',params:[{name:'Value',description:'Old meaning'}]}}});
 window.xmlDocAI.receive({state:'configuration',profiles:[{id:'p',name:'Profile'}],templates:[{id:'review',name:'Review documentation against code',operation:'review'}]});
 const operation=document.getElementById('ai-operation');operation.value='review';operation.dispatchEvent(new Event('change'));s.click('ai-prepare');const req=s.sent.filter(m=>m.type==='aiPrepare').at(-1);
 assert.equal(req.operation,'review');assert.equal(req.documentation.params[0].description,'Old meaning');s.reply(req,'prepared',{fragments:[],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'Minimal correction',parameters:[{name:'Value',description:'Corrected meaning'}],changes:['Value is now used as a count.'],uncertainties:[]});
 assert.equal(document.querySelector('#ai-parameters textarea').value,'Corrected meaning');s.click('ai-apply');s.reply(req,'approved',{summaryXml:'Minimal correction',parameters:[{name:'Value',description:'Corrected meaning'}]});s.bridge.flush();assert.equal(s.sent.filter(m=>m.type==='docUpdated').at(-1).doc.params[0].description,'Corrected meaning');s.close();
});

test('AI queue opens each selected method, captures live documentation and cancels late responses',async()=>{
 const s=setup();const second={...s.element,name:'Second',symbolId:'second',locationId:'second@interface',sourceRevision:'r2',lineNumber:20};
 window.xmlDocAI.startQueue([s.element,s.element,{...s.element,kind:'class'},second]);
 let req=s.sent.filter(m=>m.type==='aiPrepare').at(-1);assert.equal(req.symbolId,'run');assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);
 s.reply(req,'prepared',{fragments:[],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'First proposal',uncertainties:[]});
 s.click('ai-queue-next');assert.equal(s.sent.at(-1).type,'openSymbol');assert.equal(s.sent.at(-1).symbolId,'second');
 s.reply(req,'approved',{summaryXml:'Late first write'});assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);
 const before=s.sent.filter(m=>m.type==='aiPrepare').length;
 s.bridge.receive({type:'loadDoc',data:{element:second,doc:{summary:'Live second comment'}}});await Promise.resolve();
 assert.equal(s.sent.filter(m=>m.type==='aiPrepare').length,before+1);req=s.sent.filter(m=>m.type==='aiPrepare').at(-1);assert.equal(req.summary,'Live second comment');
 s.click('ai-queue-cancel');s.reply(req,'proposal',{fresh:true,summary:'Cancelled second',uncertainties:[]});assert.equal(document.querySelector('#ai-apply').disabled,true);assert.equal(document.querySelector('#ai-queue').hidden,true);assert.equal(s.sent.filter(m=>m.type==='docUpdated').length,0);s.close();
});

test('Design edits retain descriptions whose parameter and generic names use different casing',()=>{
 for(const generic of [false,true]){
  const s=setup();const element={...s.element,params:generic?[]:[{name:'Value',type:'Integer'},{name:'Other',type:'Integer'}],genericParams:generic?['T','U']:[]};
  const names=generic?['t','U']:['value','Other'];const key=generic?'typeParams':'params';
  s.bridge.receive({type:'loadDoc',data:{element,doc:{summary:'Original',[key]:[{name:names[0],description:'Important first description'},{name:names[1],description:'Existing second description'}]}}});
  const fields=document.querySelectorAll((generic?'#typeparams-body':'#params-body')+' .td-desc');assert.equal(fields[0].textContent,'Important first description');
  fields[1].querySelector('.tiptap').editor.chain().selectAll().insertContent('Updated second description').run();s.bridge.flush();
  const doc=s.sent.filter(m=>m.type==='docUpdated').at(-1).doc;assert.equal(doc[key][0].description,'Important first description');assert.equal(doc[key][1].description,'Updated second description');s.close();
 }
});

test('all 32 AI field-selection combinations preserve unaccepted source sections',()=>{
 for(let mask=0;mask<32;mask++){
  const s=setup();s.element.params=[{name:'A',type:'Integer'},{name:'B',type:'Integer'}];s.element.returnType='Integer';
  s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',returns:'Original return',remarks:'Original remarks',params:[{name:'A',description:''},{name:'B',description:''}]}}});
  const req=s.prepare();s.reply(req,'prepared',{fragments:[],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'New summary',returns:'New return',remarks:'New remarks',parameters:[{name:'A',description:'New A'},{name:'B',description:'New B'}],uncertainties:[]});
  const controls=[document.getElementById('ai-accept-summary'),...document.querySelectorAll('#ai-parameters input[type=checkbox]'),document.getElementById('ai-accept-returns'),document.getElementById('ai-accept-remarks')];
  controls.forEach((c,i)=>{c.checked=!!(mask&(1<<i));c.dispatchEvent(new Event('change'));});
  assert.equal(document.getElementById('ai-apply').disabled,mask===0,'mask '+mask);
  if(mask){s.click('ai-apply');const approved={summaryXml:mask&1?'New summary':'Original',parameters:[]};if(mask&2)approved.parameters.push({name:'A',description:'New A'});if(mask&4)approved.parameters.push({name:'B',description:'New B'});if(mask&8)approved.returnsXml='New return';if(mask&16)approved.remarksXml='New remarks';s.reply(req,'approved',approved);s.bridge.flush();
   const doc=s.sent.filter(m=>m.type==='docUpdated').at(-1).doc;assert.equal(doc.summary,mask&1?'New summary':'Original');assert.equal(doc.returns,mask&8?'New return':'Original return');assert.equal(doc.remarks,mask&16?'New remarks':'Original remarks');assert.equal(doc.params[0].description,mask&2?'New A':'');assert.equal(doc.params[1].description,mask&4?'New B':'');
  }else{s.click('ai-apply');assert.equal(s.sent.filter(m=>m.type==='aiApply').length,0);}s.close();
 }
});

test('AI section choices and review actions localize without translating parameter identifiers',()=>{
 const s=setup();s.element.params=[{name:'Value',type:'Integer'}];s.bridge.receive({type:'loadDoc',data:{element:s.element,doc:{summary:'Original',params:[{name:'Value',description:''}]}}});
 const req=s.prepare();s.reply(req,'prepared',{fragments:[],previewRequired:true});s.reply(req,'proposal',{fresh:true,summary:'User prose',returns:'Result prose',remarks:'Remark prose',parameters:[{name:'Value',description:'Parameter prose'}],uncertainties:[]});
 for(const language of ['ru','zh','ko','ja']){
  window.xmlDocSettings.apply({language,fontSize:13,theme:'dark'});
  assert.notEqual(document.getElementById('ai-review').title,'Review documentation against code');
  assert.ok(!document.getElementById('ai-proposal').textContent.includes('Accept summary'));
  const name=document.querySelector('#ai-parameters code');assert.equal(name.textContent,'Value');
  const check=document.querySelector('#ai-parameters input');assert.ok(check.getAttribute('aria-label').includes('Value'));assert.notEqual(check.getAttribute('aria-label'),'Accept parameter Value');
  assert.equal(document.getElementById('ai-summary').value,'User prose');assert.equal(document.getElementById('ai-returns').value,'Result prose');
 }s.close();
});

test('AI queue does not reuse a document from another project sharing the same unit',async()=>{
 const s=setup();s.bridge.receive({type:'loadDoc',data:{element:{...s.element,projectFile:'A.dproj'},doc:{summary:'Project A'}}});
 const target={...s.element,projectFile:'B.dproj'};const before=s.sent.filter(m=>m.type==='aiPrepare').length;
 window.xmlDocAI.startQueue([target]);assert.equal(s.sent.at(-1).type,'openSymbol');assert.equal(s.sent.at(-1).projectFile,'B.dproj');assert.equal(s.sent.filter(m=>m.type==='aiPrepare').length,before);
 s.bridge.receive({type:'loadDoc',data:{element:target,doc:{summary:'Project B'}}});await Promise.resolve();
 const request=s.sent.filter(m=>m.type==='aiPrepare').at(-1);assert.equal(request.projectFile,'B.dproj');assert.equal(request.summary,'Project B');s.click('ai-queue-cancel');s.close();
});
for(const outcome of ['success','delayed','rejected'])test('AI queue waits for source ACK and reload: '+outcome,()=>{
 const s=setup();s.bridge.saveDebounceMs=60000;window.xmlDocAI.startQueue([s.element,{...s.element,name:'Other',symbolId:'other',locationId:'other@interface'}]);
 const req=s.sent.filter(m=>m.type==='aiPrepare').at(-1);s.reply(req,'prepared',{fragments:[],previewRequired:false});s.reply(req,'proposal',{fresh:true,summary:'Accepted change',uncertainties:[]});s.click('ai-apply');
 assert.equal(document.querySelector('#ai-queue-next').disabled,true);s.reply(req,'approved',{summaryXml:'Accepted change'});const writes=s.sent.filter(m=>m.type==='docUpdated');assert.equal(writes.length,1);const write=writes[0];
 assert.match(document.querySelector('#ai-status').textContent,/Waiting for source write/);s.click('ai-queue-next');assert.equal(s.sent.filter(m=>m.type==='openSymbol').length,0);
 s.bridge.receive({type:'editResult',editId:write.editId,sessionId:s.element.sessionId,status:outcome==='rejected'?'Source changed — reload before applying':'Applied'});
 assert.equal(document.querySelector('#ai-queue-next').disabled,true);assert.doesNotMatch(document.querySelector('#ai-status').textContent,/AI proposal applied/);
 if(outcome==='rejected'){assert.match(document.querySelector('#ai-status').textContent,/Source changed/);s.click('ai-queue-next');assert.equal(s.sent.filter(m=>m.type==='openSymbol').length,0);}
 else {if(outcome==='delayed'){s.click('ai-queue-next');assert.equal(s.sent.filter(m=>m.type==='openSymbol').length,0);}s.bridge.receive({type:'loadDoc',data:{element:{...s.element,sourceRevision:'r2'},doc:write.doc}});assert.match(document.querySelector('#ai-status').textContent,/AI proposal applied/);assert.equal(document.querySelector('#ai-queue-next').disabled,false);s.click('ai-queue-next');assert.equal(s.sent.filter(m=>m.type==='openSymbol').length,1);}
 s.close();
});

test('AI queue retains the current method on a source change before its write ACK',()=>{
 const s=setup();window.xmlDocAI.startQueue([s.element,{...s.element,name:'Other',symbolId:'other'}]);const req=s.sent.filter(m=>m.type==='aiPrepare').at(-1);s.reply(req,'prepared',{fragments:[],previewRequired:false});s.reply(req,'proposal',{fresh:true,summary:'Accepted',uncertainties:[]});s.click('ai-apply');s.reply(req,'approved',{summaryXml:'Accepted'});
 s.bridge.receive({type:'loadDoc',data:{element:{...s.element,sourceRevision:'external-change'},doc:{summary:'Changed externally'}}});assert.equal(document.querySelector('#ai-queue-next').disabled,true);assert.match(document.querySelector('#ai-status').textContent,/Source changed/);s.click('ai-queue-next');assert.equal(s.sent.filter(m=>m.type==='openSymbol').length,0);s.close();
});
