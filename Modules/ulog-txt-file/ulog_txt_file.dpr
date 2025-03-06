library ulog_txt_file;

uses
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF }
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  ILogInterface,
  IModuleInterface,
  ICoreInterface,
  LogFile in 'LogFile.pas';

const
  LogSource = 'ulog-txt-file';
  IniFile = 'ulog_txt_file.ini';
  IniMain = 'Main';
  IniMainLogFileName = 'LogFileName';
  IniMainMaxSize = 'MaxSize';
  IniMainMaxHistory = 'MaxHistory';

type
  TLogTxt = class(TInterfacedObject, IModule, IDestroyNotify, ILog)
  private
    FCore: ICore;
    Ini: TIniFile;
    FLogFile: TLogToFile;
    function GetLogLineType(LogType: TLogType): string;
    procedure ReadConfig;
    procedure ShellLog(LogText: string; LogType: TLogType);
    procedure LogToFile(AText: string);
  protected
    function GetID: PGUID; stdcall;
    function GetName: WideString; stdcall;
    function GetUnique: LongBool; stdcall;
    function GetType: TModuleType; stdcall;
    function GetVersion: WideString; stdcall;
    function GetDescription: WideString; stdcall;
    // IDestroy
    procedure Delete; stdcall;
  public
    constructor Create(ACore: ICore);
    destructor Destroy; override;
    procedure Log(ALogSource, ALogText: WideString; ALogType: TLogType); stdcall;
    procedure LogTagged(ALogSource, ALogTag, ALogText: WideString; ALogType: TLogType); stdcall;
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
  szFileName: array[0..MAX_PATH] of Char;
begin
  FillChar(szFileName, SizeOf(szFileName), #0);
  GetModuleFileName(hInstance, szFileName, MAX_PATH);
  Result := szFileName;
end;

{ TLogTxt }

constructor TLogTxt.Create(ACore: ICore);
var
  libPath: string;
begin
  inherited Create;
  FCore := ACore;
  libPath := IncludeTrailingPathDelimiter(ExtractFilePath(GetModulePath));
  if not FileExists(libPath + IniFile) then
  begin
    ShellLog('Config file not found: ' + libPath + IniFile, 2);
    raise Exception.Create('Config file not found');
    exit;
  end;
  Ini := TIniFile.Create(libPath + IniFile);
  FLogFile := TLogToFile.Create(nil);
  ReadConfig;
end;

procedure TLogTxt.ReadConfig;
begin
  ShellLog('Reading config file: ' + Ini.FileName, 0);
   //
  FLogFile.IncDateTime := True;
  FLogFile.OverwriteExistingFile := False;
  FLogFile.Separator := ' ';
  FLogFile.IncSeparator := true;
   //
  FLogFile.LogFileName := Ini.ReadString(IniMain, IniMainLogFileName, 'Log.txt');
  FLogFile.MaxSize := Ini.ReadInteger(IniMain, IniMainMaxSize, 1000) * 1000; //1mb
  FLogFile.MaxHistory := Ini.ReadInteger(IniMain, IniMainMaxHistory, 100);
  FLogFile.WriteToLogFile('Started ****************************************************************', 5, 0, False, 'All');
end;

procedure TLogTxt.Delete;
begin
  FCore := nil;
end;

destructor TLogTxt.Destroy;
begin
  FLogFile.Free;
  if Assigned(Ini) then Ini.Free;
  inherited;
end;

function TLogTxt.GetDescription: WideString;
begin
  Result := 'Writing Log to TXT file';
end;

function TLogTxt.GetID: PGUID;
const
  ID: TGUID = '{4156D574-8597-4B75-8D65-F17E99E13985}';
begin
  Result := @ID;
end;

function TLogTxt.GetName: WideString;
begin
  Result := 'LogTXT';
end;

function TLogTxt.GetType: TModuleType;
begin
  Result := mdtLog;
end;

function TLogTxt.GetUnique: LongBool;
begin
  Result := False;
end;

function TLogTxt.GetVersion: WideString;
begin
  Result := '1.0.1.1';
end;

function TLogTxt.GetLogLineType(LogType: TLogType): string;
begin
  case LogType of
    tlgInfo:
      Result := 'Info';
    tlgWarning:
      Result := 'Warning';
    tlgError:
      Result := 'Error';
  end;
end;

procedure TLogTxt.ShellLog(LogText: string; LogType: TLogType);
var
  LLog: ILog;
begin
  if Supports(FCore.Shell, ILog, LLog) then
    LLog.Log(LogSource, LogText, LogType);
end;

procedure TLogTxt.Log(ALogSource, ALogText: WideString; ALogType: TLogType);
begin
  LogToFile(Format('%s:(%s) -> %s', [ALogSource, GetLogLineType(ALogType), ALogText]));
end;

procedure TLogTxt.LogTagged(ALogSource, ALogTag, ALogText: WideString; ALogType: TLogType);
begin
  LogToFile(Format('%s:(%s) %s -> %s', [ALogSource, GetLogLineType(ALogType), ALogTag, ALogText]));
end;

function InitModule(const ACore: ICore): IModule; stdcall;
begin
  Result := TLogTxt.Create(ACore);
end;

procedure TLogTxt.LogToFile(AText: string);
begin
  FLogFile.WriteToLogFile(AText, 0, 0, False, 'All');
end;

exports
  InitModule;

end.

