unit FileSeacher;

interface

uses
  System.Classes,
  System.SysUtils,
  System.RegularExpressions,
  System.IOUtils;

type
  TFileSeacher = class
  private
    FRegex: TRegEx;
    procedure ScanDirectory(const ADirectory: string; var AFileList: TStringList);
  public
    constructor Create(const ARegexPattern: string);
    procedure GetFiles(const ADirectory: string; var AFileList: TStringList);
  end;

implementation

constructor TFileSeacher.Create(const ARegexPattern: string);
begin
  inherited Create;
  FRegex := TRegEx.Create(ARegexPattern);
end;

procedure TFileSeacher.ScanDirectory(const ADirectory: string; var AFileList: TStringList);
var
  Files: TArray<string>;
  Directories: TArray<string>;
  FileName: string;
  Directory: string;
begin
  Files := TDirectory.GetFiles(ADirectory);
  for FileName in Files do
  begin
    if FRegex.IsMatch(ExtractFileName(FileName)) then
      AFileList.Add(FileName);
  end;

  Directories := TDirectory.GetDirectories(ADirectory);
  for Directory in Directories do
  begin
    ScanDirectory(Directory, AFileList);
  end;
end;

procedure TFileSeacher.GetFiles(const ADirectory: string; var AFileList: TStringList);
begin
  if not TDirectory.Exists(ADirectory) then
  begin
    AFileList.Add('Directory does not exist: ' + ADirectory);
    exit;
  end;

  AFileList.Clear;
  ScanDirectory(ADirectory, AFileList);
end;

end.
