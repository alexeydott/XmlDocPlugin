/** Local vector icons: no fonts, external requests or raster assets. */
const save = '<path d="M4 3h13l3 3v15H4V3ZM8 3v6h8V3M8 21v-8h8v8"/>';
const preview = '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>';
const paths: Record<string, string> = {
 'save-template': save,
 'save-terms': save,
 'apply-template': '<path d="M4 4h16v16H4V4ZM8 8h8M8 12h4m3 3h6m-3-3v6"/>',
 'insert-selection': '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5M8 10l-2 2 2 2m8-4 2 2-2 2m-3-6-2 12"/>',
 'link-example': '<path d="m10 14 4-4m-5 7-2 2a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0m2-2 2-2a4 4 0 1 1 6 6l-4 4a4 4 0 0 1-6 0"/>',
 'replace-all': '<circle cx="9" cy="8" r="5"/><path d="m13 12 3 3M3 20h18m-4-4 4 4-4 4"/>',
 'apply-summaries': preview,
 'preview-change': preview,
 'review-draft': preview,
 'apply-operation': '<path d="m4 12 5 5L20 6"/>',
 'apply-xml': '<path d="m5 4-3 4 3 4m8-8 3 4-3 4m-4 3 4 4L22 9"/>',
 'cancel-operation': '<path d="m6 6 12 12M18 6 6 18"/>',
 'reference': '<path d="m10 14 4-4M9 17l-2 2a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0m2-2 2-2a4 4 0 1 1 6 6l-4 4a4 4 0 0 1-6 0"/>',
 'copy-documentation': '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
 'open-source': '<path d="M14 3H3v18h18V10M12 12 21 3m-7 0h7v7"/>',
 'history-back': '<path d="m14 6-6 6 6 6M8 12h12"/>',
 'history-forward': '<path d="m10 6 6 6-6 6M4 12h12"/>',
 'pin-document': '<path d="m9 3 12 12-4 1-3 3-2-5-5-2 3-3-1-6ZM3 21l6-6"/>',
 'compact-document': '<path d="M4 3h16M4 21h16M8 7l4 4 4-4M8 17l4-4 4 4"/>',
 'focus-source': '<path d="m8 5-6 7 6 7m8-14 6 7-6 7m-3-16-2 18"/>',
 'reload-document': '<path d="M20 8a8 8 0 1 0 0 8M20 3v5h-5"/>',
 'recover-drafts': '<path d="M8 3h10l3 3v15H8V3ZM14 3v5h7M4 9a5 5 0 1 0 1 9M1 9h4v4"/>',
 'quick-documentation': '<path d="M3 4h7l2 2 2-2h7v15h-7l-2 2-2-2H3V4ZM12 6v15M6 8h3m-3 4h3m6-4h3m-3 4h3"/>',
 'sync-document': '<path d="M4 8a8 8 0 0 1 14-3l2 3M20 3v5h-5M20 16A8 8 0 0 1 6 19l-2-3M4 21v-5h5"/>',
 'open-xml': '<path d="m7 7-5 5 5 5m10-10 5 5-5 5M14 4l-4 16"/>',
 'format-document': '<path d="M3 5h18M3 10h12M3 15h9M3 20h7m7-8 1.5 3.5L22 17l-3.5 1.5L17 22l-1.5-3.5L12 17l3.5-1.5L17 12Z"/>',
 'fold-documentation': '<path d="m8 3 4 4 4-4M3 12h18M8 21l4-4 4 4"/>',
 'show-problems': '<path d="m12 3 10 18H2L12 3ZM12 9v5m0 3v.1"/>',
 'refresh-catalog': '<path d="M20 8a8 8 0 1 0 0 8M20 3v5h-5"/>',
 'next-problem': '<path d="m8 4 6 11H2L8 4ZM8 9v2m0 2v.1M13 19h9m-4-4 4 4-4 4"/>',
 'save-baseline': '<path d="M4 3h13l3 3v15H4V3ZM8 3v6h8V3M8 21v-8h8v8"/>',
 'load-baseline': '<path d="M3 7V4h7l2 3h9v14H3V7ZM12 10v7m-3-3 3 3 3-3"/>',
};

export function iconMarkup(id: string): string | undefined {
 const drawing = paths[id];
 if (!drawing) return undefined;
 return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${drawing}</svg>`;
}

export function initWorkbenchIcons(root: HTMLElement): void {
 for (const button of root.querySelectorAll<HTMLButtonElement>('button[id]')) {
  setWorkbenchIcon(button, button.id);
 }
}

export function setWorkbenchIcon(button: HTMLButtonElement, icon: string): void {
  const svg = iconMarkup(icon);
  if (!svg) return;
  const label = button.getAttribute('aria-label') || button.textContent?.trim() || button.title;
  button.title = button.title || label;
  button.setAttribute('aria-label', label);
  button.type = 'button';
  button.classList.add('workbench-icon');
  button.dataset.workbenchIcon = icon;
  button.innerHTML = svg;
}
