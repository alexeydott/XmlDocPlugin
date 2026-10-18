import {JSDOM} from 'jsdom';import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {load} from './load.mjs';
test('Russian and Chinese UI switch without changing document text, selectors or event handlers',async()=>{
 const dom=new JSDOM('<html><body><h3 class="doc-heading">Summary</h3><button title="Recover drafts" aria-label="Recover drafts">Recover drafts</button><select><option>All symbols</option></select><input placeholder="Find symbol or documentation"><div class="tiptap" contenteditable="true">Summary</div><div id="tree-content"><button>Summary</button></div></body></html>');
 for(const k of ['window','document','MutationObserver','CustomEvent'])globalThis[k]=dom.window[k];
 const {setLanguage,resolveLanguage,localizeUi}=load('i18n.ts');let clicks=0;document.querySelector('button').onclick=()=>clicks++;
 const ru=JSON.parse(readFileSync(new URL('../../resources/locales/ru.json',import.meta.url),'utf8')),zh=JSON.parse(readFileSync(new URL('../../resources/locales/zh.json',import.meta.url),'utf8'));
 assert.deepEqual(Object.keys(ru).sort(),Object.keys(zh).sort());assert.ok(Object.keys(ru).length>180);for(const [key,value] of Object.entries(ru)){const tokens=t=>t.match(/\{\d+\}/g)??[];assert.deepEqual(tokens(value),tokens(key));assert.deepEqual(tokens(zh[key]),tokens(key));}
 assert.equal(resolveLanguage('ru-RU'),'ru');assert.equal(resolveLanguage('zh-Hans'),'zh');assert.equal(resolveLanguage('fr-FR'),'en');
 for(const [code,pack] of [['ru',ru],['zh-CN',zh],['en',{}]]){setLanguage(code);assert.equal(document.querySelector('h3').textContent,pack.Summary??'Summary');assert.equal(document.querySelector('button').title,pack['Recover drafts']??'Recover drafts');assert.equal(document.querySelector('select').value,'All symbols');assert.equal(document.querySelector('.tiptap').textContent,'Summary');assert.equal(document.querySelector('#tree-content button').textContent,'Summary');document.querySelector('button').click();}
 assert.equal(clicks,3);setLanguage('zh');const dynamic=document.createElement('button');dynamic.textContent='Save terminology';document.body.append(dynamic);await new Promise(r=>setTimeout(r,0));assert.equal(dynamic.textContent,zh['Save terminology']);
 let seed=16;for(let i=0;i<1000;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;setLanguage(['en','ru','zh'][seed%3]);localizeUi();assert.equal(document.querySelector('.tiptap').textContent,'Summary');assert.equal(document.querySelector('select').value,'All symbols');}
 dom.window.close();
});
