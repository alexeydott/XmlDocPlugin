import {mkdtemp,readFile,writeFile,rename,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

// Stage both views before publishing. Truncating a resource that a Windows
// reader has memory-mapped can fail even when replacing the file is allowed.
const stage=await mkdtemp(join(tmpdir(),'xmldoc-web-'));
const vite=fileURLToPath(new URL('../node_modules/vite/bin/vite.js',import.meta.url));
try {
 for(const config of ['vite.config.ts','vite.explorer.config.ts']) {
  const result=spawnSync(process.execPath,[vite,'build','--config',config,'--outDir',stage],{stdio:'inherit'});
  if(result.error)throw result.error;
  if(result.status!==0)throw Error(`Web build failed: ${config} (exit ${result.status})`);
 }
 for(const name of ['index.html','explorer.html']) {
  const target=new URL('../../resources/'+name,import.meta.url);
  const pending=new URL(target.href+'.'+process.pid+'.tmp');
  try {
   const content=await readFile(join(stage,name),'utf8');
   await writeFile(pending,content.replace(/\r\n/g,'\n'),'utf8');
   await rename(pending,target);
  } finally {await rm(pending,{force:true});}
 }
} finally {
 // mkdtemp returned this exact directory; no existing checkout is removed.
 if(!stage.startsWith(join(tmpdir(),'xmldoc-web-')))throw Error('Unexpected web build directory');
 await rm(stage,{recursive:true,force:true});
}
