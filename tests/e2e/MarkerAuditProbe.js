(async()=>{
 if(window.__markerAuditRunning)return;window.__markerAuditRunning=true;
 const send=(action,extra={})=>window.chrome.webview.postMessage(JSON.stringify({type:'e2e',action,...extra}));
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 const until=async(test,label)=>{for(let i=0;i<200;i++){if(test())return;await pause(50);}throw Error(label);};
 const assert=(value,label)=>{if(!value)throw Error(label);};
 const log=result=>send('marker-log',{result:JSON.stringify(result)});
 try{
  const original=JSON.stringify(window.xmlDocEditor.get().doc);
  for(const [language,script] of [['ru',/[А-Яа-я]/],['zh',/[\u3400-\u9fff]/],['ko',/[\uac00-\ud7af]/],['ja',/[\u3040-\u30ff\u3400-\u9fff]/],['en',null]]){
   send('language-ui',{language});await until(()=>window.__xmlDocLanguageUi===language,'Native locale did not load');await pause(100);
   const heading=document.querySelector('[data-section=summary]').textContent;
   const hint=document.querySelector('#recover-drafts').title;
   const native=window.__nativeLocaleAudit;assert(native?.language===language,'Native locale audit missing');
   const localized=script?script.test(heading)&&script.test(hint)&&document.documentElement.lang===language&&['settingsTitle','markerHint','generationTitle','coverageTitle'].every(key=>script.test(native[key])):true;
   log({check:'locale',language,browserLanguage:document.documentElement.lang,heading,hint,native,localized});
   if(language!=='en')assert(localized,'Missing shipped translation '+language);
   assert(JSON.stringify(window.xmlDocEditor.get().doc)===original,'Locale changed source documentation');
  }
  send('marker-select');await until(()=>window.__markerSelected&&window.xmlDocEditor.get().element.name==='UndocumentedFirst','Audit member not loaded');
  const edit=async summary=>{
   const e=document.querySelector('#summary-editor .tiptap');e.editor.chain().focus().selectAll().insertContent(summary).run();
   await until(()=>window.bridge.status==='Applied'&&window.xmlDocEditor.get().doc.summary===summary,'Source edit not acknowledged');
  };
  const coverage=async()=>{
   window.__markerCoverage=null;send('marker-coverage');await until(()=>window.__markerCoverage,'Coverage did not finish');
   const d=window.__markerCoverage;const ready=d.complete.match(/ready:\s*(\d+)/);const documented=d.documented.match(/Documented:\s*(\d+)/);
   assert(ready&&documented,'Unrecognized Coverage statistics '+JSON.stringify(d));return {ready:+ready[1],documented:+documented[1]};
  };
  const filtered=async summary=>{
   const filter=document.querySelector('#catalog-filter');filter.value='all';filter.dispatchEvent(new Event('change'));document.querySelector('#refresh-catalog').click();
   await until(()=>Array.from(document.querySelectorAll('.catalog-row')).some(r=>r.textContent.includes(summary)),'Catalog lacks latest source comment');
   filter.value='todo';filter.dispatchEvent(new Event('change'));
   return Array.from(document.querySelectorAll('.catalog-row')).some(r=>r.textContent.includes(summary));
  };
  await edit('Verified complete audit summary.');assert(!document.querySelector('#documentation-problems').textContent.includes('XD008'),'Complete comment flagged as draft');
  assert(!await filtered('Verified complete audit summary.'),'Complete comment in draft filter');const baseline=await coverage();
  for(const marker of ['FIXME:','VERIFY-RESTART:','ДОРАБОТАТЬ:','待补充：','수정 필요:','要修正：','[draft].*:']){
   const summary=marker+' pending audit description';await edit(summary);
   assert(document.querySelector('#documentation-problems').textContent.includes('XD008'),'Problems missed '+marker);
   assert(await filtered(summary),'Draft filter missed '+marker);const stats=await coverage();
   assert(stats.documented===baseline.documented,'Presence changed for '+marker);
   assert(stats.ready===baseline.ready-1,'Coverage readiness disagrees for '+marker+' '+JSON.stringify({baseline,stats}));
   log({check:'quality',marker,problems:'XD008',draftFilter:true,baseline,stats,consistent:true});
  }
  await edit('Verified complete audit summary.');const restored=await coverage();assert(restored.ready===baseline.ready,'Readiness did not recover');
  log({check:'quality-recovery',baseline,restored});send('finish');
 }catch(error){send('fail',{message:String(error),stack:error?.stack??''});}
})();
