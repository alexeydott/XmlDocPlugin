import { buildSync } from 'esbuild';
import { createRequire } from 'node:module';
export function load(entry){
 const code=buildSync({entryPoints:[new URL('../src/'+entry,import.meta.url).pathname.replace(/^\/(.:)/,'$1')],bundle:true,platform:'node',format:'cjs',write:false}).outputFiles[0].text;
 const module={exports:{}};new Function('module','exports','require',code)(module,module.exports,createRequire(import.meta.url));return module.exports;
}
