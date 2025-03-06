unit MainFrm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.IniFiles,
  System.SyncObjs,
  System.DateUtils,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  ShellLogThreadManager,
  ICoreInterface,
  ILogInterface,
  IShellInterface,
  Vcl.ExtDlgs;

const
  LogSource = 'Shell';
  IniFile = 'shell_win_vcl.ini';
  IniMain = 'Main';
  IniMainHWID = 'HWID';

type
  PMemoEdit = ^TRichEdit;

type
  PStatusBar = ^TStatusBar;

type
  PMainMenu = ^TMainMenu;

type
  TSetShellCaption = procedure(Caption: string) of object;

type
  TMMItem = class(TInterfacedObject, IShellMainMenu)
  private
    FMenuItem: TMenuItem;
    FItems: TList<IShellMainMenuItem>;
    procedure OnClick(Sender: TObject);
  public
    constructor Create(Owner: TMainMenu; Caption: string);
    destructor Destroy; override;
    procedure AddMenuItem(Item: IShellMainMenuItem); stdcall;
    procedure RemoveMenuItem(Item: IShellMainMenuItem); stdcall;
    property MenuItem: TMenuItem read FMenuItem;
  end;

type
  TShell = class(TInterfacedObject, IShell, ILog, IShellBasicControl)
  private
    FLogDebug: Boolean;
    FLogThread: TLogThread;
    FMemoEdit: PMemoEdit;
    FStatusBar: PStatusBar;
    FMainMenu: PMainMenu;
    FOnSetShellCaption: TSetShellCaption;
    function GetLogLineType(LogType: TLogType): string;
    procedure Log(LogSource, LogText: WideString; LogType: TLogType); stdcall;
    procedure LogTagged(LogSource, LogTag, LogText: WideString; LogType: TLogType); stdcall;
    procedure RemoveQueuedEvents(AThread: TThread); stdcall;
    procedure Processmessages; stdcall;
    procedure LogToMemo(AText: string; LogType: TLogType);
    procedure SetLogThread(const ALogThread: TLogThread);
  public
    constructor Create(MemoEdit: PMemoEdit; StatusBar: PStatusBar; MainMenu: PMainMenu);
    destructor Destroy; override;
    procedure SetShellCaption(Text: WideString); stdcall;
    procedure SetStatusBarText(Text: WideString); stdcall;
    function AddMainMenu(Title: WideString): IShellMainMenu; stdcall;
    property OnSetShellCaption: TSetShellCaption read FOnSetShellCaption write FOnSetShellCaption;
    property LogDebug: Boolean read FLogDebug write FLogDebug;
    property LogThread: TLogThread read FLogThread write SetLogThread;
  end;

type
  TMainForm = class(TForm)
    statBar: TStatusBar;
    mm: TMainMenu;
    mmoLog: TRichEdit;
    tmrStartDelay: TTimer;
    File1: TMenuItem;
    mmLog: TMenuItem;
    mmExit: TMenuItem;
    mmLogExport: TMenuItem;
    N1: TMenuItem;
    mmLogDebug: TMenuItem;
    svtxtfldlg: TSaveTextFileDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure mmExitClick(Sender: TObject);
    procedure mmLogExportClick(Sender: TObject);
    procedure mmLogDebugClick(Sender: TObject);
  private
    { Private declarations }
    FLogThread: TLogThread;
    FShell: TShell;
    procedure LogInfoLine(Text: string);
    procedure SetFormCaption(Caption: string);
    procedure StartCore(Sender: TObject);
    procedure Terminate(Sender: TObject);
  public
    { Public declarations }
  end;

type
  TStartCore = function(const AShell: IShell): ICore; stdcall;

var
  MainForm: TMainForm;
  AppDir, CoreFilePath: string;
  Ini: TIniFile;
  CoreHandle: Cardinal;
  Inp: string;
  FCS: TCriticalSection;
  Core: ICore;
  Modules: IModules;
  //

implementation

function LogTime: string;
var
  myDate: TDateTime;
  myYear, myMonth, myDay: Word;
  myHour, myMin, mySec, myMilli: Word;
