unit XmlDoc.CodeGen;

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  /// <summary>DocModel을 /// 주석 문자열로 변환하여 소스에 삽입합니다.</summary>
  TDocCodeGenerator = class
  private
    class function BuildIndent(AIndent: Integer): string;
    class function WrapLine(const APrefix, AText: string; AMaxWidth: Integer): string;
  public
    /// <summary>모델을 /// 주석 블록 문자열로 변환합니다.</summary>
    /// <param name="AModel">변환할 문서 모델</param>
    /// <param name="AIndent">들여쓰기 칸 수 (기본: 2)</param>
    /// <returns>/// 프리픽스가 포함된 주석 블록 문자열</returns>
    class function ModelToCommentBlock(const AModel: TXmlDocModel; AIndent: Integer = 2): string;

    /// <summary>주석 블록을 소스 텍스트에 적용합니다 (순수 문자열 기반).</summary>
    /// <param name="ASource">원본 소스 코드 전체</param>
    /// <param name="AElement">대상 코드 요소 정보</param>
    /// <param name="AModel">적용할 문서 모델</param>
    /// <returns>주석이 적용된 새 소스 코드</returns>
    class function ApplyToSourceText(const ASource: string; const AElement: TCodeElementInfo; const AModel: TXmlDocModel): string;
  end;

implementation

{ TDocCodeGenerator }

class function TDocCodeGenerator.BuildIndent(AIndent: Integer): string;
begin
  Result := StringOfChar(' ', AIndent);
end;

class function TDocCodeGenerator.WrapLine(const APrefix, AText: string; AMaxWidth: Integer): string;
var
  LWords: TArray<string>;
  LCurrentLine: string;
  LSB: TStringBuilder;
  LWord: string;
  I: Integer;
begin
  if Length(APrefix + AText) <= AMaxWidth then
  begin
    Result := APrefix + AText;
    Exit;
  end;

  LWords := AText.Split([' ']);
  LSB := TStringBuilder.Create;
  try
    LCurrentLine := APrefix;
    for I := 0 to High(LWords) do
    begin
      LWord := LWords[I];
      if (LCurrentLine <> APrefix) and
         (Length(LCurrentLine) + 1 + Length(LWord) > AMaxWidth) then
      begin
        LSB.AppendLine(LCurrentLine);
        LCurrentLine := APrefix + LWord;
      end
      else
      begin
        if LCurrentLine = APrefix then
          LCurrentLine := LCurrentLine + LWord
        else
          LCurrentLine := LCurrentLine + ' ' + LWord;
      end;
    end;

    if LCurrentLine <> APrefix then
      LSB.Append(LCurrentLine);

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

class function TDocCodeGenerator.ModelToCommentBlock(const AModel:TXmlDocModel; AIndent:Integer):string;
var Line:string;SB:TStringBuilder;
begin
  if AModel.IsEmpty then Exit('');
  SB:=TStringBuilder.Create;
  try
    for Line in AModel.ToXml.Replace(#13#10,#10).Replace(#13,#10).Split([#10]) do
      if Line='' then SB.AppendLine(BuildIndent(AIndent)+'///')
      else SB.AppendLine(BuildIndent(AIndent)+'/// '+Line);
    Result:=SB.ToString;
  finally SB.Free;end;
end;

class function TDocCodeGenerator.ApplyToSourceText(const ASource: string; const AElement: TCodeElementInfo; const AModel: TXmlDocModel): string;
var
  LLines: TStringList;
  LCommentBlock: string;
  LCommentLines: TStringList;
  LInsertLine: Integer;
  I: Integer;
begin
  if (AModel.SourceXml<>'') and (AModel.ToXml=AElement.ExistingDocXml) then Exit(ASource);
  LLines := TStringList.Create;
  try
    LLines.Text := ASource;
    LCommentBlock := ModelToCommentBlock(AModel, AElement.IndentLevel);

    if LCommentBlock = '' then
    begin
      // 빈 모델: 기존 주석만 제거
      if AElement.CommentStartLine >= 0 then
      begin
        for I := AElement.CommentEndLine - 1 downto AElement.CommentStartLine - 1 do
        begin
          if (I >= 0) and (I < LLines.Count) then
            LLines.Delete(I);
        end;
      end;
      Result := LLines.Text;
      Exit;
    end;

    LCommentLines := TStringList.Create;
    try
      LCommentLines.Text := LCommentBlock;
      // 마지막 빈 줄 제거 (Text 할당으로 생기는 빈 줄)
      while (LCommentLines.Count > 0) and (Trim(LCommentLines[LCommentLines.Count - 1]) = '') do
        LCommentLines.Delete(LCommentLines.Count - 1);

      if AElement.CommentStartLine >= 0 then
      begin
        // 기존 주석 교체: CommentStartLine ~ CommentEndLine (1-based)
        for I := AElement.CommentEndLine - 1 downto AElement.CommentStartLine - 1 do
        begin
          if (I >= 0) and (I < LLines.Count) then
            LLines.Delete(I);
        end;
        LInsertLine := AElement.CommentStartLine - 1;
      end
      else
      begin
        // 새 주석 삽입: 코드 요소 직전 (1-based LineNumber)
        LInsertLine := AElement.LineNumber - 1;
      end;

      // 주석 줄 삽입
      for I := 0 to LCommentLines.Count - 1 do
      begin
        if LInsertLine + I <= LLines.Count then
          LLines.Insert(LInsertLine + I, LCommentLines[I])
        else
          LLines.Add(LCommentLines[I]);
      end;
    finally
      LCommentLines.Free;
    end;

    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

end.
