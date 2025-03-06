library shell_exec;

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF }
  System.IniFiles,
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  IModuleInterface,
  ICoreInterface,
  IShellInterface,
  ILogInterface,
  Config in 'Config.pas',
  ProcessThread in 'ProcessThread.pas',
  Common in 'Common.pas';

const
  LogSource = 'shell-exec';
  IniFile = 'shell_exec.ini';

type
  TShellExecModule = class(TInterfacedObject, IModule, ILoadNotify, IDestroyNotify)
  private
    FCore: ICore;
    FShellMMItem: IShellMainMenu;
    IniMain: TIniFile;
    FCfg: TIniOptions;
    procedure PerformTask(Sender: TObject);
    procedure OnProcessThreadResult(Sender: TObject);
  protected
    function ReadConfig: Boolean;
    procedure DoLog(LogTag, LogText: string);
    function GetID: PGUID; stdcall;
    function GetName: WideString; stdcall;
    function GetUnique: LongBool; stdcall;
    function GetType: TModuleType; stdcall;
    function GetVersion: WideString; stdcall;
    function GetDescription: WideString; stdcall;
    // IDestroy
    procedure Delete; stdcall;
    //
    procedure Log(LogText: string; LogType: TLogType);
    procedure LogTagged(LogTag, LogText: string; LogType: TLogType = 0);
  public
    constructor Create(ACore: ICore); overload;
    destructor Destroy; override;
    procedure AllModulesLoaded; stdcall;
    property ID: PGUID read GetID;
    property Name: WideString read GetName;
    property Unique: LongBool read GetUnique;
    property TypeOf: TModuleType read GetType;
    property Version: WideString read GetVersion;
    property Description: WideString read GetDescription;
  end;

{$R *.res}

function GetModulePath: string;
var
  szFileName: array [0 .. MAX_PATH] of Char;
begin
  FillChar(szFileName, SizeOf(szFileName), #0);
  GetModuleFileName(hInstance, szFileName, MAX_PATH);
  Result := szFileName;
end;

constructor TShellExecModule.Create(ACore: ICore);
begin
  inherited Create;
  FCore := ACore;
end;

destructor TShellExecModule.Destroy;
begin
  if Assigned(FCfg) then
    FCfg.Free;
  if Assigned(IniMain) then
    IniMain.Free;
  inherited;
end;

function TShellExecModule.ReadConfig: Boolean;
var
  libPath: string;
begin
  Result := False;
  libPath := IncludeTrailingPathDelimiter(ExtractFilePath(GetModulePath));
  if not FileExists(libPath + IniFile) then
  begin
    Log('Config file not found: ' + libPath + IniFile, 2);
    // raise Exception.Create('Config file not found');
    exit;
  end;
  IniMain := TIniFile.Create(libPath + IniFile);
  Log('Reading config file: ' + IniMain.FileName, 0);
  FCfg := TIniOptions.Create;
  FCfg.LoadSettings(IniMain);

  Result := True;
end;

procedure TShellExecModule.Delete;
begin

  FCore := nil;
end;

procedure TShellExecModule.AllModulesLoaded;
var
  LMenuItemTask: IShellMainMenuItem;
  LShellCtrl: IShellBasicControl;
begin

  if not Supports(FCore.Shell, IShellBasicControl, LShellCtrl) then
    exit;

  FShellMMItem := LShellCtrl.AddMainMenu(Name);

  for var Task in FCfg.ShellExecCmds do
  begin
    LMenuItemTask := TShellMainMenuItem.Create(Task, Task, PerformTask);
    FShellMMItem.AddMenuItem(LMenuItemTask);
    Log('ShellExec Task: ' + Task, tlgInfo)
  end;

end;

function TShellExecModule.GetDescription: WideString;
begin
  Result := 'Shell execute module ...';
end;

function TShellExecModule.GetID: PGUID;
const
  ID: TGUID = '{41E6A648-80FB-4E7E-980F-A0F6B7E1E108}';
begin
  Result := @ID;
end;

function TShellExecModule.GetName: WideString;
begin
  Result := 'Shell Execute';
end;

function TShellExecModule.GetType: TModuleType;
begin
  Result := mtdPluginGeneral;
end;

function TShellExecModule.GetUnique: LongBool;
begin
  Result := False;
end;

function TShellExecModule.GetVersion: WideString;
begin
  Result := '1.0.1.1';
end;

procedure TShellExecModule.DoLog(LogTag, LogText: string);
begin
  LogTagged(LogTag, LogText, 0);
end;

procedure TShellExecModule.Log(LogText: string; LogType: TLogType);
var
  Log: ILog;
begin
  if Supports(FCore, ILog, Log) then
    Log.Log(LogSource, LogText, LogType);
end;

procedure TShellExecModule.LogTagged(LogTag, LogText: string; LogType: TLogType = 0);
var
  Log: ILog;
begin
  if Supports(FCore, ILog, Log) then
    Log.LogTagged(LogSource, LogTag, LogText, LogType);
end;

procedure TShellExecModule.PerformTask(Sender: TObject);
var
  LShellTask: TShellMainMenuItem;
  LTask: ITask;
  LProcessThread: TProcessThread;
  LResult: string;
begin
  LShellTask := Sender as TShellMainMenuItem;
  Log(Format('Task is processing: %s %s ...', [LShellTask.Command, LShellTask.Args]), tlgInfo);
  LProcessThread := TProcessThread.Create(LShellTask.Command, LShellTask.Args, OnProcessThreadResult);
  LProcessThread.FreeOnTerminate := True;
end;

procedure TShellExecModule.OnProcessThreadResult(Sender: TObject);
var
  LProcessThread: TProcessThread;
  LResult: string;
begin
  LProcessThread := Sender as TProcessThread;
  LResult := OEMToAnsi(LProcessThread.Output);
  LResult := StringReplace(LResult, #$D#$A, '', []);
  try
    Log(Format('Results for the Task: %s %s' + #10#13 + '%s', [LProcessThread.Command, LProcessThread.Parameters,
      LResult]), tlgInfo);
  except
  end;
end;

//////////////////////

// Initialization

var
  Module: TShellExecModule;

function InitModule(const ACore: ICore): IModule; stdcall;
begin
{$IFDEF madExcept}
  StartLeakChecking(False);
  HideLeak('LocalAlloc|InitThreadTLS'); { MadExpert Local Alloc bug, caused by TNetHTTPClient.Create ... in any dll }
{$ENDIF}
  Result := nil;
  Module := TShellExecModule.Create(ACore);
  if not Module.ReadConfig then
    exit;
  Result := Module;
end;

exports
  InitModule;

end.
