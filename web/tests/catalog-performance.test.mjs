import {JSDOM} from 'jsdom';import {readFileSync} from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import {load} from './load.mjs';
test('large catalog avoids eager XML analysis, pages rows, and keeps pending grid edits',()=>{
 const dom=new JSDOM(readFileSync(new URL('../index.html',import.meta.url),'utf8'),{pretendToBeVisual:true});
 for(const key of ['window','document','XMLSerializer','HTMLElement','Element','Node','Event','CustomEvent'])globalThis[key]=dom.window[key];
 let parses=0;globalThis.DOMParser=class extends dom.window.DOMParser{parseFromString(...args){parses++;return super.parseFromString(...args);}};
 const element={kind:'class',name:'TWorker',symbolId:'worker',fileName:'Large.pas',params:[]};
 load('workbench.ts').initWorkbench({get:()=>({element,doc:{summary:'Owner'}}),apply:()=>{}});
 const elements=Array.from({length:1500},(_,i)=>({kind:'method',name:'Run'+i,signature:'Run'+i,symbolId:'method'+i,qualifiedParent:'TWorker',fileName:'Large.pas',params:[],doc:{summary:'Description '+i,sourceXml:'<summary>Original</summary>'}}));
 window.xmlDocWorkbench.receiveCatalog({elements});
 assert.equal(document.querySelectorAll('.catalog-row').length,100);assert.equal(parses,0,'All-symbols view must not parse every comment');
 assert.equal(document.querySelectorAll('#member-summaries textarea').length,100);
 const grid=document.querySelector('#member-summaries textarea');grid.value='UNSAVED GRID EDIT';
 document.querySelector('#catalog-results > button').click();assert.equal(document.querySelectorAll('.catalog-row').length,200);assert.equal(grid.value,'UNSAVED GRID EDIT');assert.equal(document.querySelector('#member-summaries textarea'),grid);
 document.querySelector('#member-summaries > button').click();assert.equal(document.querySelectorAll('#member-summaries textarea').length,200);assert.equal(grid.value,'UNSAVED GRID EDIT');
 const query=document.querySelector('#catalog-query');query.value='Run1499';query.dispatchEvent(new Event('input'));
 assert.equal(document.querySelectorAll('.catalog-row').length,1);assert.match(document.querySelector('.catalog-row').textContent,/Run1499/);
 dom.window.close();
});
