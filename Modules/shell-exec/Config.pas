unit Config;

interface

uses
  System.Classes,
  System.SysUtils,
  IniFiles;

const
  csIniMainSection = 'Main';
  csIniMainCount = 'Count';

type
  TIniOptions = class(TObject)
  private
    FIni: TIniFile;
    FShellExecCmds: TStringList;
  public
    procedure LoadSettings(Ini: TIniFile);
    procedure LoadFromFile(const FileName: string);
    constructor Create;
    destructor Destroy; override;
    property ShellExecCmds: TStringList read FShellExecCmds;
  end;

implementation

constructor TIniOptions.Create;
begin
  inherited;
  FShellExecCmds := TStringList.Create;
end;

destructor TIniOptions.Destroy;
begin
  FShellExecCmds.Free;
  inherited;
end;

procedure TIniOptions.LoadSettings(Ini: TIniFile);
var
  LCount: Integer;
  LCmds: TStringList;
begin
  if Ini <> nil then
  begin
    { Section: Main }
    FIni := Ini;
    LCount := Ini.ReadInteger(csIniMainSection, csIniMainCount, 0);
    for var I := 0 to LCount - 1 do
    begin
      LCmds := TStringList.Create;
      try
        Ini.ReadSectionValues(Format('Cmd_%d', [I]), LCmds);
        FShellExecCmds.AddStrings(LCmds);
      finally
        LCmds.Free;
      end;
    end;
  end;
end;

procedure TIniOptions.LoadFromFile(const FileName: string);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FileName);
  try
    LoadSettings(Ini);
  finally
    Ini.Free;
  end;
end;

end.
