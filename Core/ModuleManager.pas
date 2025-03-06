unit ModuleManager;

interface

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  ICoreInterface,
  IModuleInterface,
  ILogInterface;

type
  EModuleManagerError = class(Exception);

  EModuleLoadError = class(EModuleManagerError);

  EDuplicateModuleError = class(EModuleLoadError);

  EModulesLoadError = class(EModuleLoadError)
  private
    FItems: TStrings;
  public
    constructor Create(const AText: string; const AFailedModules: TStrings);
    destructor Destroy; override;
    property FailedModuleFileNames: TStrings read FItems;
  end;

resourcestring
  rsModulesLoadError = 'One or more modules has failed to load: %s';

const
  LogSource = 'Core';

type
  TModuleInfo = class
  private
    FFileName: string;
    FHandle: Cardinal;
    FModule: IModule;
  public
    Constructor Create(AFileName: string; AHandle: Cardinal; AModule: IModule);
    Destructor Destroy; override;
    property FileName: string read FFileName write FFileName;
    property Handle: Cardinal read FHandle write FHandle;
    property Module: IModule read FModule write FModule;
  end;

type
  TLog = procedure(LogSource, LogText: string; LogType: TLogType) of object;

type
  TModuleManager = class(TInterfacedObject, IModules)
  private
    FModules: TThreadList<TModuleInfo>;
    FBanned: TStringList;
    FOnLog: TLog;
    procedure AddModule(AModule: TModuleInfo);
  protected
    procedure LoadingFinished;
    function CantLoad(const AFileName: string): Boolean;
    function GetCount: Integer; stdcall;
    function GetModule(const AIndex: Integer): IModule; stdcall;
    procedure LoadModule(const AFileName: string; const Core: ICore);
    procedure Log(LogText: string; LogType: TLogType = 0);
    function CheckForUnique(AType: TModuleType): Boolean;
  public
    constructor Create; overload;
    destructor Destroy; override;
    procedure LoadModules(const AFolder, AFileExt: string; const Core: ICore); overload;
    procedure LoadModules(Modules: TStringList; const Core: ICore); overload;
    function IndexOf(const AModule: IModule): Integer;
    procedure Ban(const AFileName: string);
    procedure Unban(const AFileName: string);
    procedure NotifyDestroy;
    procedure UnloadModules;
    function GetHandle(const AIndex: Integer): Cardinal; stdcall;
    function GetFilename(const AIndex: Integer): WideString; stdcall;
    property Count: Integer read GetCount;
    property Modules[const AIndex: Integer]: IModule read GetModule; default;
    property OnLog: TLog write FOnLog;
  end;

  TInitModuleFunc = function(const ACore: ICore): IModule; stdcall;

implementation

{ TModuleManager }

constructor TModuleManager.Create;
begin
  inherited Create;
  FModules := TThreadList<TModuleInfo>.Create;
  FBanned := TStringList.Create;
end;

destructor TModuleManager.Destroy;
begin
  FModules.Free;
  FBanned.Free;
  inherited;
end;

procedure TModuleManager.LoadModule(const AFileName: string; const Core: ICore);
var
  InitFunc: TInitModuleFunc;
  Itf: IInterface;
  lHandle: Cardinal;
  lModule: IModule;
begin
  if CantLoad(AFileName) then
    Exit;

  try
    lHandle := SafeLoadLibrary(AFileName);
{$WARNINGS OFF}
{$IFDEF MSWINDOWS}
    Win32Check(lHandle <> 0);
{$ELSE}
    if ModuleInfo.Handle = 0 then
    begin
      Log('Error loading module (zero handle): ' + AFileName, 2);
      Exit;
    end;
{$ENDIF}
    InitFunc := GetProcAddress(lHandle, 'InitModule');
{$IFDEF MSWINDOWS}
    Win32Check(Assigned(InitFunc));
{$ELSE}
    if not Assigned(InitFunc) then
    begin
      Log('Error loading module (Init Procedure entry point not found): ' + AFileName, 2);
      Exit;
    end;
{$ENDIF}
{$WARNINGS ON}
    Itf := InitFunc(Core);
  except
    on E: Exception do
    begin
      Log(Format('[%s] %s', [E.ClassName, E.Message]), 2);
      Exit;
    end;
  end;
  if not Supports(Itf, IModule, lModule) then
  begin
    Log(Format('[%s] %s', [AFileName, 'not support IModule interface.']), 2);
    Exit;
  end;
  if lModule.Unique then
    if not CheckForUnique(lModule.&Type) then
    begin
      Log(Format('[%s] %s', [AFileName, 'is marked as Unique, but module with same type already loaded.']), 2);
      Exit;
    end;
  Log(Format('Success; Name: %s, Type: %d, Descr.: %s, Ver.: %s', [lModule.Name, lModule.&Type, lModule.Description,
    lModule.Version]));
  var
  ModuleInfo := TModuleInfo.Create(AFileName, lHandle, lModule);
  AddModule(ModuleInfo);
