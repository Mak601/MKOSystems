library core;

uses
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF }
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs,
  System.DateUtils,
  System.Generics.Collections,
  inifiles,
  ModuleManager in 'ModuleManager.pas',
  ICoreInterface in '..\Headers\ICoreInterface.pas',
  IModuleInterface in '..\Headers\IModuleInterface.pas',
  ILogInterface in '..\Headers\ILogInterface.pas',
  IShellInterface in '..\Headers\IShellInterface.pas',
  LogThreadManager in 'LogThreadManager.pas',
  Synchronizer in 'Synchronizer.pas';

{$R *.res}

const
  LogSource = 'Core';
  IniFile = 'core.ini';
  IniMain = 'Main';
  IniMainLoadModulesFromPath = 'LoadModulesFromPath';
  IniMainPath = 'Path';
  IniMainModuleExt = 'ModuleExt';
  IniMainHWID = 'HWID';
  IniSkip = 'Skip';
  IniModules = 'Modules';
  IniDefaultModuleExt = '.dll';

type
  TCore = class(TInterfacedObject, ICore, IModules, ILog)
  private
    Ini: TIniFile;
    FModulesObj: TModuleManager;
    FModules: IModules;
    FLogManager: TLogThread;
    FShell: IShell;
    FLog: ILog;
    FIniLoadFromPath: Boolean;
    FIniPath: string;
    FIniModuleExt: string;
    FIniBanned: TStringList;
    FIniModules: TStringList;
    FSyncList: TSyncList;
    procedure ShellLog(LogSource, LogText: string; LogType: TLogType);
  protected
    procedure ReadConfig;
    procedure DoLog(LogSource, LogText: string; LogType: TLogType);
    function GetVersion: Integer; stdcall;
    procedure SetLog(Log: ILog); stdcall;
    function GetShell: IShell; stdcall;
    function GetSynchronizer(AName: WideString): ISynchronizer; stdcall;
  public
    constructor Create(const AShell: IShell);
    destructor Destroy; override;
    procedure Log(LogSource, LogText: WideString; LogType: TLogType); stdcall;
    procedure LogTagged(LogSource, LogTag, LogText: WideString; LogType: TLogType); stdcall;
    procedure LoadModules(const CoreItf: ICore);
    procedure ShutDown; stdcall;
    property Version: Integer read GetVersion;
    property OnLog: ILog write SetLog;
    property Modules: TModuleManager read FModulesObj implements IModules;
    property Shell: IShell read GetShell;
  end;

function GetModulePath: string;
var
  szFileName: array [0 .. MAX_PATH] of Char;
