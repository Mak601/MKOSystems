unit FileContentScanner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TFileContentScanner = class
  private
    FPatterns: TList<TBytes>; // Список искомых последовательностей
    function FindMatches(const AFileName: string; const APattern: TBytes): TList<Int64>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddPattern(const APattern: string); // Добавление последовательности для поиска
    procedure Search(const AFileName: string; var AFileList: TStringList); // Поиск в файле
  end;

implementation

constructor TFileContentScanner.Create;
begin
  inherited;
  FPatterns := TList<TBytes>.Create;
end;

destructor TFileContentScanner.Destroy;
begin
  FPatterns.Free;
  inherited;
end;

procedure TFileContentScanner.AddPattern(const APattern: string);
begin
  FPatterns.Add(TEncoding.ANSI.GetBytes(APattern));
end;

procedure TFileContentScanner.Search(const AFileName: string; var AFileList: TStringList);
var
  Pattern: TBytes;
  PatternStr: string;
  Matches: TList<Int64>;
begin
  if not FileExists(AFileName) then
  begin
    AFileList.Add('File not found: ' + AFileName);
    Exit;
  end;

  AFileList.Add('File name: ' + AFileName);

  for Pattern in FPatterns do
  begin
    var
      MatchesPosStr: string;
    PatternStr := TEncoding.ANSI.GetString(Pattern);
    Matches := FindMatches(AFileName, Pattern);
    for var I in Matches do
      MatchesPosStr := MatchesPosStr + Format('%d,', [I]);
    if not MatchesPosStr.IsEmpty then
      Delete(MatchesPosStr, MatchesPosStr.Length, 1);
    AFileList.Add(Format('Sequence: %s, Count: %d, Positions: %s', [PatternStr, Matches.Count, MatchesPosStr]));
  end;
end;

function TFileContentScanner.FindMatches(const AFileName: string; const APattern: TBytes): TList<Int64>;
var
  Stream: TFileStream;
  Buffer: array of Byte;
  BytesRead, I, j: Integer;
  MatchPos: Int64;
  PatternLength: Integer;
begin
  Result := TList<Int64>.Create;
  PatternLength := Length(APattern);
  if PatternLength = 0 then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Buffer, PatternLength);
    MatchPos := 0;

    while Stream.Position < Stream.Size do
    begin
      BytesRead := Stream.Read(Buffer[0], PatternLength);
      if BytesRead < PatternLength then
        Break;

      // Поиск совпадения
      I := 0;
      while I <= BytesRead - PatternLength do
      begin
        j := 0;
        while (j < PatternLength) and (Buffer[I + j] = APattern[j]) do
          Inc(j);

        if j = PatternLength then
        begin
          Result.Add(MatchPos + I);
          Inc(I, PatternLength);
        end
        else
        begin
          Inc(I);
        end;
      end;

      MatchPos := Stream.Position - BytesRead;
      Stream.Position := MatchPos + 1;
    end;
  finally
    Stream.Free;
  end;
end;

end.