end;

procedure TModuleManager.LoadModules(const AFolder, AFileExt: string; const Core: ICore);

  function ModuleOK(const AModuleName, AFileExt: string): Boolean;
  begin
    Result := (AFileExt = '');
    if Result then
      Exit;
    Result := SameFileName(ExtractFileExt(AModuleName), AFileExt);
  end;

var
  Path: string;
  SR: TSearchRec;
  Failures: TStringList;
  FailedModules: TStringList;
begin

  Path := IncludeTrailingPathDelimiter(AFolder);
  Log(Format('Loading modules from path %s (Ext: %s)', [Path, AFileExt]));
  Failures := TStringList.Create;
  FailedModules := TStringList.Create;
  try
    if FindFirst(Path + '*.*', 0, SR) = 0 then
      try
        repeat
          if ((SR.Attr and faDirectory) = 0) and ModuleOK(SR.Name, AFileExt) then
          begin
            Log(Format('Loading module: %s', [SR.Name]));
            try
              LoadModule(Path + SR.Name, Core);
            except
              on E: Exception do
              begin
                FailedModules.Add(SR.Name);
                Failures.Add(Format('%s: %s', [SR.Name, E.Message]));
              end;
            end;
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;

    if Failures.Count > 0 then
      raise EModulesLoadError.Create(Format(rsModulesLoadError, [Failures.Text]), FailedModules)
    else
      LoadingFinished;
  finally
    FreeAndNil(FailedModules);
    FreeAndNil(Failures);
  end;
end;

procedure TModuleManager.LoadModules(Modules: TStringList; const Core: ICore);
var
  Module: string;
  Failures: TStringList;
  FailedModules: TStringList;
begin
  Log('Loading modules from config list...');
  Failures := TStringList.Create;
  FailedModules := TStringList.Create;
  try
    for Module in Modules do
    begin
      Log(Format('Loading module: %s', [Module]));
      try
        LoadModule(Module, Core);
      except
        on E: Exception do
        begin
          FailedModules.Add(Module);
          Failures.Add(Format('%s: %s', [Module, E.Message]));
        end;
      end;
    end;
    if Failures.Count > 0 then
      raise EModulesLoadError.Create(Format(rsModulesLoadError, [Failures.Text]), FailedModules)
    else
      LoadingFinished;
  finally
    FreeAndNil(FailedModules);
    FreeAndNil(Failures);
  end;
end;

procedure TModuleManager.LoadingFinished;
var
  LN: ILoadNotify;
begin
  for var c := 0 to GetCount - 1 do
    if Supports(Modules[c], ILoadNotify, LN) then
      LN.AllModulesLoaded;
end;

procedure TModuleManager.UnloadModules;
var
  lList: TList<TModuleInfo>;
  ModuleInfo: TModuleInfo;
begin
  Log('Unloading modules...');
  lList := FModules.LockList;
  try
    for var I := lList.Count - 1 downto 0 do
    begin
      ModuleInfo := lList.ExtractAt(I);
      var
      ModuleName := ModuleInfo.Module.Name;
      Log('Unloading: ' + ModuleName);
      { ModuleName := '' This will avoid access violation, cause compiler is trying to clear string mem from killed lib }
      ModuleName := '';
      ModuleInfo.Module := nil;
      if ModuleInfo.Handle <> 0 then
        FreeLibrary(ModuleInfo.Handle);
      ModuleInfo.Free;
    end;
  finally
    FModules.UnlockList;
  end;
end;

procedure TModuleManager.NotifyDestroy;
var
  lList: TList<TModuleInfo>;
  ModuleInfo: TModuleInfo;
  Notify: IDestroyNotify;
