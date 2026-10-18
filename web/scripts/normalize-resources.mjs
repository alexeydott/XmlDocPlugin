import {readFile,writeFile} from 'node:fs/promises';
for(const name of ['index.html','explorer.html']) {
 const file=new URL('../../resources/'+name,import.meta.url);
 const content=await readFile(file,'utf8');
 await writeFile(file,content.replace(/\r\n/g,'\n'),'utf8');
}
