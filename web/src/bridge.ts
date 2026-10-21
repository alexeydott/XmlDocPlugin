import type { DocModel, ElementInfo, InboundMessage, OutboundMessage } from './types';
export type DocChangedCallback = (doc: DocModel) => void;
export type ElementLoadedCallback = (element: ElementInfo, doc: DocModel) => void;
export type EditContext = Pick<ElementInfo, 'fileName' | 'symbolId' | 'declarationId' | 'sessionId' | 'sourceRevision' | 'locationId' | 'projectFile'>;

export class DelphiBridge {
  private onDocChangedListeners: DocChangedCallback[] = [];
  private onElementLoadedListeners: ElementLoadedCallback[] = [];
  private timer: ReturnType<typeof setTimeout> | null = null;
  private pending: OutboundMessage | null = null;
  private context: EditContext = {};
  saveDebounceMs = 500;
  private localVersion=0;
  get draftVersion():number {return this.localVersion;}
  captureStamp():EditContext & {draftVersion:number} {return {...this.context,draftVersion:this.localVersion};}
  isCurrentStamp(stamp:EditContext & {draftVersion:number}):boolean {
    return stamp.draftVersion===this.localVersion && ['fileName','locationId','declarationId','symbolId','sessionId','sourceRevision','projectFile'].every(key=>(stamp as any)[key]===(this.context as any)[key]);
  }
  status = 'Applied';
  pinned = false;
  readOnly = false;
  readOnlyReason = '';
  private serial=0;
  private readonly instanceId=globalThis.crypto?.randomUUID?.()??`${Date.now()}-${Math.random()}`;
  private inFlight: {id:string;key:string;context:EditContext;doc:DocModel;applied:boolean}|null=null;
  private held: InboundMessage | null = null;
  private originalXml='';
  private readonly rawDrafts=new Map<string,NonNullable<DocModel['unappliedXml']>>();
  unappliedXml():DocModel['unappliedXml'] {return this.rawDrafts.get(this.key(this.context));}
  approveXml():void {this.rawDrafts.delete(this.key(this.context));}
  discardDrafts():void {this.cancelPending();this.drafts.clear();this.rawDrafts.clear();}
  readonly drafts = new Map<string, {doc:DocModel;revision?:string;baseXml:string;apply:boolean}>();
  private sameLocation(a:EditContext,b:EditContext):boolean { return a.fileName===b.fileName && (a.locationId && b.locationId ? a.locationId===b.locationId : (a.declarationId??a.symbolId)===(b.declarationId??b.symbolId)); }
  private key(c: EditContext): string { return `${c.fileName}|${c.locationId??c.declarationId??c.symbolId}`; }
  setContext(element: ElementInfo): void {
    if(this.inFlight && (this.key(this.inFlight.context)!==this.key(element) || this.inFlight.context.sessionId!==element.sessionId))this.inFlight=null;
    this.cancelPending();
    this.readOnly = !!element.readOnly;this.readOnlyReason = element.readOnlyReason || 'Read-only source';
    this.context = { fileName: element.fileName, symbolId: element.symbolId, declarationId:element.declarationId,
      sessionId: element.sessionId, sourceRevision: element.sourceRevision,locationId:element.locationId,projectFile:element.projectFile };
    const draft=this.drafts.get(this.key(this.context));
    if(draft && draft.revision!==element.sourceRevision)this.context.sourceRevision=draft.revision;
  }
  prepareRecovery(element:ElementInfo):void {this.cancelPending();this.drafts.delete(this.key(element));this.rawDrafts.delete(this.key(element));this.setContext(element);}
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

