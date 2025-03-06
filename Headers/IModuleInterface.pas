unit IModuleInterface;

interface

type
  TModuleType = Word;

const
  mdtLog = 0; // ILog
  // ...
  mtdPluginController = 10;
  mtdPluginGeneral = 250;
  mtdPluginTemplate = 255;

type
  IDestroyNotify = interface
    ['{9EC06229-36A3-44FE-BAA8-75CD05C21688}']
    procedure Delete; stdcall;
  end;

  ILoadNotify = interface
    ['{9AFD3F71-FBA7-490F-B6B8-C961782CE70A}']
    procedure AllModulesLoaded; stdcall;
  end;

  INotifyEvent = interface
    ['{A19EBB14-2E47-4A81-B726-7963E2865DC7}']
    procedure Execute(Sender: IInterface); stdcall;
  end;

  IModule = interface
    ['{571273F6-04A7-4925-B956-2AB950D316FE}']
    // private
    function GetID: PGUID; stdcall;
    function GetName: WideString; stdcall; // Const
    function GetType: TModuleType; stdcall;
    function GetUnique: LongBool; stdcall;
    function GetVersion: WideString; stdcall; // Const
    function GetDescription: WideString; stdcall; // Const
    // public
    property ID: PGUID read GetID;
    property Name: WideString read GetName;
    property &Type: TModuleType read GetType;
    property Unique: LongBool read GetUnique; // Allowed be only one module of this type in core modules array
    property Version: WideString read GetVersion;
    property Description: WideString read GetDescription;
  end;

implementation

end.
