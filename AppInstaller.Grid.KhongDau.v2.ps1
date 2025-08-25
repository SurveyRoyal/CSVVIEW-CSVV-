# AppInstaller.Grid.KhongDau.v2.ps1
# Light UI (WPF) – PS 5.1 compatible
# Tabs: Install / CSVV / FONT
# Tính năng: gom nhiều winget vào 1 console; EXE/ZIP chạy nền; log rõ ràng

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { Add-Type -AssemblyName System.Web } catch {}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

# ========== XAML (Light) ==========
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="App Installer - Khong Dau" Width="1100" Height="720"
        Background="#FFFFFF" Foreground="#1C1C1C"
        FontFamily="Segoe UI" FontSize="13"
        WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent"       Color="#2563EB"/>
    <SolidColorBrush x:Key="TileBg"       Color="#F2F4F7"/>
    <SolidColorBrush x:Key="TileBgHover"  Color="#E6EAF0"/>
    <SolidColorBrush x:Key="TileBorder"   Color="#D0D5DD"/>
    <SolidColorBrush x:Key="TextFg"       Color="#1C1C1C"/>

    <Style x:Key="TileCheckBox" TargetType="CheckBox">
      <Setter Property="Margin" Value="6"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Foreground" Value="{StaticResource TextFg}"/>
      <Setter Property="Background" Value="{StaticResource TileBg}"/>
      <Setter Property="BorderBrush" Value="{StaticResource TileBorder}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="8">
              <Grid Margin="2">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="{StaticResource TileBgHover}"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter Property="Background"  Value="{StaticResource Accent}"/>
                <Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.6"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <DockPanel Margin="10">
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
      <Button Name="BtnInstallSelected" Content="Install Selected" Width="140" Height="32" Margin="0,0,8,0"/>
      <Button Name="BtnClear" Content="Clear Selection" Width="140" Height="32" Margin="0,0,8,0"/>
      <Button Name="BtnGetInstalled" Content="Get Installed" Width="120" Height="32" Margin="0,0,8,0"/>
      <CheckBox Name="ChkSilent"  IsChecked="True"  Content="Silent"        VerticalAlignment="Center" Margin="0,0,8,0"/>
      <CheckBox Name="ChkAccept"  IsChecked="True"  Content="Accept EULA"   VerticalAlignment="Center" Margin="0,0,8,0"/>
      <CheckBox Name="ChkConsole" IsChecked="True"  Content="Chay ngoai Console" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <CheckBox Name="ChkOneConsole" IsChecked="True" Content="1 Console"   VerticalAlignment="Center" Margin="0,0,8,0"/>
    </StackPanel>

    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="220"/>
      </Grid.RowDefinitions>

      <TabControl Grid.Row="0">
        <TabItem Header="Install">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Name="PanelGroups" Margin="6"/>
          </ScrollViewer>
        </TabItem>
        <TabItem Header="CSVV"><Grid><TextBlock Margin="10" Text="Tab CSVV (de trong de sua sau)"/></Grid></TabItem>
        <TabItem Header="FONT"><Grid><TextBlock Margin="10" Text="Tab FONT (de trong de sua sau)"/></Grid></TabItem>
      </TabControl>

      <Grid Grid.Row="1">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Log" FontWeight="Bold" Margin="0,0,0,4"/>
        <TextBox Grid.Row="1" Name="TxtLog" Background="#FFFFFF" Foreground="#1C1C1C"
                 IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      </Grid>
    </Grid>
  </DockPanel>
</Window>
"@

$ErrorActionPreference = 'Stop'
$window = [Windows.Markup.XamlReader]::Parse($xaml)

# Controls
$PanelGroups        = $window.FindName("PanelGroups")
$BtnInstallSelected = $window.FindName("BtnInstallSelected")
$BtnClear           = $window.FindName("BtnClear")
$BtnGetInstalled    = $window.FindName("BtnGetInstalled")
$TxtLog             = $window.FindName("TxtLog")
$ChkSilent          = $window.FindName("ChkSilent")
$ChkAccept          = $window.FindName("ChkAccept")
$ChkConsole         = $window.FindName("ChkConsole")
$ChkOneConsole      = $window.FindName("ChkOneConsole")

