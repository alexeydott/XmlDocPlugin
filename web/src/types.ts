/** 코드 요소 종류 */
export type DocElementKind =
  | 'unit' | 'class' | 'record' | 'interface'
  | 'method' | 'property' | 'field' | 'type' | 'constant';

/** 파라미터 시그니처 정보 */
export interface ParamInfo {
  name: string;
  type: string;
  defaultValue?: string;
  isConst?: boolean;
  isVar?: boolean;
  isOut?: boolean;
}

/** 코드 요소 정보 (Delphi → WebView) */
export interface ElementInfo {
  projectFile?:string;
  readOnly?: boolean;
  readOnlyReason?: string;
  kind: DocElementKind;
  name: string;
  fullName?: string;
  symbolId?: string;
  canonicalName?:string;
  unitName?:string;
  locationId?:string;
  declarationId?:string;
  sessionId?: string;
  sourceRevision?: string;
  signature?: string;
  resourceBase?:string;
  ancestor?: string;
  implements?: string[];
  qualifiedParent?: string;
  methodKind?: string;
  methodBinding?:string;
  isReintroduce?:boolean;
  params: ParamInfo[];
  returnType?: string;
  genericParams?: string[];
  visibility?: string;
  lineNumber?: number;
  commentStartLine?:number;
  fileName?: string;
}

/** 파라미터 문서 */
export interface ParamDoc {
  name: string;
  description: string;
}

/** 제네릭 타입 파라미터 문서 */
export interface TypeParamDoc {
  name: string;
  description: string;
}

/** 예외 문서 */
export interface ExceptionDoc {
  typeRef: string;
  description: string;
}

/** 예제 문서 */
export interface ExampleDoc {
  source?:string;
  region?:string;
  title?: string;
  code?: string;
  description: string;
}

/** See Also 문서 */
export interface SeeAlsoDoc {
  cref: string;
  description?: string;
}

/** 문서 모델 (Delphi ↔ WebView JSON 프로토콜) */
export interface DocModel {
  summary: string;
  inheritedFrom?: string;
  sourceXml?: string;
  parseError?: string;
  parseErrorLine?:number;
  parseErrorColumn?:number;
  rawXml?: string;
  xmlEdited?: boolean;
  renameMappings?:Record<string,string>;
  remarks?: string;
  returns?: string;
  value?: string;
  params?: ParamDoc[];
  typeParams?: TypeParamDoc[];
  exceptions?: ExceptionDoc[];
  examples?: ExampleDoc[];
  seeAlso?: SeeAlsoDoc[];
}

/** 트리용 요소 정보 (요소 + 문서 데이터 포함) */
export interface TreeElementInfo extends ElementInfo {
  searchText?:string;
  doc: DocModel;
  effectiveDoc?:DocModel;
}

/** Delphi → WebView 메시지 */
export type InboundMessage =
  | { type: 'editResult'; sessionId: string; status: string; editId?:string }
  | { type: 'loadDoc'; data: { element: ElementInfo; doc: DocModel } }
  | { type: 'elementChanged'; data: { element: ElementInfo } }
  | { type: 'loadTree'; data: { fileName: string; elements: TreeElementInfo[] } };

/** WebView → Delphi 메시지 */
export type OutboundMessage =
  | { type: 'pin'; pinned:boolean }
  | { type:'requestRefresh' }
  | { type:'requestCatalog'; scope:'module'|'project'|'group' }
  | { type:'openSymbol'; locationId?:string; fileName:string; symbolId:string; line:number;projectFile?:string }
  | { type:'copySelection' }
  | { type: 'sectionStateChanged'; sections: Record<string, boolean> }
  | ({ type: 'docUpdated'; doc: DocModel; editId?:string } & Pick<ElementInfo, 'fileName' | 'symbolId' | 'declarationId' | 'sessionId' | 'sourceRevision'>)
  | { type: 'jumpToLine'; line: number }
  | { type: 'requestAutoComplete'; prefix: string; context: string };
