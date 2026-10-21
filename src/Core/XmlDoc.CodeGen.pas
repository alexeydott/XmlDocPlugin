/// <summary>Documentation comment rendering and source-text replacement.</summary>
unit XmlDoc.CodeGen;

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  /// <summary>Renders documentation comments and applies them to source text.</summary>
  TDocCodeGenerator = class
  private
    class function BuildIndent(AIndent: Integer): string;
    class function WrapLine(const APrefix, AText: string; AMaxWidth: Integer): string;
  public
    /// <summary>Renders a model as an indented triple-slash comment block.</summary>
    /// <param name="AModel">Documentation model to render.</param>
    /// <param name="AIndent">Number of indentation spaces; defaults to 2.</param>
    /// <returns>Comment lines prefixed with triple slashes.</returns>
    class function ModelToCommentBlock(const AModel: TXmlDocModel; AIndent: Integer = 2): string;

    /// <summary>Returns source text with the declaration's documentation replaced or inserted.</summary>
    /// <param name="ASource">Complete original source text.</param>
    /// <param name="AElement">Target declaration and source location.</param>
    /// <param name="AModel">Documentation model to apply.</param>
    /// <returns>Source text with the documentation change applied.</returns>
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
  if not AElement.IsLegacyComment and (AModel.SourceXml<>'') and (AModel.ToXml=AElement.ExistingDocXml) then Exit(ASource);
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
