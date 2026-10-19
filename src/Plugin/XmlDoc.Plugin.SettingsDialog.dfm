object SettingsDialog: TSettingsDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'XmlDoc Plugin Settings'
  ClientHeight = 410
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
    Height = 365
    ActivePage = tsGeneral
    Align = alTop
    TabOrder = 0
    object tsGeneral: TTabSheet
      Caption = 'General'
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
      object lblDocumentationTheme: TLabel
        Left = 16
        Top = 100
        Caption = 'Default HTML / CHM theme:'
      end
      object cmbDocumentationTheme: TComboBox
        Left = 232
        Top = 98
        Width = 200
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        ShowHint = True
        Hint = 'A project htmlTheme setting can override this default.'
      end
      object btnCreateTheme: TButton
        Left = 16
        Top = 138
        Width = 190
        Height = 28
        Caption = 'Create CSS theme...'
        TabOrder = 3
        OnClick = btnCreateThemeClick
      end
      object lblThemeOverride: TLabel
        Left = 16
        Top = 180
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
    Top = 375
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
    Top = 375
    Width = 80
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
end
