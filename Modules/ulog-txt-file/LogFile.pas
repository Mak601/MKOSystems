unit LogFile;

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------
interface

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------
uses
  {$IFDEF LINUX}
  Posix.Stdio,
  Posix.Unistd,
  {$ENDIF }
  IdGlobalProtocols,
  SysUtils, Classes;

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------
type
  // Events used by TLogToFile
  TBeforeWriteToLogEvent   = Procedure(Const NewText     :String;
                                       Const SpaceBefore :Integer;
                                       Const SpaceAfter  :Integer;
                                       Const FileName    :String)  of Object;
  TAfterWriteToLogEvent    = Procedure(Const NewText     :String;
                                       Const SpaceBefore :Integer;
                                       Const SpaceAfter  :Integer;
                                       Const FileName    :String)  of Object;


  //----------------------------------------------------------------------------
  // TLogFileObj
  //   A helper object for TLogToFile.
  //----------------------------------------------------------------------------
  TLogFileObj = Class(TObject)
  Private
    FLogFileName     :String;          // Not really used at this point...
    FLogFile         :TextFile;        // The Text File handle to be written to
  Protected

  Public
    constructor Create;
    destructor  Destroy; override;

    Property LogFileName     :String     read FLogFileName    write FLogFileName;
    Property LogFile         :TextFile   read FLogFile        write FLogFile;
  End; // TLogFileObj


  //----------------------------------------------------------------------------
  // TLogtoFile
  //----------------------------------------------------------------------------
  TLogToFile = class(TComponent)
  private
    { Private declarations }
    FLogFileName            : String;         // Name of File used to store Log Entries
    FMaxSize                : Integer;        // Limits the LogFile to X MB of Disk Space before creating a history file
    FMaxHistory             : Integer;        // How Many Levels of history will the component keep...
    FOverwriteExistingFile  : Boolean;        // Overwrite the file - Don't append
    FClearonCreate          : Boolean;        // Clear the existing file on create - even if Overwrite is set to False
    FIncDateTime            : Boolean;        // Include the Date/Time in the Log
    FIncPrefix              : Boolean;        // Include the Prefix String in the Log
    FIncSeparator           : Boolean;        // Include the Sperator String in the Log
    FIncSuffix              : Boolean;        // Include the Suffix String in the Log
    FPrefix                 : String;         // Prefix String that may be included in the Log
    FSeparator              : String;         // Seperator String that may be included in the Log
    FSuffix                 : String;         // Suffix String that may be included in the Log
    FDateTimeFormatStr      : String;         // Format to use with FormatDateTime - used to output TimeStamp to Log
    FLogTags                : TStringList;    // Used to control which statements will actually be logged...
    FLoggingActive          : Boolean;        // Used to determine if the Logging should be done
                                              //  I use this so that I don't have to put If statements around my WriteToLogFile methods
    FArchiveActive          : Boolean;        // Used to control whether Archiving is active or not...
    FLogFiles               : TStringList;    // Used to hold the Log Files that will be kept open
    FOnBeforeWriteToLog     : TBeforeWriteToLogEvent;
    FOnAfterWriteToLog      : TAfterWriteToLogEvent;
    //FLog:TShellLog;

  protected
    { Protected declarations }
    Function GetFullPathName(Const FileName :String = '') :String;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    Procedure   Loaded; Override;

    Function    CreateLogFile(Const FileName :String = '') :Integer;
    Procedure   CloseLogFile(Const FileName :String = '');
    Procedure   WriteToLogFile(Const NewText     :String;
                               Const SpaceBefore :Integer = 0;
                               Const SpaceAfter  :Integer = 0;
                               Const KeepOpen    :Boolean = False;
                               Const LogTag      :String  = 'All';
                               Const FileName    :String  = '');
    Function    StripOffTrailingSlash(Const sDirectory :String) :String;
    Procedure   ArchiveLogFiles(Const FileName :String = '');
    Procedure   ClearLogFile(Const FileName :String);

    Procedure   ClearLogFileList;
    Function    LogFileAlreadyOpen(Const FileName :String) :Boolean;
    Procedure   CloseOpenLogFile(Const Index :Integer = 0);
    Function    GetFileObjIndex(Const FileName :String) : Integer;
    Function    FileIsOpen(var F :TextFile): boolean;
  public
    { Published declarations }
    Property  LogFileName            : String        read FLogFileName             write FLogFileName;
    Property  OverwriteExistingFile  : Boolean       read FOverwriteExistingFile   write FOverwriteExistingFile;
    Property  ClearonCreate          : Boolean       read FClearonCreate           write FClearonCreate;

    Property  IncDateTime            : Boolean       read FIncDateTime             write FIncDateTime;
    Property  IncPrefix              : Boolean       read FIncPrefix               write FIncPrefix;
    Property  IncSeparator           : Boolean       read FIncSeparator            write FIncSeparator;
    Property  IncSuffix              : Boolean       read FIncSuffix               write FIncSuffix;
    Property  Prefix                 : String        read FPrefix                  write FPrefix;
    Property  Separator              : String        read FSeparator               write FSeparator;
    Property  Suffix                 : String        read FSuffix                  write FSuffix;
    Property  MaxSize                : Integer       read FMaxSize                 write FMaxSize;
    Property  MaxHistory             : Integer       read FMaxHistory              write FMaxHistory;
    // DateTimeFormatStr property assumes the values described in "FormatDateTime Function" in Delphi Help
    Property  DateTimeFormatStr      : String        read FDateTimeFormatStr       write FDateTimeFormatStr;
    Property  LoggingActive          : Boolean       read FLoggingActive           write FLoggingActive;
    Property  LogTags                : TStringList   read FLogTags                 write FLogTags;
    Property  ArchiveActive          : Boolean       read FArchiveActive           write FArchiveActive;

    property  OnAfterWriteToLog      : TAfterWriteToLogEvent    read FOnAfterWriteToLog        write FOnAfterWriteToLog;
    property  OnBeforeWriteToLog     : TBeforeWriteToLogEvent   read FOnBeforeWriteToLog       write FOnBeforeWriteToLog;

  end;

