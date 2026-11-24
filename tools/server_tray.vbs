' Starts tools\server_tray.ps1 with no console window at all (SW_HIDE from the start, so Windows Terminal never opens a tab).
' Arguments are passed on to server\run.py. Called by the server launcher .bat files.
Dim sh, fso, ps1, cmd, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ps1 = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "server_tray.ps1")
cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """"
For i = 0 To WScript.Arguments.Count - 1
  cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
sh.Run cmd, 0, False
