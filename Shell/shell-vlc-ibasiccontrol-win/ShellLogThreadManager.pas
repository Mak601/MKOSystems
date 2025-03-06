unit ShellLogThreadManager;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  IModuleInterface,
  ILogInterface,
  IShellInterface;

type
  TLogToMemoProc = procedure(AText: string; LogType: TLogType) of object;

type
  TLogTask = class(TObject)
  private
    FTagged: Boolean;
    FSource: string;
    FTag: string;
    FText: string;
    FLogType: TLogType;
  public
    constructor Create(ASource, ATag, AText: string; ALogType: TLogType);
    property Tagged: Boolean read FTagged;
    property Source: string read FSource;
    property Tag: string read FTag;
    property Text: string read FText;
    property LogType: TLogType read FLogType;
  end;

type
  TLogThread = class(TThread)
  private
    FLogToMemo: TLogToMemoProc;
    FTaskList: TThreadList<TLogTask>;
    procedure ExecLogTask(ALogTask: TLogTask);
    procedure AddTask(ALogTask: TLogTask);
    function HasPendingTasks: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Log(ALogSource, ALogText: string; ALogType: TLogType); overload;
    procedure Log(ALogSource, ALogTag, ALogText: string; ALogType: TLogType); overload;
    property LogToMemoProc: TLogToMemoProc read FLogToMemo write FLogToMemo;
  end;

implementation

constructor TLogThread.Create;
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FTaskList := TThreadList<TLogTask>.Create;
end;

destructor TLogThread.Destroy;
begin
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
  lLineType: string;
begin
  if not Assigned(FLogToMemo) then
    exit;

  case ALogTask.LogType of
    tlgInfo:
      lLineType := 'Info';
    tlgWarning:
      lLineType := 'Warning';
    tlgError:
      lLineType := 'Error';
  end;

  var
  thread := TThread.CurrentThread;
  thread.Synchronize(thread,
    procedure
    begin
      if ALogTask.Tagged then
        FLogToMemo(Format('TREAD! %s:(%s) -> %s', [ALogTask.Source, lLineType, ALogTask.Text]), ALogTask.LogType)
      else
        FLogToMemo(Format('TREAD! %s:(%s) %s -> %s', [ALogTask.Source, lLineType, ALogTask.Tag, ALogTask.Text]),
          ALogTask.LogType)
    end);

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
var
  lText: string;
begin
  FTagged := ATag.Length > 0;
  FSource := ASource;
  FTag := ATag;
  FText := AText;
  FLogType := ALogType;
end;

end.
