unit ProcessThread;

interface

uses
  System.SysUtils,
  Windows,
  Classes;

type
  TProcessThread = class(TThread)
  private
    FCommand: string;
    FParameters: string;
    FOutput: string;
    FOnResult: TNotifyEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACommand: string; const AParameters: string; AOnResult: TNotifyEvent);
    property Command: string read FCommand;
    property Parameters: string read FParameters;
    property Output: string read FOutput;
    property OnResult: TNotifyEvent read FOnResult write FOnResult;
  end;

function OEMToAnsi(const OEMStr: AnsiString): AnsiString;
function RunConsoleCommand(const ACommand: string; const AParameters: string; out AOutput: string): Boolean;

implementation

function OEMToAnsi(const OEMStr: AnsiString): AnsiString;
var
  Len: Integer;
begin
  Len := Length(OEMStr);
  SetLength(Result, Len);
  if Len > 0 then
    OemToCharBuffA(PAnsiChar(OEMStr), PAnsiChar(Result), Len);
end;

function RunConsoleCommand(const ACommand: string; const AParameters: string; out AOutput: string): Boolean;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  SecurityAttributes: TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  Buffer: array [0 .. 4095] of AnsiChar;
  BytesRead: DWORD;
  OutputStream: TStringStream;
begin
  Result := False;
  AOutput := '';

  SecurityAttributes.nLength := SizeOf(TSecurityAttributes);
  SecurityAttributes.bInheritHandle := True;
  SecurityAttributes.lpSecurityDescriptor := nil;

  if not CreatePipe(ReadPipe, WritePipe, @SecurityAttributes, 0) then
    RaiseLastOSError;

  try
    ZeroMemory(@StartupInfo, SizeOf(TStartupInfo));
    StartupInfo.cb := SizeOf(TStartupInfo);
    StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.hStdOutput := WritePipe;
    StartupInfo.hStdError := WritePipe;
    StartupInfo.wShowWindow := SW_HIDE;

    ZeroMemory(@ProcessInfo, SizeOf(TProcessInformation));

    // Создаем процесс
    if not CreateProcess(nil, PChar(ACommand + ' ' + AParameters), nil, nil, True, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
    begin
      RaiseLastOSError;
    end;

    try
      CloseHandle(WritePipe);
      OutputStream := TStringStream.Create;
      try
        while ReadFile(ReadPipe, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) do
        begin
          OutputStream.Write(Buffer, BytesRead);
        end;

        AOutput := OutputStream.DataString;
      finally
        OutputStream.Free;
      end;

      WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
      Result := True;
    finally
      CloseHandle(ProcessInfo.hProcess);
      CloseHandle(ProcessInfo.hThread);
    end;
  finally
    CloseHandle(ReadPipe);
  end;
end;

constructor TProcessThread.Create(const ACommand: string; const AParameters: string; AOnResult: TNotifyEvent);
begin
  inherited Create;
  FCommand := ACommand;
  FParameters := AParameters;
  FOnResult := AOnResult;
end;

procedure TProcessThread.Execute;
begin
  inherited;
  try
    RunConsoleCommand(FCommand, FParameters, FOutput);
  except
    on E: Exception do
      FOutput := E.Message;
  end;
  if Assigned(FOnResult) then
    FOnResult(Self);
end;

end.
