unit Common;

interface

uses System.Classes,
  IShellInterface;

type
  TFSTaskType = (fsttSearcher, fsttContentScanner);

type
  TShellMainMenuItem = class(TInterfacedObject, IShellMainMenuItem)
  private
    FTitle: WideString;
    FTag: Integer;
    FOnClick: TNotifyEvent;
    FCommand: string;
    FArgs: string;
    procedure ParseData(ATask: string);
  protected
    function GetTitle: WideString; stdcall;
    function GetTag: Integer; stdcall;
  public
    constructor Create(ATitle: WideString; ATask: string; AOnClick: TNotifyEvent);
    destructor Destroy; override;
    procedure OnClickEvent; stdcall;
    procedure IShellMainMenuItem.OnClick = OnClickEvent;
    property Command: string read FCommand;
    property Args: string read FArgs;
    property Title: WideString read GetTitle;
    property Tag: Integer read GetTag write FTag;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

implementation

{ TShellMainMenuItem }
constructor TShellMainMenuItem.Create(ATitle: WideString; ATask: string; AOnClick: TNotifyEvent);
begin
  inherited Create;
  FTitle := ATitle;
  FOnClick := AOnClick;
  ParseData(ATask);
end;

destructor TShellMainMenuItem.Destroy;
begin

  inherited;
end;

procedure TShellMainMenuItem.ParseData(ATask: string);
var
  LStringList: TStringList;
begin
  LStringList := TStringList.Create;
  try
    LStringList.Text := ATask;
    if LStringList.Count > 0 then
    begin
      FCommand := LStringList.KeyNames[0];
      FArgs := LStringList.ValueFromIndex[0];
    end; // else raise error
  finally
    LStringList.Free;
  end;

end;

function TShellMainMenuItem.GetTag: Integer;
begin
  Result := FTag;
end;

function TShellMainMenuItem.GetTitle: WideString;
begin
  Result := FTitle;
end;

procedure TShellMainMenuItem.OnClickEvent;
begin
  if Assigned(FOnClick) then
    FOnClick(Self);
end;

end.
