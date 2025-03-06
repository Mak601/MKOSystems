object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Main'
  ClientHeight = 354
  ClientWidth = 718
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = mm
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    718
    354)
  TextHeight = 13
  object statBar: TStatusBar
    Left = 0
    Top = 335
    Width = 718
    Height = 19
    Panels = <>
    SimplePanel = True
    ExplicitTop = 302
    ExplicitWidth = 704
  end
  object mmoLog: TRichEdit
    Left = 8
    Top = 8
    Width = 702
    Height = 321
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object mm: TMainMenu
    Left = 32
    Top = 40
    object File1: TMenuItem
      Caption = 'File'
      object mmLog: TMenuItem
        Caption = 'Log'
        object mmLogExport: TMenuItem
          Caption = 'Export'
          OnClick = mmLogExportClick
        end
        object N1: TMenuItem
          Caption = '-'
        end
        object mmLogDebug: TMenuItem
          Caption = 'Log Debug'
          Checked = True
          OnClick = mmLogDebugClick
        end
      end
      object mmExit: TMenuItem
        Caption = 'Exit'
        OnClick = mmExitClick
      end
    end
  end
  object tmrStartDelay: TTimer
    Enabled = False
    Interval = 500
    Left = 80
    Top = 40
  end
  object svtxtfldlg: TSaveTextFileDialog
    Filter = 'txt|*.txt'
    ShowEncodingList = False
    Left = 160
    Top = 40
  end
end