begin
  Log('Sending Destroy Notify to modules...');
  lList := FModules.LockList;
  try
    for var I := lList.Count - 1 downto 0 do
    begin
      ModuleInfo := lList.Items[I];
      var
      ModuleName := ModuleInfo.Module.Name;
      Log('Destroy Notify: ' + ModuleName);
      ModuleName := '';
      if Supports(ModuleInfo.Module, IDestroyNotify, Notify) then
        Notify.Delete;
      Notify := nil;
    end;
  finally
    FModules.UnlockList;
  end;
  Log('Destroy notify finished.');
end;

function TModuleManager.IndexOf(const AModule: IModule): Integer;
var
  lList: TList<TModuleInfo>;
begin
  Result := -1;
  lList := FModules.LockList;
  try
    for var I := 0 to lList.Count - 1 do
      if lList.Items[I].Module = AModule then
      begin
        Result := I;
        Break;
      end;
  finally
    FModules.UnlockList;
  end;
end;

procedure TModuleManager.AddModule(AModule: TModuleInfo);
var
  lList: TList<TModuleInfo>;
begin
  lList := FModules.LockList;
  try
    lList.Add(AModule);
  finally
    FModules.UnlockList;
  end;
end;

procedure TModuleManager.Ban(const AFileName: string);
begin
  Unban(AFileName);
  FBanned.Add(AFileName);
end;

procedure TModuleManager.Unban(const AFileName: string);
begin
  for var I := 0 to FBanned.Count - 1 do
    if SameFileName(FBanned[I], AFileName) then
    begin
      FBanned.Delete(I);
      Break;
    end;
end;

function TModuleManager.CantLoad(const AFileName: string): Boolean;
var
  lList: TList<TModuleInfo>;
begin
  for var Banned in FBanned do
    if SameFileName(Banned, AFileName) then
    begin
      Log('Module in ban list, skipped...', 1);
      Result := True;
      Exit;
    end;

  lList := FModules.LockList;
  try
    for var Module in lList do
      if SameFileName(Module.FileName, AFileName) then
      begin
        Log('Module already loaded, skipped...', 1);
        Result := True;
        Exit;
      end;
  finally
    FModules.UnlockList;
  end;

  Result := False;
end;

function TModuleManager.CheckForUnique(AType: TModuleType): Boolean;
var
  lList: TList<TModuleInfo>;
begin
  Result := True;
  lList := FModules.LockList;
  try
    for var Module in lList do
      if Module.Module.&Type = AType then
      begin
        Result := False;
        Exit;
      end;
  finally
    FModules.UnlockList;
  end;
end;

procedure TModuleManager.Log(LogText: string; LogType: TLogType = 0);
begin
  if Assigned(FOnLog) then
    FOnLog(LogSource, LogText, LogType);
end;

// procedure TModuleManager.RegisterServiceProvider(const AProvider: IInterface);
// begin
// FProviders.Add(AProvider);
// end;

function TModuleManager.GetCount: Integer;
var
  lList: TList<TModuleInfo>;
begin
  lList := FModules.LockList;
  try
    Result := lList.Count;
  finally
    FModules.UnlockList;
  end;
end;

function TModuleManager.GetFilename(const AIndex: Integer): WideString;
var
  lList: TList<TModuleInfo>;
begin
  lList := FModules.LockList;
  try
    Result := PWideChar(lList.Items[AIndex].FileName);
  finally
    FModules.UnlockList;
  end;
end;

function TModuleManager.GetHandle(const AIndex: Integer): Cardinal;
var
  lList: TList<TModuleInfo>;
begin
  lList := FModules.LockList;
  try
    Result := lList.Items[AIndex].Handle;
  finally
    FModules.UnlockList;
  end;
end;

function TModuleManager.GetModule(const AIndex: Integer): IModule;
var
  lList: TList<TModuleInfo>;
begin
  lList := FModules.LockList;
  try
    Result := lList.Items[AIndex].Module;
  finally
    FModules.UnlockList;
  end;
end;

{ EModulesLoadError }

constructor EModulesLoadError.Create(const AText: string; const AFailedModules: TStrings);
begin
  inherited Create(AText);
  FItems := TStringList.Create;
  FItems.Assign(AFailedModules);
end;

destructor EModulesLoadError.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

{ TModuleInfo }

constructor TModuleInfo.Create(AFileName: string; AHandle: Cardinal; AModule: IModule);
begin
  inherited Create;
  FFileName := AFileName;
  FHandle := AHandle;
  FModule := AModule;
end;

destructor TModuleInfo.Destroy;
begin
  FModule := nil;
  inherited;
end;

end.
