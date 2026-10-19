import {JSDOM} from 'jsdom';import {readFileSync} from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
test('Design ACK and source reload retain the visible unapplied XML draft',()=>{
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});
 for(const k of ['window','document','DOMParser','XMLSerializer','HTMLElement','Element','Node','Event','MutationObserver','CustomEvent','getComputedStyle'])globalThis[k]=k==='getComputedStyle'?dom.window.getComputedStyle.bind(dom.window):dom.window[k];
 Object.defineProperty(globalThis,'navigator',{value:dom.window.navigator,configurable:true});globalThis.ResizeObserver=class{observe(){}disconnect(){}};
 window.matchMedia=()=>({matches:false,addEventListener(){},removeEventListener(){}});const sent=[];window.chrome={webview:{postMessage:s=>sent.push(JSON.parse(s))}};
 const {init}=load('editor.ts');init();const bridge=window.bridge;
 const element={kind:'method',name:'Run',symbolId:'run',locationId:'run@interface',fileName:'Case.pas',sessionId:'session',sourceRevision:'r1',params:[],genericParams:[]};
 bridge.receive({type:'loadDoc',data:{element,doc:{summary:'Original',sourceXml:'<summary>Original</summary>'}}});
 document.querySelector('#open-xml').click();const xml=document.querySelector('#xml-source');xml.value='<summary>UNAPPLIED RAW</summary>';xml.dispatchEvent(new Event('input'));
 document.querySelector('[data-tab=design]').click();const summary=document.querySelector('#summary-editor .tiptap').editor;summary.chain().selectAll().insertContent('APPLIED DESIGN').run();bridge.flush();
 const edit=sent.filter(m=>m.type==='docUpdated').at(-1);assert.ok(edit);document.querySelector('#open-xml').click();assert.equal(xml.value,'<summary>UNAPPLIED RAW</summary>');
 bridge.receive({type:'editResult',sessionId:'session',editId:edit.editId,status:'Applied'});
 bridge.receive({type:'loadDoc',data:{element:{...element,sourceRevision:'r2'},doc:{summary:'APPLIED DESIGN',sourceXml:'<summary>APPLIED DESIGN</summary>'}}});
 assert.equal(xml.value,'<summary>UNAPPLIED RAW</summary>');assert.equal(bridge.unappliedXml().xml,xml.value);assert.equal(document.querySelector('#doc-xml').classList.contains('hidden'),false);
 xml.value='<summary>NEXT RAW</summary>';xml.dispatchEvent(new Event('input'));assert.equal(bridge.unappliedXml().xml,xml.value);bridge.cancelPending();dom.window.close();
});

test('changing the configured placeholder prefix refreshes unfinished-draft catalog filtering',()=>{
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});
 for(const k of ['window','document','DOMParser','XMLSerializer','HTMLElement','Element','Node','Event','MutationObserver','CustomEvent','getComputedStyle'])globalThis[k]=k==='getComputedStyle'?dom.window.getComputedStyle.bind(dom.window):dom.window[k];
 Object.defineProperty(globalThis,'navigator',{value:dom.window.navigator,configurable:true});globalThis.ResizeObserver=class{observe(){}disconnect(){}};
 window.matchMedia=()=>({matches:false,addEventListener(){},removeEventListener(){}});window.chrome={webview:{postMessage(){}}};load('editor.ts').init();
 const element={kind:'class',name:'TWidget',symbolId:'widget',fileName:'Case.pas',params:[],genericParams:[]};
 window.bridge.receive({type:'loadDoc',data:{element,doc:{summary:'Owner'}}});
 window.xmlDocWorkbench.receiveCatalog({elements:[
  {...element,symbolId:'custom',doc:{summary:'FIXME: Custom unfinished comment'}},
  {...element,symbolId:'legacy',doc:{summary:'TODO: Legacy unfinished comment'}},
  {...element,symbolId:'complete',doc:{summary:'Represents a widget.'}}
 ]});
 const filter=document.querySelector('#catalog-filter');filter.value='todo';filter.dispatchEvent(new Event('change'));
 assert.equal(document.querySelectorAll('.catalog-row').length,1,'legacy TODO remains visible');
 window.xmlDocSettings.apply({placeholderPrefix:'FIXME: '});
 assert.equal(document.querySelectorAll('.catalog-row').length,2,'both configured and legacy placeholders remain unfinished');
 window.xmlDocSettings.apply({placeholderPrefix:'OTHER: '});assert.equal(document.querySelectorAll('.catalog-row').length,1,'filter reacts to settings without changing the comments');
 window.bridge.cancelPending();dom.window.close();
});
