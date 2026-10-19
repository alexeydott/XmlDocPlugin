/// <summary>Localization of native plugin controls and menu text.</summary>
unit XmlDoc.Plugin.Localization;
interface
uses System.Classes;
procedure LocalizePluginUi(Component:TComponent);
implementation
uses XmlDoc.I18n,XmlDoc.Plugin.Settings;
procedure LocalizePluginUi(Component:TComponent);
begin
 TI18n.Instance.SetLanguage(TPluginSettings.Instance.Global.General.Language);TI18n.Instance.TranslateComponent(Component);
end;
end.
