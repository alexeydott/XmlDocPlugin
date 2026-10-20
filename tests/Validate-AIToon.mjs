import {readFileSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const require=createRequire(new URL('../web/package.json',import.meta.url));
const {decode}=await import(pathToFileURL(require.resolve('@toon-format/toon')).href);
const [mode,file]=process.argv.slice(2);
if(mode==='generate'){
 let seed=124597;const next=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};
 const alphabet=['a','Z','0',' ',':',',','[',']','{','}','"','\\','\n','\r','\t','\0','\x01','😀','日本語','한국어','中文','Пример','&lt;b&gt;'];
 const text=()=>Array.from({length:next()%30},()=>alphabet[next()%alphabet.length]).join('');
 const cases=['',true,false,null,0,{},[],[[],[1,'x']],{mixed:[{},[],{field:['a'],other:{a:1}},false,'null']}];
 for(let i=0;i<512;i++)cases.push({instructions:text(),context:{signature:text(),implementation:text(),parameters:Array.from({length:next()%5},()=>({name:text(),type:text()})),type_context:{owner:text(),defines:[text(),text()],includesAndDependencies:[{file:text(),revision:text()},{file:text(),revision:text(),source:text()}]}}});
 writeFileSync(file,JSON.stringify(cases));
}else if(mode==='request'){
 const request=JSON.parse(readFileSync(file,'utf8').replace(/^\uFEFF/,''));
 const payload=decode(request.messages.find(m=>m.role==='user').content);
 assert.equal(typeof payload.instructions,'string');assert.equal(typeof payload.context.implementation,'string');assert.ok(Array.isArray(payload.context.parameters));
 console.log(JSON.stringify({toonDecoded:true,implementationChars:payload.context.implementation.length,parameters:payload.context.parameters.length,language:payload.context.language}));
}else{
 const cases=JSON.parse(readFileSync(file,'utf8').replace(/^\uFEFF/,''));
 for(const [i,item]of cases.entries())assert.deepEqual(decode(item.toon),item.value,`Native TOON round-trip ${i}: ${item.toon}`);
 console.log(`PASS ${cases.length} native TOON cases decoded by the official reference implementation`);
}
