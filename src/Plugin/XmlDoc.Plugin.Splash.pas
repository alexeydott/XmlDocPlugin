/// <summary>IDE startup branding with the package's shared file version.</summary>
unit XmlDoc.Plugin.Splash;

interface

/// <summary>Register the splash entry once, when the IDE service is available.</summary>
procedure RegisterPluginSplash;
/// <summary>Return the caption successfully registered with the IDE.</summary>
function RegisteredSplashCaption: string;

implementation

uses
  System.Classes, System.SysUtils, Winapi.Windows, Vcl.Graphics,
  Vcl.Imaging.pngimage, ToolsAPI, XmlDoc.Plugin.Utils;

{$R XmlDocSplash.res}

var
  RegistrationCaption: string;

function RegisteredSplashCaption: string;
begin
  Result := RegistrationCaption;
end;

procedure RegisterPluginSplash;
const
  Sizes: array[0..2] of Integer = (24, 48, 96);
var
  Images: TGraphicArray;
  Resource: TResourceStream;
  Caption: string;
  I: Integer;
begin
  if (RegistrationCaption <> '') or not Assigned(SplashScreenServices) then
    Exit;
  Caption := 'XmlDocPlugin ' + GetModuleVersion;
  SetLength(Images, Length(Sizes));
  try
    for I := 0 to High(Sizes) do
    begin
      Images[I] := TPngImage.Create;
      Resource := TResourceStream.Create(HInstance,
        'XMLDOC_SPLASH_' + IntToStr(Sizes[I]), RT_RCDATA);
      try
        Images[I].LoadFromStream(Resource);
      finally
        Resource.Free;
      end;
    end;
    // The DPI-aware OTA overload copies the images; keep no IDE interfaces
    // or image objects alive for package shutdown.
    SplashScreenServices.AddPluginBitmap(Caption, Images);
    SplashScreenServices.StatusMessage(Caption);
    RegistrationCaption := Caption;
  finally
    for I := 0 to High(Images) do
      Images[I].Free;
  end;
end;

initialization
  RegisterPluginSplash;
end.
