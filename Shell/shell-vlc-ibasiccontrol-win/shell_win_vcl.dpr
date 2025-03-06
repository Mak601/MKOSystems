program shell_win_vcl;

uses
  Vcl.Forms,
  MainFrm in 'MainFrm.pas' {MainForm},
  IShellInterface in '..\..\Headers\IShellInterface.pas',
  ICoreInterface in '..\..\Headers\ICoreInterface.pas',
  IModuleInterface in '..\..\Headers\IModuleInterface.pas',
  ILogInterface in '..\..\Headers\ILogInterface.pas',
  ShellLogThreadManager in 'ShellLogThreadManager.pas';

{ Form1 }

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
