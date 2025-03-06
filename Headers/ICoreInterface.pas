unit ICoreInterface;

interface

uses
  IShellInterface,
  IModuleInterface,
  ILogInterface;

type
  ISynchronizer = interface
    ['{A7F31984-0814-424A-9D58-DFAB4D4A5906}']
    function GetName: WideString; stdcall;
    procedure Enter; stdcall;
    procedure Leave; stdcall;
    //
    property Name: WideString read GetName;
  end;

type
  ICore = interface
    ['{E74A7BB6-DC4E-4B88-817F-39B338E3765F}']
    function GetVersion: Integer; stdcall;
    procedure SetLog(ALog: ILog); stdcall;
    procedure ShutDown; stdcall;
    function GetShell: IShell; stdcall;
    function GetSynchronizer(AName: WideString): ISynchronizer; stdcall;
    // ...
    property Version: Integer read GetVersion;
    property OnLog: ILog write SetLog;
    property Shell: IShell read GetShell;
  end;

type
  IModules = interface
    ['{54FE6374-0054-4A4D-A73E-4B382185DFFA}']
    function GetCount: Integer; stdcall;
    function GetModule(const AIndex: Integer): IModule; stdcall;
    function GetHandle(const AIndex: Integer): Cardinal; stdcall;
    function GetFilename(const AIndex: Integer): WideString; stdcall;
    // ...
    property Count: Integer read GetCount;
    property Modules[const AIndex: Integer]: IModule read GetModule; default;
  end;

implementation

end.
