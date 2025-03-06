unit ILogInterface;

interface

uses
  IModuleInterface;

type
  TLogType = Word;

const
  tlgInfo = 0;
  tlgWarning = 1;
  tlgError = 2;
  tlgDebug = 10;

type
  ILog = interface
    ['{814F1D73-9E77-42A5-A818-58AB63EEF09C}']
    procedure Log(ALogSource, ALogText: WideString; ALogType: TLogType); stdcall;
    procedure LogTagged(ALogSource, ALogTag, LogText: WideString; ALogType: TLogType); stdcall;
  end;

implementation

end.