begin
  myDate := Now;
  DecodeDateTime(myDate, myYear, myMonth, myDay, myHour, myMin, mySec, myMilli);
  Result := Format('%d/%d/%d %d:%d:%d.%d', [myDay, myMonth, myYear, myHour, myMin, mySec, myMilli]);
end;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  AppDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  FCS := TCriticalSection.Create;
  tmrStartDelay.OnTimer := StartCore;
  tmrStartDelay.Enabled := True;
  FLogThread := TLogThread.Create;
end;

procedure TMainForm.StartCore(Sender: TObject);
var
  StartFunc: TStartCore;
  Itf: IInterface;
begin
  tmrStartDelay.Enabled := False;
  if not FileExists(AppDir + IniFile) then
  begin
    LogInfoLine('Shell:(Error) -> Config file not found: ' + AppDir + IniFile);
    exit;
  end;
  Ini := TIniFile.Create(AppDir + IniFile);
  CoreFilePath := Ini.ReadString('Core', 'File', 'Core.dll');
  if not FileExists(CoreFilePath) then
  begin
    LogInfoLine('Shell:(Error) -> Core library file not found: ' + CoreFilePath);
    exit;
  end;
  LogInfoLine('Shell:(Info) -> Loading Core: ' + CoreFilePath);
  try
    CoreHandle := SafeLoadLibrary(CoreFilePath);
    if CoreHandle = 0 then
      raise Exception.Create('Error loading core module (zero handle): ' + CoreFilePath);
    StartFunc := GetProcAddress(CoreHandle, 'StartCore');
    if not Assigned(StartFunc) then
      raise Exception.Create('Error loading core module (Init Prcedure entry point not found): ' + CoreFilePath);
    FShell := TShell.Create(@mmoLog, @statBar, @mm);
    FShell.OnSetShellCaption := SetFormCaption;
    FShell.LogThread := FLogThread;
    Itf := StartFunc(FShell);
    if not Assigned(Itf) then
      raise Exception.Create('Core interface not found');
    if not Supports(Itf, ICore, Core) then
      raise Exception.Create('Core interface not supported');
  except
    on E: Exception do
    begin
      LogInfoLine('Shell:(Error) -> Loading Core: ' + E.Message);
      { TODO : Unload core }
      // Itf := nil;
      // Core := nil;
      // if CoreHandle <> 0 then
      // FreeLibrary(CoreHandle);
      // FShell.Free;
      exit;
    end;
  end;
  LogInfoLine('Shell:(Info) -> Message loop started...');

end;

procedure TMainForm.LogInfoLine(Text: string);
begin
  mmoLog.Lines.Add(LogTime + ' ' + Text);
end;

procedure TMainForm.mmExitClick(Sender: TObject);
begin
  var
    Close: Boolean;
  FormCloseQuery(Self, Close);
end;

procedure TMainForm.mmLogDebugClick(Sender: TObject);
begin
  mmLogDebug.Checked := not mmLogDebug.Checked;
  FShell.LogDebug := mmLogDebug.Checked;
end;

procedure TMainForm.mmLogExportClick(Sender: TObject);
var
  LPath: string;
begin
  svtxtfldlg.Execute;
  LPath := svtxtfldlg.FileName;
  if LPath.Length > 0 then
    try
      mmoLog.PlainText := True;
      mmoLog.Lines.SaveToFile(LPath + '.txt');
    except
      on E: Exception do
        LogInfoLine('Save log to file: ' + E.Message);
    end;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := False;
  LogInfoLine('Terminating application');
  Modules := nil;
  if Assigned(Core) then
    Core.ShutDown;
  Core := nil; // Core must have refCount =1 before this line
  if CoreHandle <> 0 then
    FreeLibrary(CoreHandle);
  FLogThread.OnTerminate := Terminate;
  FLogThread.Terminate;
end;

