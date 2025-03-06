unit Config;

interface

uses
  System.Classes,
  System.SysUtils,
  IniFiles;

const
  csIniFileSearcherSection = 'FileSearcher';
  csIniFileContentScannerSection = 'FileContentScanner';

type
  TIniOptions = class(TObject)
  private
    FIni: TIniFile;
    FFileSearcherTasks: TStringList;
    FFileContentScannerTasks: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadSettings(Ini: TIniFile);
    procedure LoadFromFile(const FileName: string);
    property FileSearcherTasks: TStringList read FFileSearcherTasks;
    property FileContentScannerTasks: TStringList read FFileContentScannerTasks;
  end;

implementation

constructor TIniOptions.Create;
begin
  inherited;
  FFileSearcherTasks := TStringList.Create;
  FFileContentScannerTasks := TStringList.Create;
end;

destructor TIniOptions.Destroy;
begin
  FFileSearcherTasks.Free;
  FFileContentScannerTasks.Free;
  inherited;
end;

procedure TIniOptions.LoadSettings(Ini: TIniFile);
begin
  if Ini <> nil then
  begin
    FIni := Ini;
    Ini.ReadSectionValues(csIniFileSearcherSection, FFileSearcherTasks);
    Ini.ReadSectionValues(csIniFileContentScannerSection, FFileContentScannerTasks);
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
