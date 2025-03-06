unit IShellInterface;

interface

uses System.Classes;

type
  IShell = interface(IInterface)
    ['{12021FB8-670D-4027-B846-7D3920F9C63F}']
  end;

type
  IShellMainMenuItem = interface(IInterface)
    ['{5EED38AF-5231-4D74-B94B-720A755838B5}']
    function GetTitle: WideString; stdcall;
    function GetTag: Integer; stdcall;
    procedure OnClick; stdcall;
    property Title: WideString read GetTitle;
  end;

type
  IShellMainMenu = interface(IInterface)
    ['{D44601E9-370D-4E02-B8D5-991D5CDD722D}']
    procedure AddMenuItem(Item: IShellMainMenuItem); stdcall;
    procedure RemoveMenuItem(Item: IShellMainMenuItem); stdcall;
  end;

type
  IShellBasicControl = interface(IInterface)
    ['{C08DC194-DE83-4A35-A2E4-B3F732D0C398}']
    procedure SetShellCaption(Text: WideString); stdcall;
    procedure SetStatusBarText(Text: WideString); stdcall;
    function AddMainMenu(Title: WideString): IShellMainMenu; stdcall;
    // Remove from main GUI thread, should be used from main thread
    procedure RemoveQueuedEvents(AThread: TThread); stdcall;
    procedure Processmessages; stdcall; // The Application.Processmessages handles all waiting messages
  end;

implementation

end.