# ===== Helpers =====
function Log-Msg([string]$msg){
  $TxtLog.AppendText(("{0}  {1}`r`n" -f (Get-Date).ToString("HH:mm:ss"), $msg))
  $TxtLog.ScrollToEnd()
}
function Resolve-Id([string[]]$candidates){
  foreach($id in $candidates){
    $p = Start-Process -FilePath "winget" -ArgumentList @("show","-e","--id",$id) -PassThru -WindowStyle Hidden
    $p.WaitForExit()
    if($p.ExitCode -eq 0){ return $id }
  }
  return $null
}

# Build PS array literal text from args (an toàn cho PS5.1)
function To-PSArrayLiteral([string[]]$arr){
  $safe = @()
  foreach($s in $arr){ $safe += ($s -replace '"','``"') }
  '@("' + ($safe -join '","') + '")'
}

# Chờ MSI rảnh để tránh "Waiting for another install..."
function Wait-InstallerIdle([int]$timeoutSec=600){
  $sw=[Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt $timeoutSec){
    $busy = Get-Process -Name msiexec -ErrorAction SilentlyContinue
    if(-not $busy){ return }
    Start-Sleep -Seconds 3
  }
}

# Giữ 1 cửa sổ console ngoài (tùy chọn)
$global:ExtConsoleProc = $null
function Start-ExternalConsoleFromLines([string]$title,[string[]]$lines){
  try{
    $tmp = Join-Path $env:TEMP ("run_" + [Guid]::NewGuid().ToString("N") + ".ps1")

    $preamble = @(
      'try{ chcp 65001 | Out-Null }catch{}',
      'try{ [Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::InputEncoding=[Text.Encoding]::UTF8 }catch{}',
      '$ErrorActionPreference = ''Continue''',
      'function WaitIdle([int]$sec=600){ $sw=[Diagnostics.Stopwatch]::StartNew(); while($sw.Elapsed.TotalSeconds -lt $sec){ if(-not (Get-Process msiexec -ErrorAction SilentlyContinue)){ return }; Start-Sleep -s 3 } }'
    )

    $scriptText = (($preamble + $lines) -join [Environment]::NewLine)
    Set-Content -Path $tmp -Value $scriptText -Encoding UTF8

    if ($global:ExtConsoleProc -and -not $global:ExtConsoleProc.HasExited) {
      try { $global:ExtConsoleProc.CloseMainWindow() | Out-Null; Start-Sleep -Milliseconds 300 } catch {}
      try { if(-not $global:ExtConsoleProc.HasExited){ $global:ExtConsoleProc.Kill() } } catch {}
    }

    $exe  = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-NoExit","-File",$tmp)
    $global:ExtConsoleProc = Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Normal -PassThru
    Log-Msg ("[LAUNCH] {0}" -f $title)
  } catch {
    Log-Msg ("[ERR] Start-ExternalConsoleFromLines: {0}" -f $_.Exception.Message)
  }
}

function Launch-OneConsoleWingetBatch([object[]]$wingetArgsList){
  $hdr = @(
    'try{ chcp 65001 | Out-Null }catch{}',
    'try{ [Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::InputEncoding=[Text.Encoding]::UTF8 }catch{}',
    '$ErrorActionPreference = ''Continue''',
    'function WaitIdle([int]$sec=600){ $sw=[Diagnostics.Stopwatch]::StartNew(); while($sw.Elapsed.TotalSeconds -lt $sec){ if(-not (Get-Process msiexec -ErrorAction SilentlyContinue)){ return }; Start-Sleep -s 3 } }',
    'function RunWinget($arr){',
    '  WaitIdle 600',
    '  Write-Host ("`n=== winget " + ([string]::Join(" ", $arr))) -ForegroundColor Cyan',
    '  $p = Start-Process -FilePath "winget" -ArgumentList $arr -PassThru',
    '  $p.WaitForExit()',
    '  Write-Host ("ExitCode: " + $p.ExitCode)',
    '}'
  )
  $lines = @()
  $lines += $hdr
  foreach($a in $wingetArgsList){
    $lit = To-PSArrayLiteral $a
    $lines += '$a = ' + $lit
    $lines += 'RunWinget $a'
  }
  Start-ExternalConsoleFromLines "Batch install" $lines
}

