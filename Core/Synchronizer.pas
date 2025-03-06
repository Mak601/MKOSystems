unit Synchronizer;

interface
uses  System.SyncObjs,
      System.Generics.Collections,
      ICoreInterface;

type
  TSyncList = class(TThreadList<ISynchronizer>)
  private
    function FindWithName(AName: string): ISynchronizer;
  public
    function GetSynchronizer(AName: string): ISynchronizer;
  end;

type
  TSynchronizer = class(TInterfacedObject, ISynchronizer)
  private
    FName: string;
    FCriticalSection: TCriticalSection;
  public
    constructor Create(AName: string);
    destructor Destroy; override;
    function GetName: WideString; stdcall;
    procedure Enter; stdcall;
    procedure Leave; stdcall;
    property Name: WideString read GetName;
  end;

implementation

{TSyncList}

function TSyncList.FindWithName(AName: string): ISynchronizer;
var LList: TList<ISynchronizer>;
    LSynchronizer: ISynchronizer;
begin
  Result := nil;
  LList := LockList;
  try
    for LSynchronizer in LList do
      if LSynchronizer.Name = AName then
      begin
        Result := LSynchronizer;
        Break;
      end;
  finally
    UnlockList;
  end;
end;

function TSyncList.GetSynchronizer(AName: string): ISynchronizer;
var LList: TList<ISynchronizer>;
    LSynchronizer: ISynchronizer;
begin
  LSynchronizer := FindWithName(AName);
  if not Assigned(LSynchronizer) then
  begin
    LList := LockList;
    try
      LSynchronizer := TSynchronizer.Create(AName);
      LList.Add(LSynchronizer);
      Result := LSynchronizer;
    finally
      UnlockList;
    end;
  end else Result := LSynchronizer;
end;

{TSynchronizer}

constructor TSynchronizer.Create(AName: string);
begin
  inherited Create;
  FName :=  AName;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TSynchronizer.Destroy;
begin
  FCriticalSection.Free;
  inherited Destroy;
end;

procedure TSynchronizer.Enter;
begin
  FCriticalSection.Enter;
end;

function TSynchronizer.GetName: WideString;
begin
  Result := FName;
end;

procedure TSynchronizer.Leave;
begin
  FCriticalSection.Leave;
end;

end.
