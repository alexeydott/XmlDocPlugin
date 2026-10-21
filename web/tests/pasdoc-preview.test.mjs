import test from 'node:test';
import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {load} from './load.mjs';
const dom=new JSDOM();globalThis.DOMParser=dom.window.DOMParser;globalThis.XMLSerializer=dom.window.XMLSerializer;
const {inlineToPreviewHtml}=load('preview.ts');const {textToHtml}=load('xmlCodec.ts');
test('PasDoc tables and numbering remain visible and protected in Design',()=>{
 const xml='<table><tr><th>Head</th><th>Value</th><th>Extra</th></tr><tr><td>A</td><td>B</td><td>C</td></tr></table>';
 const preview=inlineToPreviewHtml(xml);assert.ok(preview.includes('<th>Head</th>'));assert.ok(preview.includes('<td>C</td>'));
 const numbered='<list type="number"><item number="10"><description>Ten</description></item></list>';
 assert.ok(inlineToPreviewHtml(numbered).includes('value="10"'));
 assert.ok(textToHtml(numbered).includes('data-xml'));assert.ok(textToHtml(xml).includes('data-xml'));
});
