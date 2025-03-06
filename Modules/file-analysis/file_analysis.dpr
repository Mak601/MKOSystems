library file_analysis;

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF }
  System.IniFiles,
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  System.StrUtils,
  IModuleInterface,
  ICoreInterface,
  IShellInterface,
  ILogInterface,
  Config in 'Config.pas',
  FileSeacher in 'FileSeacher.pas',
  FileContentScanner in 'FileContentScanner.pas',
  Common in 'Common.pas';

const
  LogSource = 'file-analysis';
  IniFile = 'file_analysis.ini';
  ShellCaption = 'MKO Systems Test Task';

type
  TFileAnalysisModule = class(TInterfacedObject, IModule, ILoadNotify, IDestroyNotify)
  private
    FCore: ICore;
    IniMain: TIniFile;
    FCfg: TIniOptions;
    FShellMMItem: IShellMainMenu;
    procedure PerformTask(Sender: TObject);
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

constructor TFileAnalysisModule.Create(ACore: ICore);
begin
  inherited Create;
  FCore := ACore;
end;

destructor TFileAnalysisModule.Destroy;
begin
  if Assigned(FCfg) then
    FCfg.Free;
  if Assigned(IniMain) then
    IniMain.Free;
  inherited;
end;

function TFileAnalysisModule.ReadConfig: Boolean;
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

procedure TFileAnalysisModule.Delete;
begin
  FShellMMItem := nil;
  FCore := nil;
end;

procedure TFileAnalysisModule.AllModulesLoaded;
var
  LMenuItemTask: IShellMainMenuItem;
  LShellCtrl: IShellBasicControl;
begin
  if Supports(FCore.Shell, IShellBasicControl, LShellCtrl) then
    LShellCtrl.SetShellCaption(ShellCaption);

  if not Supports(FCore.Shell, IShellBasicControl, LShellCtrl) then
    exit;

  FShellMMItem := LShellCtrl.AddMainMenu(Name);
  LMenuItemTask := TShellMainMenuItem.Create('---File Searcher--------', fsttSearcher, '', nil);
  FShellMMItem.AddMenuItem(LMenuItemTask);

  for var FSTask in FCfg.FileSearcherTasks do
  begin
    LMenuItemTask := TShellMainMenuItem.Create(FSTask, fsttSearcher, FSTask, PerformTask);
    FShellMMItem.AddMenuItem(LMenuItemTask);
    Log('fsttSearcher: ' + FSTask, tlgInfo)
  end;

  LMenuItemTask := TShellMainMenuItem.Create('---File Content Scanner--------', fsttContentScanner, '', nil);
  FShellMMItem.AddMenuItem(LMenuItemTask);

  for var FSTask in FCfg.FileContentScannerTasks do
  begin
    LMenuItemTask := TShellMainMenuItem.Create(FSTask, fsttContentScanner, FSTask, PerformTask);
    FShellMMItem.AddMenuItem(LMenuItemTask);
    Log('fsttContentScanner: ' + FSTask, tlgInfo)
  end;

end;

function TFileAnalysisModule.GetDescription: WideString;
begin
  Result := 'File analysis module ...';
end;

function TFileAnalysisModule.GetID: PGUID;
const
  ID: TGUID = '{DEE6233C-4B51-4B5B-9D61-18BC1B26719B}';
begin
  Result := @ID;
end;

function TFileAnalysisModule.GetName: WideString;
begin
  Result := 'File Analysis';
end;

function TFileAnalysisModule.GetType: TModuleType;
begin
  Result := mtdPluginGeneral;
end;

function TFileAnalysisModule.GetUnique: LongBool;
begin
  Result := False;
end;

function TFileAnalysisModule.GetVersion: WideString;
begin
  Result := '1.0.1.1';
end;

procedure TFileAnalysisModule.DoLog(LogTag, LogText: string);
begin
  LogTagged(LogTag, LogText, 0);
end;

procedure TFileAnalysisModule.Log(LogText: string; LogType: TLogType);
var
  Log: ILog;
begin
  if Supports(FCore, ILog, Log) then
    Log.Log(LogSource, LogText, LogType);
end;

procedure TFileAnalysisModule.LogTagged(LogTag, LogText: string; LogType: TLogType = 0);
var
  Log: ILog;
begin
  if Supports(FCore, ILog, Log) then
    Log.LogTagged(LogSource, LogTag, LogText, LogType);
end;

procedure TFileAnalysisModule.PerformTask(Sender: TObject);
var
  LShellTask: TShellMainMenuItem;
  LFileSearcher: TFileSeacher;
  LFileContentScanner: TFileContentScanner;
  LTask: ITask;
  LResult: TStringList;
begin
  LShellTask := Sender as TShellMainMenuItem;
  Log(Format('Performing Task(%s): %s %s', [ifthen(LShellTask.TaskType = fsttSearcher, 'File Search', 'File Content Scan'), LShellTask.FilePath, LShellTask.FSRegexPattern]), tlgInfo);

    case LShellTask.TaskType of
      fsttSearcher:
        begin
          LTask := TTask.Create(
            procedure()
            begin
              LResult := TStringList.Create;
              LResult.Delimiter := #13;
              try
                LFileSearcher := TFileSeacher.Create(LShellTask.FSRegexPattern);
                try
                  LFileSearcher.GetFiles(LShellTask.FilePath, LResult);
                  Log(Format('Results for the Task(File Search): %s' + #13 + '%s',
                    [LShellTask.Title, LResult.DelimitedText]), tlgInfo);
                finally
                  LFileSearcher.Free;
                end;
              finally
                LResult.Free;
              end;
            end);
          LTask.Start;
        end;
      fsttContentScanner:
        begin
          LTask := TTask.Create(
            procedure()
            begin
              LResult := TStringList.Create;
              LResult.Delimiter := #13;
              try
                LFileContentScanner := TFileContentScanner.Create;
                try
                  for var Sequence in LShellTask.FCSSequences do
                    LFileContentScanner.AddPattern(Sequence);
                  LFileContentScanner.Search(LShellTask.FilePath, LResult);
                  Log(Format('Results for the Task(Content Scanner): %s' + #13 + '%s',
                    [LShellTask.Title, LResult.DelimitedText]), tlgInfo);
                finally
                  LFileSearcher.Free;
                end;
              finally
                LResult.Free;
              end;
            end);
          LTask.Start;
        end;
    end;

end;

//////////////////////

// Initialization

var
  Module: TFileAnalysisModule;

function InitModule(const ACore: ICore): IModule; stdcall;
begin
{$IFDEF madExcept}
  StartLeakChecking(False);
  HideLeak('LocalAlloc|InitThreadTLS'); { MadExpert Local Alloc bug, caused by TNetHTTPClient.Create ... in any dll }
{$ENDIF}
  Result := nil;
  Module := TFileAnalysisModule.Create(ACore);
  if not Module.ReadConfig then
    exit;
  Result := Module;
end;

exports
  InitModule;

end.
