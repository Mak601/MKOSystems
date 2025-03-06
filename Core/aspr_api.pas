unit aspr_api;

interface

uses
  Windows;


type

  //' Mode status

  TModeStatus = packed record
    ModeID           : Byte;
    IsRegistered,
    IsKeyPresent,
    IsWrongHardwareID,
    IsKeyExpired,
    IsModeExpired,
    IsBlackListedKey,
    IsModeActivated  : Boolean;
  end;
  PModeStatus = ^TModeStatus;


function  GetRegistrationKeys: PAnsiChar; stdcall;

function  GetRegistrationInformation   ( ModeID : Byte; var Key : PAnsiChar; var Name : PAnsiChar ): Boolean; stdcall;

function  RemoveKey               ( ModeID : Byte ): Boolean; stdcall;

function  CheckKey                ( Key, Name : PAnsiChar; ModeStatus : PModeStatus ): Boolean; stdcall;

function  CheckKeyAndDecrypt      ( Key, Name : PAnsiChar; SaveKey: Boolean ): Boolean; stdcall;

function  GetKeyDate              (     ModeID : Byte;
                                    var Day    : WORD;
                                    var Month  : WORD;
                                    var Year   : WORD ): Boolean; stdcall;

function  GetKeyExpirationDate    (     ModeID : Byte;
                                    var Day    : WORD;
                                    var Month  : WORD;
                                    var Year   : WORD ): Boolean; stdcall;

function  GetTrialDays            (     ModeID : Byte;
                                    var Total  : DWORD;
                                    var Left   : DWORD ): Boolean; stdcall;

function  GetTrialExecs           (     ModeID : Byte;
                                    var Total  : DWORD;
                                    var Left   : DWORD ): Boolean; stdcall;

function  GetExpirationDate       (     ModeID : Byte;
                                    var Day    : WORD;
                                    var Month  : WORD;
                                    var Year   : WORD ): Boolean; stdcall;

function  GetModeInformation      (     ModeID     : Byte;
                                    var ModeName   : PAnsiChar;
                                    var ModeStatus : TModeStatus ): Boolean; stdcall;

function  GetHardwareID : PAnsiChar; stdcall;

function  GetHardwareIDEx         ( ModeID : Byte ) : PAnsiChar; stdcall;

function  SetUserKey              ( Key     : Pointer;
                                    KeySize : DWORD ): Boolean; stdcall;


implementation

const
  aspr_ide  = 'aspr_ide.dll';


//------------------------------------------------------------------------------

function  GetRegistrationKeys: PAnsiChar; external aspr_ide name 'GetRegistrationKeys';

function  GetRegistrationInformation   ( ModeID : Byte; var Key : PAnsiChar; var Name : PAnsiChar ): Boolean; external aspr_ide name 'GetRegistrationInformation';

function  RemoveKey               ( ModeID : Byte ): Boolean; external aspr_ide name 'RemoveKey';

function  CheckKey                ( Key, Name : PAnsiChar; ModeStatus : PModeStatus ): Boolean; external aspr_ide name 'CheckKey';

function  CheckKeyAndDecrypt      ( Key, Name : PAnsiChar; SaveKey: Boolean ): Boolean; external aspr_ide name 'CheckKeyAndDecrypt';

function  GetKeyDate              (     ModeID : Byte;
                                    var Day    : WORD;
                                    var Month  : WORD;
                                    var Year   : WORD ): Boolean; external aspr_ide name 'GetKeyDate';

function  GetKeyExpirationDate    (     ModeID : Byte;
                                    var Day    : WORD;
                                    var Month  : WORD;
                                    var Year   : WORD ): Boolean; external aspr_ide name 'GetKeyExpirationDate';

function  GetTrialDays            (     ModeID : Byte;
                                    var Total  : DWORD;
                                    var Left   : DWORD ): Boolean; external aspr_ide name 'GetTrialDays';

function  GetTrialExecs           (     ModeID : Byte;
                                    var Total  : DWORD;
                                    var Left   : DWORD ): Boolean; external aspr_ide name 'GetTrialExecs';

function  GetExpirationDate       (     ModeID : Byte;
                                    var Day    : WORD;
                                    var Month  : WORD;
                                    var Year   : WORD ): Boolean; external aspr_ide name 'GetExpirationDate';

function  GetModeInformation      (     ModeID     : Byte;
                                    var ModeName   : PAnsiChar;
                                    var ModeStatus : TModeStatus ): Boolean; external aspr_ide name 'GetModeInformation';

function  GetHardwareID : PAnsiChar; external aspr_ide name 'GetHardwareID';

function  GetHardwareIDEx         ( ModeID : Byte ) : PAnsiChar; external aspr_ide name 'GetHardwareIDEx';

function  SetUserKey              ( Key     : Pointer;
                                    KeySize : DWORD ): Boolean; external aspr_ide name 'SetUserKey';

//------------------------------------------------------------------------------

end.
