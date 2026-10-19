/// <summary>Common rendering interface and output options.</summary>
unit XmlDoc.HelpGen.Renderer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef;

type
  /// <summary>Documentation output options shared by renderers.</summary>
  TRenderOptions = record
    NumericFileNames: Boolean;
    CSSTheme: string;
    FooterText: string;
    IncludeInheritanceTree: Boolean;
    IncludePrivate: Boolean;
    IncludeSearchIndex: Boolean;
    IncludeSource: Boolean;
    LogoPath: string;
    OutputDir: string;
    ProjectName: string;
    ProjectDir:string;
    Title: string;
  end;

  /// <summary>Common interface for documentation renderers.</summary>
  IDocRenderer = interface
    ['{B3F5C2A1-8D4E-47F9-A2C1-6E3B5D8F1A2C}']
    procedure Render(
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const AOptions: TRenderOptions
    );
  end;

implementation

end.