procedure TMainForm.Terminate(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Ini.Free;
  FLogThread.Free;
  FCS.Free;
end;

procedure TMainForm.SetFormCaption(Caption: string);
begin
  Self.Caption := Caption;
end;

{ FShell }

constructor TShell.Create(MemoEdit: PMemoEdit; StatusBar: PStatusBar; MainMenu: PMainMenu);
begin
  FLogDebug := True;
  FMemoEdit := MemoEdit;
  FStatusBar := StatusBar;
  FMainMenu := MainMenu;
end;

destructor TShell.Destroy;
begin
  inherited;
end;

function TShell.GetLogLineType(LogType: TLogType): string;
begin
  case LogType of
    tlgInfo:
      Result := 'Info';
    tlgWarning:
      Result := 'Warning';
    tlgError:
      Result := 'Error';
    tlgDebug:
      Result := 'Debug';
  end;
end;

procedure TShell.Log(LogSource, LogText: WideString; LogType: TLogType);
var
  thread: TThread;
begin
  if (not FLogDebug) and (LogType = tlgDebug) then
    exit;

  if GetCurrentThreadId = MainThreadID then
    LogToMemo(Format('%s:(%s) -> %s', [LogSource, GetLogLineType(LogType), LogText]), LogType)
  else
    FLogThread.Log(LogSource, LogText, LogType);
end;

procedure TShell.LogTagged(LogSource, LogTag, LogText: WideString; LogType: TLogType);
var
  thread: TThread;
begin
  if (not FLogDebug) and (LogType = tlgDebug) then
    exit;

  if GetCurrentThreadId = MainThreadID then
    LogToMemo(Format('%s:(%s) %s -> %s', [LogSource, GetLogLineType(LogType), LogTag, LogText]), LogType)
  else
    FLogThread.Log(LogSource, LogTag, LogText, LogType);
end;

procedure TShell.LogToMemo(AText: string; LogType: TLogType);
var
  lColor: Integer;
begin
  case LogType of
    tlgInfo:
      lColor := clBlack;
    tlgWarning:
      lColor := clBlue;
    tlgError:
      lColor := clRed;
    tlgDebug:
      lColor := clGreen;
    else lColor := clBlack;
  end;
  FMemoEdit^.SelAttributes.color := lColor;
  FMemoEdit^.Lines.Add(AText);
end;

procedure TShell.Processmessages;
begin
  Application.Processmessages;
end;

procedure TShell.RemoveQueuedEvents(AThread: TThread);
begin
  TThread.CurrentThread.RemoveQueuedEvents(AThread);
end;

procedure TShell.SetLogThread(const ALogThread: TLogThread);
begin
  FLogThread := ALogThread;
  FLogThread.LogToMemoProc := LogToMemo;
end;

procedure TShell.SetShellCaption(Text: WideString);
begin
  if Assigned(FOnSetShellCaption) then
    FOnSetShellCaption(Text);
end;

procedure TShell.SetStatusBarText(Text: WideString);
begin
  FStatusBar^.SimpleText := Text;
end;

function TShell.AddMainMenu(Title: WideString): IShellMainMenu;
var
  Item: TMMItem;
begin
  Item := TMMItem.Create(FMainMenu^, Title);
  FMainMenu^.Items.Add(Item.MenuItem);
  Result := Item;
end;

{ TMMItem }

constructor TMMItem.Create(Owner: TMainMenu; Caption: string);
begin
  FMenuItem := TMenuItem.Create(Owner);
  FMenuItem.Caption := Caption;
  FItems := TList<IShellMainMenuItem>.Create;
end;

destructor TMMItem.Destroy;
var
  c: Integer;
begin
  (FMenuItem.Owner as TMainMenu).Items.Remove(FMenuItem);
  FMenuItem.Free;
  for c := 0 to FItems.Count - 1 do
    FItems.Items[c] := nil;
  FItems.Free;
  inherited;
end;

procedure TMMItem.AddMenuItem(Item: IShellMainMenuItem);
var
  mItem: TMenuItem;
begin
  mItem := TMenuItem.Create(FMenuItem);
  mItem.Caption := Item.Title;
  mItem.Tag := FItems.Add(Item);
  mItem.OnClick := OnClick;
  FMenuItem.Add(mItem);
end;

procedure TMMItem.RemoveMenuItem(Item: IShellMainMenuItem);
var
  index: Integer;
begin
  index := FItems.IndexOf(Item);
  if index < 0 then
    exit;
  FMenuItem.Delete(index);
  FItems.Remove(Item);
end;

procedure TMMItem.OnClick(Sender: TObject);
var
  index: Integer;
begin
  index := (Sender as TMenuItem).Tag;
  FItems.Items[index].OnClick;
end;

end.