# Winget
function Install-ById([string]$id, [string[]]$ExtraArgs=$null){
  if(-not $id){ return $false }
  $args = @("install","-e","--id",$id)
  if($ChkSilent.IsChecked){ $args += "--silent" }
  if($ChkAccept.IsChecked){ $args += @("--accept-package-agreements","--accept-source-agreements") }
  if($ExtraArgs){ $args += $ExtraArgs }

  if($ChkConsole.IsChecked -and -not $ChkOneConsole.IsChecked){
    $lit = To-PSArrayLiteral $args
    $lines = @(
      '$a = ' + $lit,
      'WaitIdle 600',
      'Write-Host ("winget " + ([string]::Join(" ", $a))) -ForegroundColor Cyan',
      '$p = Start-Process -FilePath "winget" -ArgumentList $a -PassThru',
      '$p.WaitForExit()',
      'Write-Host ("ExitCode: " + $p.ExitCode)',
      'Write-Host ""',
      'Write-Host "Done. Nhan Enter de dong cua so..."',
      '[Console]::ReadLine() | Out-Null'
    )
    Start-ExternalConsoleFromLines "winget $id" $lines
    return $true
  }

  Wait-InstallerIdle 600
  Log-Msg ("Install: {0}" -f $id)
  $p = Start-Process -FilePath "winget" -ArgumentList $args -PassThru -WindowStyle Hidden
  $p.WaitForExit()
  $code = $p.ExitCode
  if(($code -eq 0) -or ($code -eq -1978335189)){
    if($code -eq -1978335189){ Log-Msg ("[OK] already installed / not applicable: {0}" -f $id) }
    else { Log-Msg ("[OK] installed: {0}" -f $id) }
    return $true
  } else { Log-Msg ("[WARN] install failed (ExitCode={0})" -f $code); return $false }
}

