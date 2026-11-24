# 本地游戏服务器托盘程序：后台启动 server/run.py（不显示黑窗口），右下角托盘图标里可以看日志、重启、关闭。
# 由 启动服务器.bat 经 server_tray.vbs 隐藏启动（直接起 powershell 会被 Windows Terminal 接管成一个窗口）；直接运行：powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File tools\server_tray.ps1 [run.py 的参数]
# 本文件必须存成 UTF-8 带 BOM，否则 Windows PowerShell 5.1 会把中文读乱。
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$RunArgs)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root 'server'
$outLog = Join-Path $serverDir 'server.log'
$errLog = Join-Path $serverDir 'server.err.log'
$port = 8765
for ($i = 0; $i -lt $RunArgs.Count - 1; $i++) {
	if ($RunArgs[$i] -eq '--port') { $port = [int]$RunArgs[$i + 1] }
}
$base = "http://127.0.0.1:$port"

# 只开一个托盘
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'TribeMergeServerTray', [ref]$created)
if (-not $created) {
	[System.Windows.Forms.MessageBox]::Show('服务器已经在运行了，看右下角托盘里的图标。', '合合部落服务器') | Out-Null
	exit
}

# 把服务器进程放进一个「托盘退出就全部结束」的作业对象：托盘被任务管理器结束、注销时也不会留下后台 python
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TrayJob {
	[StructLayout(LayoutKind.Sequential)] struct BASIC { public long a, b; public uint LimitFlags; public UIntPtr c, d; public uint e; public UIntPtr f; public uint g, h; }
	[StructLayout(LayoutKind.Sequential)] struct IO { public ulong a, b, c, d, e, f; }
	[StructLayout(LayoutKind.Sequential)] struct EXT { public BASIC Basic; public IO Io; public UIntPtr p, q, r, s; }
	[DllImport("kernel32.dll")] static extern IntPtr CreateJobObject(IntPtr a, string n);
	[DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr j, int c, ref EXT i, uint l);
	[DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);
	static IntPtr job = IntPtr.Zero;
	public static bool Add(IntPtr process) {
		if (job == IntPtr.Zero) {
			job = CreateJobObject(IntPtr.Zero, null);
			EXT info = new EXT();
			info.Basic.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
			SetInformationJobObject(job, 9, ref info, (uint)Marshal.SizeOf(typeof(EXT)));
		}
		return AssignProcessToJobObject(job, process);
	}
}
'@

$py = 'python'
$pyPre = @()
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { $py = 'py'; $pyPre = @('-3') }

function New-TrayIcon([System.Drawing.Color]$color) {
	$bmp = New-Object System.Drawing.Bitmap 32, 32
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = 'AntiAlias'
	$g.Clear([System.Drawing.Color]::Transparent)
	$g.FillEllipse((New-Object System.Drawing.SolidBrush $color), 1, 1, 30, 30)
	$g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 50, 20)), 2), 2, 2, 28, 28)
	$font = New-Object System.Drawing.Font 'Microsoft YaHei', 13, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
	$fmt = New-Object System.Drawing.StringFormat
	$fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
	$g.DrawString('合', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 1, 32, 32), $fmt)
	$g.Dispose()
	return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$iconOn = New-TrayIcon ([System.Drawing.Color]::FromArgb(232, 150, 42))
$iconOff = New-TrayIcon ([System.Drawing.Color]::FromArgb(140, 140, 140))

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $iconOff
$tray.Text = '合合部落服务器'
$tray.Visible = $true

$script:proc = $null
$script:stopping = $false

function Set-State([bool]$on, [string]$text) {
	$tray.Icon = $(if ($on) { $iconOn } else { $iconOff })
	$t = "合合部落服务器：$text"
	if ($t.Length -gt 63) { $t = $t.Substring(0, 63) }
	$tray.Text = $t
	$itemStatus.Text = $text
}

function Start-Server {
	$script:stopping = $false
	$args2 = @($pyPre) + @('run.py') + @($RunArgs | Where-Object { $_ })
	$script:proc = Start-Process -FilePath $py -ArgumentList $args2 -WorkingDirectory $serverDir -WindowStyle Hidden `
		-RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
	[TrayJob]::Add($script:proc.Handle) | Out-Null
	Set-State $true "运行中  $base"
}

function Stop-Server {
	$script:stopping = $true
	if ($script:proc -and -not $script:proc.HasExited) {
		# py 启动器会再起一个 python 子进程，连进程树一起关
		& taskkill.exe /PID $script:proc.Id /T /F 2>$null | Out-Null
		$script:proc.WaitForExit(5000) | Out-Null
	}
	$script:proc = $null
	Set-State $false '已停止'
}

function Show-Log {
	$path = $(if ((Test-Path $errLog) -and (Get-Item $errLog).Length -gt 0) { $errLog } else { $outLog })
	if (Test-Path $path) { Start-Process notepad.exe $path }
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$itemStatus = $menu.Items.Add('启动中…')
$itemStatus.Enabled = $false
$menu.Items.Add('-') | Out-Null
$menu.Items.Add('打开接口文档', $null, { Start-Process "$base/docs" }) | Out-Null
$menu.Items.Add('查看日志', $null, { Show-Log }) | Out-Null
$menu.Items.Add('重启服务器', $null, { Stop-Server; Start-Server }) | Out-Null
$menu.Items.Add('-') | Out-Null
$menu.Items.Add('关闭服务器并退出', $null, {
	Stop-Server
	$tray.Visible = $false
	[System.Windows.Forms.Application]::Exit()
}) | Out-Null
$tray.ContextMenuStrip = $menu
$tray.add_DoubleClick({ Start-Process "$base/docs" })

# 服务器自己退出（端口被占、报错）时提示
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1500
$timer.add_Tick({
	if ($script:proc -and $script:proc.HasExited -and -not $script:stopping) {
		$script:proc = $null
		Set-State $false '意外停止（右键看日志）'
		$tray.ShowBalloonTip(5000, '合合部落服务器', '服务器意外停止了，右键托盘图标 → 查看日志。', 'Error')
	}
})
$timer.Start()

Start-Server
$tray.ShowBalloonTip(3000, '合合部落服务器', "已在后台启动：$base`n右键托盘图标可以关闭。", 'Info')

try {
	[System.Windows.Forms.Application]::Run()
} finally {
	$timer.Stop()
	if ($script:proc -and -not $script:proc.HasExited) { Stop-Server }
	$tray.Dispose()
	$mutex.ReleaseMutex()
}
