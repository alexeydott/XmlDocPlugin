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
