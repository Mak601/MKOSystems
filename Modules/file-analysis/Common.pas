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
    FTaskType: TFSTaskType;
    FFilePath: string;
    FFSRegexPattern: string;
    FFCSSequences: TStringList;
    procedure ParseData(ATaskType: TFSTaskType; ATask: string);
  protected
    function GetTitle: WideString; stdcall;
    function GetTag: Integer; stdcall;
  public
    constructor Create(ATitle: WideString; ATaskType: TFSTaskType; ATask: string; AOnClick: TNotifyEvent);
    destructor Destroy; override;
    procedure OnClickEvent; stdcall;
    procedure IShellMainMenuItem.OnClick = OnClickEvent;
    property TaskType: TFSTaskType read FTaskType write FTaskType;
    property FilePath: string read FFilePath;
    property FSRegexPattern: string read FFSRegexPattern;
    property FCSSequences: TStringList read FFCSSequences;
    property Title: WideString read GetTitle;
    property Tag: Integer read GetTag write FTag;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

implementation

{ TShellMainMenuItem }
constructor TShellMainMenuItem.Create(ATitle: WideString; ATaskType: TFSTaskType; ATask: string;
  AOnClick: TNotifyEvent);
begin
  inherited Create;
  FFCSSequences := TStringList.Create;
  FTitle := ATitle;
  FTaskType := ATaskType;
  FOnClick := AOnClick;
  ParseData(ATaskType, ATask);
end;

destructor TShellMainMenuItem.Destroy;
begin
  FFCSSequences.Free;
  inherited;
end;

procedure TShellMainMenuItem.ParseData(ATaskType: TFSTaskType; ATask: string);
var
  LStringList: TStringList;
begin
  LStringList := TStringList.Create;
  try
    LStringList.Text := ATask;
    if LStringList.Count > 0 then
    begin
      FFilePath := LStringList.KeyNames[0];
      FFSRegexPattern := LStringList.ValueFromIndex[0];
    end; // else raise error
  finally
    LStringList.Free;
  end;

  case ATaskType of
    fsttSearcher:
      begin
      end;
    fsttContentScanner:
      begin
        LStringList := TStringList.Create;
        try
          LStringList.Delimiter := ',';
          LStringList.StrictDelimiter := True;
          LStringList.DelimitedText := FFSRegexPattern;
          for var Sequence in LStringList do
            FFCSSequences.Add(Sequence);
        finally
          LStringList.Free;
        end;
      end;
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
