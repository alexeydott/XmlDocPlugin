import type { DocModel, ElementInfo, InboundMessage, OutboundMessage } from './types';
export type DocChangedCallback = (doc: DocModel) => void;
export type ElementLoadedCallback = (element: ElementInfo, doc: DocModel) => void;
export type EditContext = Pick<ElementInfo, 'fileName' | 'symbolId' | 'declarationId' | 'sessionId' | 'sourceRevision'>;

export class DelphiBridge {
  private onDocChangedListeners: DocChangedCallback[] = [];
  private onElementLoadedListeners: ElementLoadedCallback[] = [];
  private timer: ReturnType<typeof setTimeout> | null = null;
  private pending: OutboundMessage | null = null;
  private context: EditContext = {};
  saveDebounceMs = 500;
  status = 'Applied';
  pinned = false;
  private held: InboundMessage | null = null;
  readonly drafts = new Map<string, {doc:DocModel;revision?:string}>();
  private key(c: EditContext): string { return `${c.fileName}|${c.declarationId??c.symbolId}`; }
  setContext(element: ElementInfo): void {
    this.cancelPending();
    this.context = { fileName: element.fileName, symbolId: element.symbolId, declarationId:element.declarationId,
      sessionId: element.sessionId, sourceRevision: element.sourceRevision };
    const draft=this.drafts.get(this.key(this.context));
    if(draft && draft.revision!==element.sourceRevision)this.context.sourceRevision=draft.revision;
  }
  setStatus(status: string): void {
    this.status = status;
    window.dispatchEvent(new CustomEvent('docStatus', { detail: status }));
  }
  setPinned(pinned: boolean): void {
    this.pinned = pinned;
    if (!pinned && this.held) { const next = this.held; this.held = null; this.receive(next); }
  }
  receive(message: InboundMessage): void {
    if (message.type === 'editResult') {
      if (message.sessionId === this.context.sessionId) {
        this.setStatus(message.status);
        if(message.status==='Applied')this.drafts.delete(this.key(this.context));
      }
      return;
    }
    if (message.type === 'loadDoc') {
      if (this.pinned) { this.held = message; return; }
      this.setContext(message.data.element);
      const draft = this.drafts.get(this.key(this.context));
      this.setStatus(draft ? 'Unsaved draft — source may have changed' : 'Applied');
      if(draft && draft.revision!==this.context.sourceRevision) this.context.sourceRevision=draft.revision;
      this.onElementLoadedListeners.forEach(cb => cb(message.data.element, draft?.doc ?? message.data.doc));
    }
  }
  sendToHost(message: OutboundMessage): void {
    (window as any).chrome?.webview?.postMessage(JSON.stringify(message));
  }
  cancelPending(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null; this.pending = null;
  }
  flush(): void {
    if (!this.pending) return;
    const pending = this.pending; this.cancelPending(); this.sendToHost(pending);
  }
  saveDraft(doc:DocModel):void {
    const snapshot=JSON.parse(JSON.stringify(doc));const context={...this.context};
    this.drafts.set(this.key(context),{doc:snapshot,revision:context.sourceRevision});
    this.sendToHost({type:'draftUpdated',doc:snapshot,...context} as any);
    this.setStatus('Modified');
  }
  notifyDocChanged(doc: DocModel): void {
    this.cancelPending();
    const snapshot = JSON.parse(JSON.stringify(doc));
    const context = { ...this.context };
    this.drafts.set(this.key(context), {doc:snapshot,revision:context.sourceRevision});
    this.sendToHost({type:'draftUpdated',doc:snapshot,...context} as any);
    this.pending = { type: 'docUpdated', doc: snapshot, ...context };
    this.setStatus('Modified');
    this.timer = setTimeout(() => this.flush(), Math.max(0, this.saveDebounceMs));
    this.onDocChangedListeners.forEach(cb => cb(snapshot));
  }
  acknowledge(element: ElementInfo): void { this.drafts.delete(this.key(element)); }
  onElementLoaded(callback: ElementLoadedCallback): void { this.onElementLoadedListeners.push(callback); }
  onDocChanged(callback: DocChangedCallback): void { this.onDocChangedListeners.push(callback); }
}
export const bridge = new DelphiBridge();
(window as any).bridge = bridge;
