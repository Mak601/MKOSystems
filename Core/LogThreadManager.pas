unit LogThreadManager;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  IModuleInterface,
  ILogInterface,
  ICoreInterface;

type
  TLogTask = class
  private
    FTagged: Boolean;
    FSource: string;
    FTag: string;
    FText: string;
    FLogType: TLogType;
  public
    constructor Create(ASource, ATag, AText: string; ALogType: TLogType);
    property Tagged: Boolean read FTagged write FTagged;
    property Source: string read FSource write FSource;
    property Tag: string read FTag write FTag;
    property Text: string read FText write FText;
    property LogType: TLogType read FLogType write FLogType;
  end;

type
  TLogThread = class(TThread)
  private
    FModules: IModules;
    FTaskList: TThreadList<TLogTask>;
    procedure ExecLogTask(ALogTask: TLogTask);
    procedure AddTask(ALogTask: TLogTask);
    function HasPendingTasks: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AModules: IModules);
    destructor Destroy; override;
    procedure Log(ALogSource, ALogText: string; ALogType: TLogType); overload;
    procedure Log(ALogSource, ALogTag, ALogText: string; ALogType: TLogType); overload;
  end;

implementation

uses ModuleManager;

constructor TLogThread.Create(AModules: IModules);
begin
  inherited Create(False);
  FModules := AModules;
  FreeOnTerminate := False;
  FTaskList := TThreadList<TLogTask>.Create;
end;

destructor TLogThread.Destroy;
begin
  FModules := nil;
  FTaskList.Free;
  inherited Destroy;
end;

procedure TLogThread.AddTask(ALogTask: TLogTask);
var
  List: TList<TLogTask>;
begin
  List := FTaskList.LockList;
  try
    List.Add(ALogTask);
  finally
    FTaskList.UnlockList;
  end;
end;

procedure TLogThread.ExecLogTask(ALogTask: TLogTask);
var
  lLog: ILog;
begin
  if not Assigned(FModules) then
    exit;
  for var I := 0 to FModules.Count - 1 do
    if (FModules.Modules[I].&Type = mdtLog) and (Supports(FModules.Modules[I], ILog, lLog)) then
    begin
      if ALogTask.Tagged then
        lLog.LogTagged(ALogTask.Source, ALogTask.Tag, ALogTask.Text, ALogTask.LogType)
      else
        lLog.Log(ALogTask.Source, ALogTask.Text, ALogTask.LogType);
    end;
end;

procedure TLogThread.Execute;
var
  List: TList<TLogTask>;
  lLogTask: TLogTask;
begin
  while (not Terminated) or HasPendingTasks do
  begin
    List := FTaskList.LockList;
    lLogTask := nil;
    try
      if List.Count > 0 then
        lLogTask := List.ExtractAt(0);
    finally
      FTaskList.UnlockList;
    end;
    if Assigned(lLogTask) then
    begin
      ExecLogTask(lLogTask);
      lLogTask.Free;
    end;
    Sleep(10);
  end;
end;

function TLogThread.HasPendingTasks: Boolean;
var
  lList: TList<TLogTask>;
begin
  lList := FTaskList.LockList;
  try
    Result := lList.Count > 0;
  finally
    FTaskList.UnlockList;
  end;
end;

procedure TLogThread.Log(ALogSource, ALogText: string; ALogType: TLogType);
var
  lLogTask: TLogTask;
begin
  if Terminated then
    exit;
  lLogTask := TLogTask.Create(ALogSource, '', ALogText, ALogType);
  AddTask(lLogTask);
end;

procedure TLogThread.Log(ALogSource, ALogTag, ALogText: string; ALogType: TLogType);
var
  lLogTask: TLogTask;
begin
  if Terminated then
    exit;
  lLogTask := TLogTask.Create(ALogSource, ALogTag, ALogText, ALogType);
  AddTask(lLogTask);
end;

{ TLogTask }

constructor TLogTask.Create(ASource, ATag, AText: string; ALogType: TLogType);
begin
  FTagged := ATag.Length > 0;
  FSource := ASource;
  FTag := ATag;
  FText := AText;
  FLogType := ALogType;
end;

end.