begin
  FillChar(szFileName, SizeOf(szFileName), #0);
  GetModuleFileName(hInstance, szFileName, MAX_PATH);
  Result := szFileName;
end;

function LogTime: string;
var
  myDate: TDateTime;
  myYear, myMonth, myDay: Word;
  myHour, myMin, mySec, myMilli: Word;
  LLocalFormatSettings: TFormatSettings;
begin
  myDate := Now;
  DecodeDateTime(myDate, myYear, myMonth, myDay, myHour, myMin, mySec, myMilli);
  LLocalFormatSettings := TFormatSettings.Create;
  Result := Format('%d/%d/%d %d:%d:%d.%d', [myDay, myMonth, myYear, myHour, myMin, mySec, myMilli], LLocalFormatSettings);
end;

{ TCore }

constructor TCore.Create(const AShell: IShell);
var
  libPath: string;
begin
  inherited Create;
  ShellLog(LogSource, Format('API Version %d', [GetVersion]), 0);
  FShell := AShell;
  libPath := IncludeTrailingPathDelimiter(ExtractFilePath(GetModulePath));
  if not FileExists(libPath + IniFile) then
  begin
    ShellLog(LogSource, 'Config file not found: ' + libPath + IniFile, 2);
    raise Exception.Create('Config file not found');
    exit;
  end;
  Ini := TIniFile.Create(libPath + IniFile);
  FModules := TModuleManager.Create;
  FModulesObj := (FModules as TModuleManager);
  FModulesObj.OnLog := DoLog;
  FLogManager := TLogThread.Create(FModules);
  FSyncList := TSyncList.Create;
  ReadConfig;
end;

destructor TCore.Destroy;
begin
  FModules := nil;
  FIniBanned.Free;
  FIniModules.Free;
  FLog := nil;
  FShell := nil;
  if Assigned(Ini) then
    Ini.Free;
  FLogManager.Free;
  FSyncList.Free;
  inherited;
end;

procedure TCore.DoLog(LogSource, LogText: string; LogType: TLogType);
begin
  Log(LogSource, LogText, LogType);
end;

procedure TCore.ReadConfig;
var
  key: string;
  c: Integer;
begin
  DoLog(LogSource, 'Reading config file: ' + Ini.FileName, 0);
  FIniLoadFromPath := Ini.ReadBool(IniMain, IniMainLoadModulesFromPath, False);
  FIniPath := Ini.ReadString(IniMain, IniMainPath, '');
  FIniModuleExt := Ini.ReadString(IniMain, IniMainModuleExt, IniDefaultModuleExt);
  FIniBanned := TStringList.Create;
  FIniModules := TStringList.Create;
  Ini.ReadSection(IniSkip, FIniBanned);
  for key in FIniBanned do
    if Ini.ReadBool(IniSkip, key, True) then
      FModulesObj.Ban(key);
  Ini.ReadSection(IniModules, FIniModules);
  for c := FIniModules.Count - 1 downto 0 do
    if not Ini.ReadBool(IniModules, FIniModules.Strings[c], True) then
      FIniModules.Delete(c);
end;

function TCore.GetShell: IShell;
begin
  Result := FShell;
end;

function TCore.GetSynchronizer(AName: WideString): ISynchronizer;
begin
  Result := FSyncList.GetSynchronizer(AName);
end;

function TCore.GetVersion: Integer;
begin
  Result := 1;    // Modules can check if Core API is Correct.
end;

procedure TCore.SetLog(Log: ILog);
begin
  FLog := Log;
end;

procedure TCore.LoadModules(const CoreItf: ICore);
begin
  Log(LogSource, 'Core Starting ...', tlgInfo);
  if FIniLoadFromPath then
    FModulesObj.LoadModules(FIniPath, FIniModuleExt, CoreItf)
  else
    FModulesObj.LoadModules(FIniModules, CoreItf);
end;

procedure TCore.ShellLog(LogSource, LogText: string; LogType: TLogType);
var
  lText: string;
  Log: ILog;
begin
  lText := Format('%s %s', [LogTime, LogText]);
  if Supports(FShell, ILog, Log) then
    Log.Log(LogSource, lText, LogType); // Shell Log
end;

procedure TCore.Log(LogSource, LogText: WideString; LogType: TLogType);
var
  lText: string;
  Log: ILog;
  LLocalFormatSettings: TFormatSettings;
begin
  LLocalFormatSettings := TFormatSettings.Create;
  lText := Format('%s %s', [LogTime, LogText], LLocalFormatSettings);
  if Supports(FShell, ILog, Log) then
    Log.Log(LogSource, lText, LogType); // Shell Log
  FLogManager.Log(LogSource, lText, LogType);
end;

procedure TCore.LogTagged(LogSource, LogTag, LogText: WideString; LogType: TLogType);
var
  lText: string;
  Log: ILog;
  LLocalFormatSettings: TFormatSettings;
begin
  LLocalFormatSettings := TFormatSettings.Create;
  lText := Format('%s %s', [LogTime, LogText], LLocalFormatSettings);
  if Supports(FShell, ILog, Log) then
    Log.LogTagged(LogSource, LogTag, lText, LogType); // Shell log
  FLogManager.Log(LogSource, LogTag, lText, LogType);
end;

procedure TCore.ShutDown;
begin
  Log(LogSource, 'Core shutdown', tlgInfo);
  FModulesObj.NotifyDestroy; // Notify modules to release all ext. interfaces
  FLogManager.Terminate;
  FLogManager.WaitFor;
  FModulesObj.UnloadModules; // Unload modules
end;

function StartCore(const AShell: IShell): ICore; stdcall;
var
  Core: TCore;
begin
{$IFDEF madExcept}
  StartLeakChecking(False);
  HideLeak('LocalAlloc|InitThreadTLS'); { MadExpert Local Alloc bug,caused by TNetHTTPClient.Create ... in any dll }
{$ENDIF}
  Core := TCore.Create(AShell);
  Result := Core;
  Core.LoadModules(Result);
end;

exports
  StartCore;

end.