      const flight=this.inFlight;
      if(message.editId && flight?.id!==message.editId)return;
      if (message.sessionId === this.context.sessionId) {
        if(message.status.startsWith('Read-only')){this.readOnly=true;this.readOnlyReason=message.status;this.cancelPending();window.dispatchEvent(new CustomEvent('sourceReadOnlyChanged'));}
        this.setStatus(message.status);
        if(message.status==='Applied' && flight && message.editId===flight.id){
          flight.applied=true;
          const draft=this.drafts.get(flight.key);
          if(draft && JSON.stringify(draft.doc)===JSON.stringify(flight.doc))this.drafts.delete(flight.key);
        } else if(message.status!=='Applied'){this.inFlight=null;if(flight)window.dispatchEvent(new CustomEvent('documentationWriteResult',{detail:{applied:false,editId:flight.id,message:message.status,context:flight.context}}));}

      }
      return;
    }
    if (message.type === 'loadDoc') {
      const element=message.data.element;
      const sameTarget=this.sameLocation(element,this.context);
      if (this.pinned && !sameTarget) { this.held = message; return; }
      this.localVersion++;
      const pending=this.pending?.type==='docUpdated' && this.key(this.pending)===this.key(element) && this.pending.sourceRevision===element.sourceRevision ? this.pending : null;
      const flight=this.inFlight;
      const rebase=!!(sameTarget && flight?.applied && this.sameLocation(flight.context,element));
      const interrupted=!!(flight&&!rebase&&(!sameTarget||flight.context.sessionId!==element.sessionId||flight.context.sourceRevision!==element.sourceRevision));
      if(interrupted)this.inFlight=null;
      const newer=rebase?this.drafts.get(flight!.key):undefined;
      if(rebase){this.inFlight=null;this.drafts.delete(flight!.key);}
      this.originalXml=message.data.doc.sourceXml??message.data.doc.rawXml??'';
      this.setContext(element);
      // Requeue the permitted write without replacing a newer, unapplied draft.
      if(pending && !rebase && !this.readOnly){
        this.pending={...pending,...this.context};
        this.timer=setTimeout(()=>this.flush(),Math.max(0,this.saveDebounceMs));
      }
      if(newer && !this.readOnly){
        this.drafts.set(this.key(this.context),{doc:newer.doc,revision:element.sourceRevision,baseXml:this.originalXml,apply:newer.apply});
        this.context.sourceRevision=element.sourceRevision;
        if(newer.apply)this.notifyDocChanged(newer.doc);
      }

      const draft = this.drafts.get(this.key(this.context));
      this.setStatus(this.readOnly ? this.readOnlyReason : draft ? 'Unsaved draft — source may have changed' : 'Applied');
      if(draft && draft.revision!==this.context.sourceRevision) this.context.sourceRevision=draft.revision;
      this.onElementLoadedListeners.forEach(cb => cb(message.data.element, (!this.readOnly && draft?.doc) || message.data.doc));
      if(interrupted)window.dispatchEvent(new CustomEvent('documentationWriteResult',{detail:{applied:false,editId:flight!.id,context:flight!.context,message:'Source changed — reload before applying'}}));
      if(rebase)window.dispatchEvent(new CustomEvent('documentationWriteResult',{detail:{applied:true,editId:flight!.id,context:flight!.context,element}}));
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
    if(this.inFlight)return;
    const pending = this.pending; this.cancelPending();
    if(pending.type==='docUpdated'){
      pending.editId=`${this.instanceId}:${++this.serial}`;
      this.inFlight={id:pending.editId,key:this.key(pending),context:{...pending},doc:pending.doc,applied:false};
    }
    if(pending.type==='docUpdated')window.dispatchEvent(new CustomEvent('documentationWriteStarted',{detail:{editId:pending.editId,doc:pending.doc}}));
    this.sendToHost(pending);
  }
  saveDraft(doc:DocModel):void {
    if(this.readOnly){this.setStatus(this.readOnlyReason);return;}
    this.localVersion++;
    const snapshot=JSON.parse(JSON.stringify(doc));const context={...this.context};
    const baseXml=this.drafts.get(this.key(context))?.baseXml??this.originalXml;
    if(snapshot.xmlEdited){const raw={xml:snapshot.rawXml??'',sourceRevision:context.sourceRevision,baseXml};this.rawDrafts.set(this.key(context),raw);snapshot.unappliedXml=raw;}
    this.drafts.set(this.key(context),{doc:snapshot,revision:context.sourceRevision,baseXml,apply:false});
    this.sendToHost({type:'draftUpdated',doc:snapshot,baseXml,applyAllowed:false,...context} as any);
    this.setStatus('Modified');
  }
  notifyDocChanged(doc: DocModel): void {
    if(this.readOnly){this.cancelPending();this.setStatus(this.readOnlyReason);return;}
    this.localVersion++;
    this.cancelPending();
    const snapshot = JSON.parse(JSON.stringify(doc));
    const context = { ...this.context };
    const baseXml=this.drafts.get(this.key(context))?.baseXml??this.originalXml;
    if(snapshot.xmlEdited){this.rawDrafts.delete(this.key(context));delete snapshot.unappliedXml;}
    else {const raw=this.rawDrafts.get(this.key(context))??snapshot.unappliedXml;if(raw){snapshot.unappliedXml=raw;this.rawDrafts.set(this.key(context),raw);}}
    this.drafts.set(this.key(context), {doc:snapshot,revision:context.sourceRevision,baseXml,apply:true});
    this.sendToHost({type:'draftUpdated',doc:snapshot,baseXml,applyAllowed:true,...context} as any);
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