Function  TAGetFileSize(Const FileName :String) :Int64;


implementation

// -----------------------------------------------------------------------------
//  TAGetFileSize
//    - This routine gets the file size for a file passed to it...
// -----------------------------------------------------------------------------
//{$IFDEF Win32}
{Function TAGetFileSize(Const FileName :STring) :Int64;

// -----------------------------------------------------------------------------
  procedure CardinalsToI64(var I: Int64; const LowPart, HighPart: Cardinal);
  begin
    Windows.ULARGE_INTEGER(I).LowPart := LowPart;
    Windows.ULARGE_INTEGER(I).HighPart := HighPart;
  end;
// -----------------------------------------------------------------------------
var
  fLOdword   : dword;
  fHIdword   : dword;
  Filesize   : Int64;
  FileHandle : THandle;
begin
  If FileExists(FileName) Then Begin
    FileHandle := CreateFile(PChar(FileName),
        GENERIC_READ, FILE_SHARE_READ,
                nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    Try
      fLOdword := GetFileSize(FileHandle, @fHIdword);
      CardinalsToI64(Filesize, fLOdword, fHIdword);
    Finally
      CloseHandle(FileHandle);
    End; // Try..Finally
  End Else Begin
    FileSize := -1;
  End;
  Result := FileSize;
End;  // TAGetFileSize}
//{$ELSE}
Function TAGetFileSize(Const FileName :STring) :Int64;
begin
   Result := FileSizeByName(FileName);
end;
//{$ENDIF}


//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// TLogFileObj
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

//----------------------------------------------------------------------------
//
//----------------------------------------------------------------------------
constructor TLogFileObj.Create;
Begin
  inherited;
  FLogFileName            := '';
End;  { Create }

//----------------------------------------------------------------------------
//
//----------------------------------------------------------------------------
destructor  TLogFileObj.Destroy;
Begin
  inherited;
End;  { Destroy }


//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// TLogToFile
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------


//----------------------------------------------------------------------------
//
//----------------------------------------------------------------------------
constructor TLogToFile.Create(AOwner: TComponent);
Begin
  inherited;

  FLogFileName            := 'LogFile.Txt';
  FOverwriteExistingFile  := False;
  FIncDateTime            := False;
  FIncPrefix              := False;
  FIncSeparator           := False;
  FIncSuffix              := False;
  FPrefix                 := '';
  FSeparator              := '';
  FSuffix                 := '';
  FDateTimeFormatStr      := 'c';
  FLoggingActive          := True;
  FLogTags                := TStringList.Create;
  FClearonCreate          := False;
  FLogFiles               := TStringList.Create;
  FArchiveActive          := True;  
End;  { Create }

//----------------------------------------------------------------------------
//
//----------------------------------------------------------------------------
destructor  TLogToFile.Destroy;
Begin
  FLogTags.Free;

  // Need to clear any open Files - so that no memory leaks...
  ClearLogFileList;
  FLogFiles.Free;

  inherited;
End;  { Destroy }


//-----------------------------------------------------------------------------}
//  Loaded - runs right after Create...
//     Used to have the file cleared upon creating the object.  It is only used
//      to not have to call the ClearLogFile when first creating the object...
//-----------------------------------------------------------------------------}
Procedure TLogToFile.Loaded;
var
  SaveOverwriteExistingFile  :Boolean;
Begin
  // Quick and Dirty fix.  Will Make better later....
  If ClearonCreate Then Begin
    // First Create/Open the LogFile
    SaveOverwriteExistingFile := FOverwriteExistingFile;
    Try
      FOverwriteExistingFile    := ClearonCreate;
      CreateLogFile;
      CloseLogFile;
    Finally
      FOverwriteExistingFile := SaveOverwriteExistingFile;
    End;  { Try..Finally }
  End;  { If ClearonCreate }
End; { Loaded }

//-----------------------------------------------------------------------------
// Purpose     : To Create/Assign/Open the log file
//
//-----------------------------------------------------------------------------
Function TLogToFile.CreateLogFile(Const FileName :String = '') :Integer;
Var
  CurrFileName   :String;
  TempLogFileObj :TLogFileObj;
Begin
  Try
    // Get the full path name
    CurrFileName := GetFullPathName(FileName);
    //Log(CurrFileName);
    // Now Check to see if the file is already in use
    If NOT LogFileAlreadyOpen(CurrFileName) Then Begin
      // Now Create the LogFileObj...
      TempLogFileObj             := TLogFileObj.Create;
      TempLogFileObj.LogFileName := CurrFileName;

      // Assign the TextFile Variable to the new name...
      AssignFile(TempLogFileObj.LogFile, CurrFileName);

      // Now check to see if the file exists - if it does - then Append to it - unless overwrite flag is set.
      If FileExists(CurrFileName) and Not FOverwriteExistingFile then Begin
         Append(TempLogFileObj.LogFile);
      End Else Begin
         Rewrite(TempLogFileObj.LogFile);
      End;  { If FileExists(FLogFileName) }

      // Now Add the LogFileObj to the StringList - so it can be used to close it later...
      Result := FLogFiles.AddObject(UpperCase(CurrFileName), TempLogFileObj);
    End Else Begin
      // Get the Index for the open file...
      Result := GetFileObjIndex(CurrFileName);
    End; // If Already Open
  Except
    Result := -1;
  End;  { Try..Except }
End;  { CreateLogFile }


//------------------------------------------------------------------------------
// Purpose     : To Close the Log File.
//------------------------------------------------------------------------------
Procedure TLogToFile.CloseLogFile(Const FileName :String = '');
Var
  LogFileIndex  :Integer;
  CurrFileName  :String;
Begin
  // Get the full path name
  CurrFileName := GetFullPathName(FileName);

  // First - find which one to close
  LogFileIndex := FLogFiles.IndexOf(UpperCase(CurrFileName));
  If LogFileIndex <> -1 Then Begin
    CloseOpenLogFile(LogFileIndex);
  End; // If

End;  { CloseLogFile }


//-----------------------------------------------------------------------------
// Purpose     : To Close the Log File.
//
//-----------------------------------------------------------------------------
Function TLogToFile.GetFullPathName(Const FileName :String = '') :String;
Var
  TempFileName   :String;
Begin
  // First Find out which file to use
  If (FileName = '') then Begin
    TempFileName := FLogFileName;
  End Else Begin
    TempFileName := FileName;
  End;  // If FileName

  // Check to see if the file name starts with 'x:'  - ie specified full path!
 {$IFDEF MSWINDOWS}
  If Not ((Copy(TempFileName,2,1) = ':') or (Copy(TempFileName,1,2) = '\\')) Then
  {$ELSE}
  If Not ((Copy(TempFileName,1,1) = '/') or (Copy(TempFileName,1,2) = '//')) Then
 {$ENDIF}
  Begin
    TempFileName := ExpandFileName(TempFileName);     {Get full path from relative}
  End;  { If LogFileName has a Drive letter in it }

  Result := TempFileName;
End;  // GetFullPathName


//------------------------------------------------------------------------------
// Purpose     :  To write the passed text out to the log file.
//
// Parameters  :
// Input       :
//     1.  NewText       :String
//           This is the text to be written out to the log
//     2.  SpaceBefore   :Integer
//           This is the number of Lines to skip before writting out the text
//     3.  SpaceAfter    :Integer
//           This is the number of Lines to skip after writting out the text
//     4.  KeepOpen      :Boolean
//           This determines whether the file is closed after each write or not
//     5.  LogTag        :String
//           This String determines whether the LogToFile component will write
//           out to the log file.  (See notes at top for more info)
//     6.  FileName      :String
//           This string holds the name of the file to be written to.  You can
//           make each call to WritetoLogFile write to a different log file if
//           you so wish.
// Output      :
//
//------------------------------------------------------------------------------
Procedure TLogToFile.WriteToLogFile(Const NewText     :String;
                                    Const SpaceBefore :Integer = 0;
                                    Const SpaceAfter  :Integer = 0;
                                    Const KeepOpen    :Boolean = False;
                                    Const LogTag      :String  = 'All';
                                    Const FileName    :String  = '');
Var
  i                :Integer;
  szLogHeader      :String;
  TempLogFileIndex :Integer;
  CurrFileName     :String;
Begin
  // Only Log - if the user has set LoggingActive to True
  If FLoggingActive Then Begin
    // Get the full path name
    CurrFileName := GetFullPathName(FileName);
    //Log('Log file name: '+CurrFileName);
    // Now Check the LogTags StringList to see if this should be logged
    If (UpperCase(LogTag) <> 'ALL') Then Begin
      // If Not All - then only log if LogTag in LogTags list
      If  (FLogTags.IndexOf(LogTag) = -1) Then Begin
        Exit;  // If not match then end the procedure
      End; // If not in List
    End; // If ALL

    // First Create/Open the LogFile
    TempLogFileIndex := CreateLogFile(CurrFileName);

    {Event Generation }
    If Assigned(FOnBeforeWriteToLog) then FOnBeforeWriteToLog(NewText, SpaceBefore, SpaceAfter, CurrFileName);


    // Write out the appropriate number of spaces before hand...
    For i := 1 To SpaceBefore Do Begin
      WriteLn(TLogFileObj(FLogFiles.Objects[TempLogFileIndex]).LogFile);
    End;  { For i }

    // Create the formatted output message
    szLogHeader := '';
    // do you need a prefix
    If IncPrefix Then Begin
      szLogHeader := Prefix;
    End;  { If IncPrefix }

    // do you need a timestamp
    If IncDateTime Then begin
      // if no format supplied, default it to "c"
      If DateTimeFormatStr = '' Then Begin
        DateTimeFormatStr := 'c';
      End;  { If DataTimeFormatStr }

      szLogHeader := szLogHeader + FormatDateTime( DateTimeFormatStr, Now);
    end;

    // do you need a separator
    If IncSeparator Then Begin
      szLogHeader := szLogHeader + Separator;
    End; { If IncSeperator }

    // do you need a suffix
    If IncSuffix Then Begin
      // Now write out the actual Text to the file
      WriteLn(TLogFileObj(FLogFiles.Objects[TempLogFileIndex]).LogFile, szLogHeader + NewText + Suffix);
    End Else Begin
      WriteLn(TLogFileObj(FLogFiles.Objects[TempLogFileIndex]).LogFile, szLogHeader + NewText);
    End; { If IncSuffix }

    // Write out the appropriate number of spaces after writing the text
    For i := 1 To SpaceAfter Do Begin
      WriteLn(TLogFileObj(FLogFiles.Objects[TempLogFileIndex]).LogFile);
    End;  { For i }

    // Now Close the LogFile
    If Not KeepOpen Then Begin
      CloseLogFile(CurrFileName);
    End; // If

    // Now Check for File Size and create history if required.
    ArchiveLogFiles(CurrFileName);

    {Event Generation }
    If Assigned(FOnAfterWriteToLog) then FOnAfterWriteToLog(NewText, SpaceBefore, SpaceAfter, CurrFileName);


  End;  { If LoggingActive }
End; { WriteToLogFile }


//------------------------------------------------------------------------------
// Purpose: This routine takes a directory path - and strips off the trailing '\'
//            if it exists...
//------------------------------------------------------------------------------
Function  TLogToFile.StripOffTrailingSlash(Const sDirectory :String) :String;
Begin
  // Strip off the Last '\' if it exists...
  If sDirectory[Length(sDirectory)] = PathDelim Then
  Begin
    Result := Copy(sDirectory,1,(Length(sDirectory) - 1));
  End
  Else
  Begin
    Result := sDirectory;
  End;
End;  { StripOffTrailingSlash }



//------------------------------------------------------------------------------
//  Purpose   :  This routine makes backups of the existing log files by creating
//                a series of backups (log1, log2, log3, etc.).  It also then
//                allows the program to create a new clean log...
//
//  NOTE      :  This routine is called by the LIPToCCRS Datamodule.  It is done
//                there to create a backup of the logs for each full run.
//------------------------------------------------------------------------------
Procedure TLogToFile.ArchiveLogFiles(Const FileName :String = '');
Var
  i            :Integer;
  BaseFileName :String;
  TempFileName :String;
  TempFileExt  :String;
  BasePath     :String;
  OldFileName  :String;
  NewFileName  :String;
  CurrSize     :Int64;
  CurrFileName :String;

Begin
  // File to Use
  CurrFileName := GetFullPathName(FileName);

  // Now First Determine if we need to Archive...
  If FArchiveActive and (MaxSize > 0) Then Begin
    If FileExists(LogFileName) then Begin
      TempFileName     := ExtractFileName(CurrFileName);
      TempFileExt      := ExtractFileExt(CurrFileName);
      BasePath         := ExtractFilePath(CurrFileName);

      CurrSize := TAGetFileSize(CurrFileName);

      If CurrSize > MaxSize Then Begin
        // Get the base file name before the '.'
        BaseFileName := Copy(TempFileName,1,Pos('.',TempFileName) - 1);

        // Now deal with existing files - delete and rename
        For i := MaxHistory downto 1 do begin
          // CurrFileName - is I + 1 - so that if i=5 then it would be Events6.log
          OldFileName := BasePath {+ '\'} + BaseFileName + IntToStr(i + 1) {+ '.'} + TempFileExt;
          NewFileName := BasePath {+ '\'} + BaseFileName + IntToStr(i) {+ '.'} + TempFileExt;
          IF FileExists(OldFileName) Then begin
            DeleteFile(OldFileName);
          End; // If LogFileExists

          // Now rename it to the NewFileName
          RenameFile(NewFileName, OldFileName);
        End; // For

        // Now rename the current one...
        RenameFile(BasePath+TempFileName, NewFileName);

      End; // If CurrSize > MaxSize
    End; // If Exists
  End; // If MaxSize > 0
End;  // Archive Log Files



//------------------------------------------------------------------------------
//  Purpose   :  This routine is used to clear the log file of all text...
//------------------------------------------------------------------------------
Procedure   TLogToFile.ClearLogFile(Const FileName :String);
Var
  LogFileIndex   :Integer;
  CurrFileName   :String;
  TempLogFile    :TextFile;
Begin
//  Index := GetFileObjIndex(FileName);
  // Get the full path name
  CurrFileName := GetFullPathName(FileName);

  // First - find which one to close
  LogFileIndex := FLogFiles.IndexOf(UpperCase(CurrFileName));
  If LogFileIndex <> -1 Then Begin
    CloseOpenLogFile(LogFileIndex);
  End Else Begin
    // Clear a non-open Log...

    // Assign the TextFile Variable to the new name...
    AssignFile(TempLogFile, CurrFileName);

    // Now Overwrite the file
    Rewrite(TempLogFile);
    CloseFile(TempLogFile);
  End; // If logfile open
End; // ClearLogFile


//------------------------------------------------------------------------------
//  Purpose   :  This routine is used to clear the log file list - but should
//                only be cleared when the LogToFile object is destroyed...
//------------------------------------------------------------------------------
Procedure   TLogToFile.ClearLogFileList;
Begin
  While FLogFiles.Count > 0 Do Begin
    CloseOpenLogFile(0);
  End; // While

  // Now clear the list
  FLogFiles.Clear;
End; // ClearLogFileList

//------------------------------------------------------------------------------
//  Purpose   :  This routine is used to close an open log file based on Index
//------------------------------------------------------------------------------
Procedure TLogToFile.CloseOpenLogFile(Const Index :Integer = 0);
Begin
  // First close it if it is open
  If FileIsOpen(TLogFileObj(FLogFiles.Objects[Index]).FLogFile) Then Begin
    CloseFile(TLogFileObj(FLogFiles.Objects[Index]).LogFile);
  End; // If Open

  // Then Destroy the object
  TLogFileObj(FLogFiles.Objects[Index]).Free;

  FLogFiles.Delete(Index);
End; // CloseLogFile

//------------------------------------------------------------------------------
//  Purpose   :  This routine is used to check if the Log file is already open
//------------------------------------------------------------------------------
Function    TLogToFile.LogFileAlreadyOpen(Const FileName :String) :Boolean;
Begin
  // Basically - if it is in the list - then it should be open...
  If (FLogFiles.IndexOf(UpperCase(FileName)) <> -1) Then Begin
    Result := True;
  End Else Begin
    Result := False;
  End; // If
End; // LogFileAlreadyOpen


//------------------------------------------------------------------------------
//  Purpose   :  This routine is used get the index of the FileName in the
//                Open LogFile List
//------------------------------------------------------------------------------
Function   TLogToFile.GetFileObjIndex(Const FileName :String) : Integer;
Begin
  Result := FLogFiles.IndexOf(UpperCase(FileName));
End; // GetFileObjIndex


//------------------------------------------------------------------------------
//  Purpose   :  This routine is used to determine if a file variable is open
//------------------------------------------------------------------------------
Function TLogToFile.FileIsOpen(var F :TextFile): boolean;
Begin
   result := (TTextRec(F).Handle <> 0);
End; // FileIsOpen


{-----------------------------------------------------------------------------}
{ Initialization                                                              }
{ Purpose     :  To create the instance of the TLogToFile Object              }
{                                                                             }
{-----------------------------------------------------------------------------}
{Initialization
  LogToFile                        := TLogToFile.Create(Nil);
  LogToFile.LogFileName            := 'LogLogFile.Txt';
  LogToFile.OverwriteExistingFile  := False;
  LogToFile.LoggingActive          := True;
  LogToFile.MaxSize                := 5000000;
  LogToFile.MaxHistory             := 5;
  LogToFile.LogTags.Clear;         }

{-----------------------------------------------------------------------------}
{ Finalization                                                                }
{ Purpose     :  To destroy the instance of the TLogToFile Object             }
{                                                                             }
{-----------------------------------------------------------------------------}
{Finalization
  LogToFile.Free;
 }
end.