# EXE/MSI (chạy nền để UI mượt)
function Install-Exe([hashtable]$exe){
  try{
    $url = [string]$exe.Url
    $args = if([string]::IsNullOrWhiteSpace($exe.Args)) { "" } else { [string]$exe.Args }
    $sha  = [string]$exe.Sha256
    if([string]::IsNullOrWhiteSpace($url)){ Log-Msg "[ERR] Exe.Url rong"; return $false }

    $file = Join-Path $env:TEMP ([IO.Path]::GetFileName(($url -split '\?')[0]))
    Log-Msg ("Download: {0}" -f $url); iwr -useb $url -OutFile $file
    if($sha){
      $hash = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLower()
      if($hash -ne $sha.ToLower()){ Log-Msg "[ERR] SHA256 mismatch"; return $false }
    }
    if($file.ToLower().EndsWith(".msi")){
      $msiArgs = "/i `"$file`" /qn /norestart"; Log-Msg ("MSI: msiexec {0}" -f $msiArgs)
      Wait-InstallerIdle 600
      $p = Start-Process msiexec -ArgumentList $msiArgs -PassThru -WindowStyle Hidden
    } else {
      if([string]::IsNullOrWhiteSpace($args)){
        Log-Msg ("EXE: {0}" -f $file)
        $p = Start-Process -FilePath $file -PassThru -WindowStyle Hidden
      } else {
        Log-Msg ("EXE: {0} {1}" -f $file,$args)
        $p = Start-Process -FilePath $file -ArgumentList $args -PassThru -WindowStyle Hidden
      }
    }
    $p.WaitForExit()
    if($p.ExitCode -eq 0){ Log-Msg "[OK] installed"; return $true } else { Log-Msg ("[WARN] exit {0}" -f $p.ExitCode); return $false }
  } catch { Log-Msg ("[ERR] Install-Exe: {0}" -f $_.Exception.Message); return $false }
}

# ZIP (giải + shortcut/startup)
function Install-ZipPackage([hashtable]$zip){
  try{ Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null } catch {}
  $url=[string]$zip.Url; $dest=[Environment]::ExpandEnvironmentVariables([string]$zip.DestDir)
  $exe=[string]$zip.Exe; $runArgs=[string]$zip.RunArgs; $mkDesk=[bool]$zip.CreateShortcut; $startup=[bool]$zip.AddStartup
  if([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($dest)){ Log-Msg "[ERR] Zip.Url/DestDir rong"; return $false }

  $zipPath = Join-Path $env:TEMP ([IO.Path]::GetFileName(($url -split '\?')[0]))
  Log-Msg ("Download: {0}" -f $url); iwr -useb $url -OutFile $zipPath
  if(-not (Test-Path $dest)){ New-Item -ItemType Directory -Path $dest -Force | Out-Null }
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $dest, $true)

  if($mkDesk -and -not [string]::IsNullOrWhiteSpace($exe)){
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "UniKey.lnk"
    $target = Join-Path $dest $exe
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $sc.TargetPath = $target
    if(-not [string]::IsNullOrWhiteSpace($runArgs)){ $sc.Arguments = $runArgs }
    $sc.WorkingDirectory = $dest
    $sc.Save()
  }
  if($startup -and -not [string]::IsNullOrWhiteSpace($exe)){
    $target = Join-Path $dest $exe
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "UniKey" -Value "`"$target`"" -PropertyType String -Force | Out-Null
  }
  Log-Msg "[OK] zip extracted"; return $true
}

# GitHub latest (EVKey…)
function Install-GitHubLatest([hashtable]$gh){
  try{
    $repo=[string]$gh.Repo; if([string]::IsNullOrWhiteSpace($repo)){ Log-Msg "[ERR] GitHub.Repo rong"; return $false }
    $api="https://api.github.com/repos/$repo/releases/latest"; Log-Msg ("GitHub API: {0}" -f $api)
    $rel = Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent'='PowerShell' } -Uri $api -ErrorAction Stop
    $assets=@($rel.assets)
    $cand = $assets | Where-Object { $_.name -match '(?i)\.(msi|exe)$' } | Select-Object -First 1
    if($cand){ return Install-Exe @{ Url=$cand.browser_download_url; Args="/S"; Sha256="" } }
    $zip = $assets | Where-Object { $_.name -match '(?i)\.zip$' } | Select-Object -First 1
    if($zip){ return Install-ZipPackage @{ Url=$zip.browser_download_url; DestDir="$Env:ProgramFiles\EVKey"; Exe="EVKey.exe"; RunArgs=""; CreateShortcut=$true; AddStartup=$true } }
    Log-Msg "[ERR] Khong tim thay asset phu hop"; return $false
  } catch { Log-Msg ("[ERR] Install-GitHubLatest: {0}" -f $_.Exception.Message); return $false }
}

# AutoHotkey helpers
function Find-AutoHotkeyExe(){
  $cmd = Get-Command AutoHotkey -ErrorAction SilentlyContinue
  if($cmd){ return $cmd.Source }
  foreach($p in @("C:\Program Files\AutoHotkey\AutoHotkey.exe","C:\Program Files (x86)\AutoHotkey\AutoHotkey.exe")){
    if(Test-Path $p){ return $p }
  }
  return $null
}
function Ensure-AutoHotkey(){
  $exe = Find-AutoHotkeyExe; if($exe){ return $true }
  $id = Resolve-Id @("AutoHotkey.AutoHotkey","AutoHotkey.AutoHotkey.Portable")
  if($id){ if(-not (Install-ById -id $id)){ return $false } } else { Log-Msg "[ERR] Khong tim thay goi AutoHotkey tren winget."; return $false }
  Start-Sleep -Seconds 2; return [bool](Find-AutoHotkeyExe)
}

# ===== Data: Apps =====
$AppCatalog = @{
  "7zip"          = @{ Name="7zip";            Ids=@("7zip.7zip") }
  "Chrome"        = @{ Name="Chrome";          Ids=@("Google.Chrome") }
  "Notepad++"     = @{ Name="Notepad++";       Ids=@("Notepad++.Notepad++") }
  "VS Code"       = @{ Name="VS Code";         Ids=@("Microsoft.VisualStudioCode") }
  "PowerToys"     = @{ Name="PowerToys";       Ids=@("Microsoft.PowerToys") }
  "PC Manager"    = @{ Name="PC Manager";      Ids=@("Microsoft.PCManager") }
  "Rainmeter"     = @{ Name="Rainmeter";       Ids=@("Rainmeter.Rainmeter") }

  # HHMap 2019 (EXE)
  "HHMap2019"     = @{ Name="HHMap 2019";      Exe=@{ Url="https://hhmaps.vn/uploads/download/files/hhmaps2019_setup.exe"; Args=""; Sha256="" } }

  "Zalo"          = @{
    Name="Zalo";
    Exe = @{ Url="https://res-download-pc-te-vnno-cm-1.zadn.vn/win/ZaloSetup-25.8.2.exe"; Args="/S"; Sha256="" }
    Ids = @("VNG.ZaloPC","Zalo.Zalo","VNG.Zalo","VNGCorp.Zalo")
  }
  "EVKey"         = @{ Name="EVKey"; GitHub=@{ Repo="lamquangminh/EVKey" }; Ids=@("tranxuanthang.EVKey","EVKey.EVKey","EVKey") }
  "UniKey"        = @{ Name="UniKey"; Zip=@{ Url="https://www.unikey.org/assets/release/unikey46RC2-230919-win64.zip"; DestDir="$Env:ProgramFiles\UniKey"; Exe="UniKeyNT.exe"; RunArgs=""; CreateShortcut=$true; AddStartup=$true } }

  "AutoHotkey"    = @{ Name="AutoHotkey";      Ids=@("AutoHotkey.AutoHotkey","AutoHotkey.AutoHotkey.Portable") }
  "AHK Sample"    = @{ Name="AHK Sample (Startup)"; ScriptAction="AHK_SAMPLE" }
}
$Groups = @(
  @{ Title="Essentials";       Keys=@("7zip","Chrome","Notepad++","VS Code","PowerToys","PC Manager","Rainmeter","HHMap2019") },
  @{ Title="VN Chat & Input";  Keys=@("Zalo","EVKey","UniKey","AutoHotkey","AHK Sample") }
)

# ===== UI: Install tab =====
$CheckBoxes = @{}
foreach($g in $Groups){
  $gb = New-Object System.Windows.Controls.GroupBox; $gb.Header = $g.Title; $gb.Margin = "0,0,0,10"
  $panel = New-Object System.Windows.Controls.WrapPanel
  foreach($k in $g.Keys){
    $info = $AppCatalog[$k]; if(-not $info){ continue }
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Style = $window.Resources["TileCheckBox"]; $cb.Content = $info.Name; $cb.Tag = $k; $cb.Width = 180; $cb.Height = 38
    $panel.Children.Add($cb) | Out-Null; $CheckBoxes[$k] = $cb
    $cb.AddHandler([System.Windows.Controls.Control]::MouseDoubleClickEvent,
      [System.Windows.Input.MouseButtonEventHandler]{ param($s,$e)
        $key = $s.Tag; $s.IsEnabled = $false
        try {
          $info2 = $AppCatalog[$key]
          if($info2.ScriptAction -eq "AHK_SAMPLE"){
            if(-not (Ensure-AutoHotkey)){ return }
            $startup = Join-Path ([Environment]::GetFolderPath('Startup')) "MyHotkeys.ahk"
            $content = @"
; MyHotkeys.ahk - mau co ban (AutoHotkey v2)
#SingleInstance Force
^!e::Run "C:\Program Files\EVKey\EVKey.exe"
#F2::SetCapsLockState !GetKeyState("CapsLock","T")
CapsLock::Esc
TrayTip "MyHotkeys", "AutoHotkey dang chay tu Startup", 5
"@
            Set-Content -Path $startup -Value $content -Encoding UTF8
            Log-Msg ("[OK] Da tao: {0}" -f $startup)
            $exe = Find-AutoHotkeyExe; if($exe){ Start-Process -FilePath $exe -ArgumentList "`"$startup`"" | Out-Null; Log-Msg "[OK] Da chay AHK script ngay." }
            return
          }
          if($info2.Exe){ [void](Install-Exe -exe $info2.Exe); return }
          if($info2.Zip){ [void](Install-ZipPackage -zip $info2.Zip); return }
          if($info2.GitHub){ [void](Install-GitHubLatest -gh $info2.GitHub); return }
          if($info2.Ids){ $id = Resolve-Id -candidates $info2.Ids; if($id){ [void](Install-ById -id $id) } else { Log-Msg ("[ERR] not found on winget: {0}" -f ($info2.Ids -join " | ")) } }
        } finally { $s.IsEnabled = $true }
      })
  }
  $gb.Content = $panel; $PanelGroups.Children.Add($gb) | Out-Null
}

# ===== Buttons =====
$BtnClear.Add_Click({ foreach($cb in $CheckBoxes.Values){ $cb.IsChecked = $false }; Log-Msg "Selection cleared." })

$BtnGetInstalled.Add_Click({
  Log-Msg "winget list ..."
  $tmp = [System.IO.Path]::GetTempFileName()
  $p = Start-Process -FilePath "winget" -ArgumentList @("list") -PassThru -WindowStyle Hidden -RedirectStandardOutput $tmp
  $p.WaitForExit()
  try { Log-Msg (Get-Content -Raw $tmp) } catch { Log-Msg "[WARN] cannot read output." }
  Remove-Item -ErrorAction SilentlyContinue $tmp
})

$BtnInstallSelected.Add_Click({
  $selected = @(); foreach($kv in $CheckBoxes.GetEnumerator()){ if($kv.Value.IsChecked){ $selected += $kv.Key } }
  if($selected.Count -eq 0){ Log-Msg "Chua chon ung dung nao."; return }
  Log-Msg ("Installing {0} item(s)..." -f $selected.Count)

  $wingetBatch = @()   # mảng các mảng đối số
  foreach($k in $selected){
    $cb = $CheckBoxes[$k]; $cb.IsEnabled = $false
    try {
      $info = $AppCatalog[$k]
      if($null -eq $info){ continue }

      if($info.ScriptAction -eq "AHK_SAMPLE"){
        if(-not (Ensure-AutoHotkey)){ continue }
        $startup = Join-Path ([Environment]::GetFolderPath('Startup')) "MyHotkeys.ahk"
        $content = @"
; MyHotkeys.ahk - mau co ban (AutoHotkey v2)
#SingleInstance Force
^!e::Run "C:\Program Files\EVKey\EVKey.exe"
#F2::SetCapsLockState !GetKeyState("CapsLock","T")
CapsLock::Esc
TrayTip "MyHotkeys", "AutoHotkey dang chay tu Startup", 5
"@
        Set-Content -Path $startup -Value $content -Encoding UTF8
        Log-Msg ("[OK] Da tao: {0}" -f $startup)
        $exe = Find-AutoHotkeyExe; if($exe){ Start-Process -FilePath $exe -ArgumentList "`"$startup`"" | Out-Null; Log-Msg "[OK] Da chay AHK script ngay." }
        continue
      }

      if($info.Exe){ [void](Install-Exe -exe $info.Exe); continue }
      if($info.Zip){ [void](Install-ZipPackage -zip $info.Zip); continue }
      if($info.GitHub){ [void](Install-GitHubLatest -gh $info.GitHub); continue }

      if($info.Ids){
        $id = Resolve-Id -candidates $info.Ids
        if($id){
          if($ChkConsole.IsChecked -and $ChkOneConsole.IsChecked){
            $arr = @("install","-e","--id",$id)
            if($ChkSilent.IsChecked){ $arr += "--silent" }
            if($ChkAccept.IsChecked){ $arr += @("--accept-package-agreements","--accept-source-agreements") }
            $wingetBatch += ,$arr
          } else {
            [void](Install-ById -id $id)
          }
        } else {
          Log-Msg ("[ERR] not found on winget: {0}" -f ($info.Ids -join " | "))
        }
      }
    } finally { $cb.IsEnabled = $true }
  }

  if($wingetBatch.Count -gt 0 -and $ChkConsole.IsChecked -and $ChkOneConsole.IsChecked){
    Launch-OneConsoleWingetBatch $wingetBatch
    Log-Msg ("[Batch] Da phat lenh cai {0} goi winget trong 1 console." -f $wingetBatch.Count)
  }

  Log-Msg "Done."
})

# Show UI
$window.ShowDialog() | Out-Null
