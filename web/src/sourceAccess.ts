/** Viewing and navigation remain available while source mutation is locked. */
const navigation = new Set(['history-back','history-forward','pin-document','compact-document','focus-source','reload-document','quick-documentation','open-xml','fold-documentation','show-problems','refresh-catalog','next-problem','save-baseline','load-baseline','recover-drafts']);
export function applySourceAccess(readOnly: boolean, reason: string): void {
 const banner=document.getElementById('source-access-status');
 if(banner){banner.hidden=!readOnly;banner.textContent=reason;}
 for(const control of document.querySelectorAll<HTMLInputElement|HTMLTextAreaElement>('#doc-design input,#doc-design textarea,#xml-source,#member-summaries textarea'))control.readOnly=readOnly || control.dataset.sourceLocked==='true';
 for(const button of document.querySelectorAll<HTMLButtonElement>('#doc-design button,#doc-toolbar button,#apply-xml'))button.disabled=readOnly;
 for(const button of document.querySelectorAll<HTMLButtonElement>('#workbench button')){
  const viewAction=navigation.has(button.id) || button.dataset.workbenchIcon==='open-source' || button.dataset.workbenchIcon==='open-xml';
  button.disabled=readOnly && !viewAction;
 }
 for(const check of document.querySelectorAll<HTMLInputElement>('#member-summaries input[type=checkbox]'))check.disabled=readOnly || check.dataset.sourceLocked==='true';
}
