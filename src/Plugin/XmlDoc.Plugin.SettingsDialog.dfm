object SettingsDialog: TSettingsDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'XmlDoc Plugin Settings'
  ClientHeight = 520
  ClientWidth = 464
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 464
    Height = 475
    ActivePage = tsGeneral
    Align = alTop
    TabOrder = 0
    object tsGeneral: TTabSheet
      Caption = 'General'
      object btnAISettings: TButton
        Left = 16
        Top = 184
        Width = 428
        Height = 30
        Caption = 'AI profiles and prompts'
        TabOrder = 4
        OnClick = AISettingsClick
      end
      object lblTheme: TLabel
        Left = 16
        Top = 16
        Width = 40
        Height = 15
        Caption = 'Theme follows the IDE'
      end
      object lblFontSize: TLabel
        Left = 16
        Top = 48
        Width = 50
        Height = 15
        Caption = 'Font Size:'
      end
      object lblLanguage: TLabel
        Left = 16
        Top = 80
        Width = 55
        Height = 15
        Caption = 'Language:'
      end
      object spnFontSize: TSpinEdit
        Left = 232
        Top = 46
        Width = 80
        Height = 24
        MaxValue = 32
        MinValue = 8
        TabOrder = 0
        Value = 13
      end
      object cmbLanguage: TComboBox
        Left = 232
        Top = 78
        Width = 160
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 1
        Text = 'auto'
        Items.Strings = (
          'auto'
          'en'
          'ko'
          'ja'
          'ru'
          'zh')
      end
      object chkCollapseEmptySections: TCheckBox
        Left = 16
        Top = 118
        Width = 428
        Height = 17
        Caption = 'Collapse empty sections'
        TabOrder = 2
      end
      object chkShowSignatureHeader: TCheckBox
        Left = 16
        Top = 144
        Width = 428
        Height = 17
        Caption = 'Show signature header'
        TabOrder = 3
      end
    end
    object tsCodeGen: TTabSheet
      Caption = 'Code Generation'
      ImageIndex = 1
      object lblPlaceholderPrefix: TLabel
        Left = 16
        Top = 56
        Width = 97
        Height = 15
        Caption = 'Placeholder Prefix:'
      end
      object chkAutoGenerate: TCheckBox
        Left = 16
        Top = 16
        Width = 428
        Height = 17
        Caption = 'Generate a stub after typing ///'
        TabOrder = 0
      end
      object edtPlaceholderPrefix: TEdit
        Left = 232
        Top = 54
        Width = 200
        Height = 23
        TabOrder = 1
      end
      object lblPlaceholderMarkers: TLabel
        Left = 16
        Top = 88
        Caption = 'Unfinished documentation markers:'
      end
      object memPlaceholderMarkers: TMemo
        Left = 16
        Top = 110
        Width = 416
        Height = 108
        ScrollBars = ssVertical
        TabOrder = 2
        ShowHint = True
        Hint = 'One marker per line. The generated prefix and TODO are always recognized.'
      end
      object lblDocumentationTheme: TLabel
        Left = 16
        Top = 236
        Caption = 'Default HTML / CHM theme:'
      end
      object cmbDocumentationTheme: TComboBox
        Left = 232
        Top = 234
        Width = 200
        Height = 23
        Style = csDropDownList
        TabOrder = 3
        ShowHint = True
        Hint = 'A project htmlTheme setting can override this default.'
      end
      object btnCreateTheme: TButton
        Left = 16
        Top = 272
        Width = 190
        Height = 28
        Caption = 'Create CSS theme...'
        TabOrder = 4
        OnClick = btnCreateThemeClick
      end
      object lblThemeOverride: TLabel
        Left = 16
        Top = 310
        Width = 410
        Height = 48
        AutoSize = False
        WordWrap = True
        Caption = 'The generation dialog shows the effective theme, including any project override.'
      end
    end
    object tsShortcuts: TTabSheet
      Caption = 'Shortcuts'
      ImageIndex = 2
      object lblToggleInspector: TLabel
        Left = 16
        Top = 16
        Width = 91
        Height = 15
        Caption = 'Toggle Inspector:'
      end
      object lblGenerateStub: TLabel
        Left = 16
        Top = 52
        Width = 77
        Height = 15
        Caption = 'Generate Stub:'
      end
      object lblGenerateHelp: TLabel
        Left = 16
        Top = 88
        Width = 78
        Height = 15
        Caption = 'Generate Help:'
      end
      object lblCoverageReport: TLabel
        Left = 16
        Top = 124
        Width = 91
        Height = 15
        Caption = 'Coverage Report:'
      end
      object lblNextUndocumented: TLabel
        Left = 16
        Top = 160
        Width = 113
        Height = 15
        Caption = 'Next Undocumented:'
      end
      object lblPreviousUndocumented: TLabel
        Left = 16
        Top = 196
        Width = 134
        Height = 15
        Caption = 'Previous Undocumented:'
      end
      object hotToggleInspector: THotKey
        Left = 170
        Top = 14
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 0
      end
      object hotGenerateStub: THotKey
        Left = 170
        Top = 50
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 1
      end
      object hotGenerateHelp: THotKey
        Left = 170
        Top = 86
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 2
      end
      object hotCoverageReport: THotKey
        Left = 170
        Top = 122
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 3
      end
      object hotNextUndocumented: THotKey
        Left = 170
        Top = 158
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 4
      end
      object hotPreviousUndocumented: THotKey
        Left = 170
        Top = 194
        Width = 240
        Height = 23
        HotKey = 32833
        TabOrder = 5
      end
    end
    object tsHelpInsight: TTabSheet
      Caption = 'Help Insight'
      object chkHelpInsightEnabled: TCheckBox
        Left = 16
        Top = 16
        Width = 420
        Height = 22
        Caption = 'Customize native Help Insight'
        TabOrder = 0
        OnClick = HelpInsightChanged
      end
      object lblHintAppearance: TLabel
        Left = 16
        Top = 52
        Caption = 'Hint appearance:'
      end
      object cmbHintAppearance: TComboBox
        Left = 288
        Top = 48
        Width = 144
        Height = 23
        Style = csDropDownList
        OnChange = HelpInsightChanged
        TabOrder = 9
        Items.Strings = (
          'IDE default'
          'Extended')
      end
      object btnHintPreview: TButton
        Left = 16
        Top = 416
        Width = 200
        Height = 26
        Caption = 'Preview hint...'
        TabOrder = 10
        OnClick = HintPreviewClick
      end
      object btnRestoreHint: TButton
        Left = 232
        Top = 416
        Width = 200
        Height = 26
        Caption = 'Restore original templates'
        TabOrder = 11
        OnClick = RestoreHintClick
      end
      object lblHintWidth: TLabel
        Left = 16
        Top = 94
        Caption = 'Hint width (px):'
      end
      object spnHintWidth: TSpinEdit
        Left = 288
        Top = 90
        Width = 100
        Height = 24
        MinValue = 360
        MaxValue = 1200
        Increment = 40
        Value = 720
        TabOrder = 1
      end
      object lblHintFont: TLabel
        Left = 16
        Top = 126
        Caption = 'Hint font size (pt):'
      end
      object spnHintFontSize: TSpinEdit
        Left = 288
        Top = 122
        Width = 100
        Height = 24
        MinValue = 8
        MaxValue = 18
        Value = 9
        TabOrder = 2
      end
      object lblHintLineHeight: TLabel
        Left = 16
        Top = 158
        Caption = 'Line spacing (%):'
      end
      object spnHintLineHeight: TSpinEdit
        Left = 288
        Top = 154
        Width = 100
        Height = 24
        MinValue = 100
        MaxValue = 180
        Increment = 5
        Value = 125
        TabOrder = 3
      end
      object chkHelpInsightWrap: TCheckBox
        Left = 16
        Top = 192
        Width = 420
        Height = 22
        Caption = 'Wrap long signatures'
        TabOrder = 4
      end
      object chkHelpInsightCompact: TCheckBox
        Left = 16
        Top = 224
        Width = 420
        Height = 22
        Caption = 'Compact parameter descriptions'
        TabOrder = 5
        OnClick = HelpInsightChanged
      end
      object lblHintParameterWidth: TLabel
        Left = 16
        Top = 262
        Caption = 'Parameter name column (px):'
      end
      object spnHintParameterWidth: TSpinEdit
        Left = 288
        Top = 258
        Width = 100
        Height = 24
        MinValue = 80
        MaxValue = 400
        Increment = 10
        Value = 160
        TabOrder = 6
      end
      object lblHintNote: TLabel
        Left = 16
        Top = 290
        Width = 416
        Height = 56
        AutoSize = False
        WordWrap = True
        Caption = 'Template changes require restarting the IDE. CSS follows the current IDE theme. Disable or restore to return to the original template.'
      end
      object btnExportHintCss: TButton
        Left = 16
        Top = 350
        Width = 200
        Height = 26
        Caption = 'Export templates...'
        TabOrder = 7
        OnClick = ExportHintCssClick
      end
      object lblHintStatus: TLabel
        Left = 16
        Top = 382
        Width = 416
        Height = 30
        AutoSize = False
        WordWrap = True
        ShowHint = True
      end
      object btnShellHintCss: TButton
        Left = 232
        Top = 350
        Width = 200
        Height = 26
        Caption = 'Apply through Windows...'
        TabOrder = 8
        OnClick = ShellHintCssClick
      end
    end
    object tsAdvanced: TTabSheet
      Caption = 'Advanced'
      ImageIndex = 3
      object lblDebounceMs: TLabel
        Left = 16
        Top = 16
        Width = 84
        Height = 15
        Caption = 'Debounce (ms):'
      end
      object lblSaveDebounceMs: TLabel
        Left = 16
        Top = 52
        Width = 111
        Height = 15
        Caption = 'Save Debounce (ms):'
      end
      object lblLogLevel: TLabel
        Left = 16
        Top = 88
        Width = 53
        Height = 15
        Caption = 'Log Level:'
      end
      object spnDebounceMs: TSpinEdit
        Left = 150
        Top = 14
        Width = 100
        Height = 24
        Increment = 50
        MaxValue = 5000
        MinValue = 50
        TabOrder = 0
        Value = 300
      end
      object spnSaveDebounceMs: TSpinEdit
        Left = 150
        Top = 50
        Width = 100
        Height = 24
        Increment = 100
        MaxValue = 10000
        MinValue = 100
        TabOrder = 1
        Value = 500
      end
      object cmbLogLevel: TComboBox
        Left = 150
        Top = 86
        Width = 120
        Height = 23
        Style = csDropDownList
        ItemIndex = 1
        TabOrder = 2
        Text = 'Info'
        Items.Strings = (
          'Debug'
          'Info'
          'Warn'
          'Error'
          'Fatal')
      end
    end
  end
  object btnOK: TButton
    Left = 296
    Top = 484
    Width = 80
    Height = 28
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 382
    Top = 484
    Width = 80
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
end
