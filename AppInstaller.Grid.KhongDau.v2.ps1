<#  StoreOnly.WinGUI.ONE.ps1
    - 1 file duy nhất: GUI WPF + winget + chờ installer rảnh + catalog mẫu nhúng sẵn
    - Tabs: Apps (DataGrid Pick/Name/Category/Id), thanh Search/Reload/Status, footer: Exact/-silent/-accept/--scope user
    - Có thể nạp file catalog ngoài qua tham số -CatalogPath (nếu muốn), không bắt buộc
#>

param(
    [string]$AppTitle   = "HDP App Store",
    [string]$CatalogPath = ""   # optional: nếu không có dùng catalog nhúng bên dưới
)
$ErrorActionPreference = 'Stop'

# ===== Catalog nhúng sẵn (chỉnh sửa trong file này nếu muốn) =====
$EmbeddedCatalogJson = @'
{
  "Essentials": [
    { "name": "7-Zip",              "id": "7zip.7zip" },
    { "name": "Google Chrome",      "id": "Google.Chrome" },
    { "name": "Notepad++",          "id": "Notepad++.Notepad++" },
    { "name": "Visual Studio Code", "id": "Microsoft.VisualStudioCode" },
    { "name": "PowerToys",          "id": "Microsoft.PowerToys" },
    { "name": "Git",                "id": "Git.Git" },
    { "name": "VLC Media Player",   "id": "VideoLAN.VLC" }
  ],
  "Browsers": [
    "Mozilla Firefox",
    { "name": "Brave", "id": "Brave.Brave" }
  ]
}
'@

# --- WPF prerequisites ---
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
# Đảm bảo STA; không tự elevate — có thể chạy Admin nếu muốn scope=machine
try {
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-STA',
                      '-File',('"{0}"' -f $PSCommandPath),
                      '-AppTitle',('"{0}"' -f $AppTitle))
        if ($CatalogPath) { $argsList += @('-CatalogPath',('"{0}"' -f $CatalogPath)) }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argsList -WindowStyle Normal | Out-Null
        return
    }
} catch { }

# ================ Utils =================
function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        [System.Windows.MessageBox]::Show("Winget not found. Install 'App Installer' from Microsoft Store and try again.",
            "Winget missing",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
        return $false
    }
    return $true
}

function Test-PendingReboot {
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
  )
  foreach ($p in $paths) { if (Test-Path $p) { return $true } }
  try {
    $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($val.PendingFileRenameOperations) { return $true }
  } catch {}
  return $false
}

function Test-InstallerBusy {
  $procs = Get-CimInstance Win32_Process |
           Where-Object { $_.Name -match 'msiexec|setup|unins.*|AppInstaller|StoreBroker|Install.*' }
  $inProg = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress" -ErrorAction SilentlyContinue
  [pscustomobject]@{ Busy=[bool]($procs -or $inProg); Processes=$procs; InProgressKey=$inProg; RebootPending=(Test-PendingReboot) }
}

function Wait-InstallerIdle([int]$TimeoutSec=1200,[int]$PollSec=5) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    $t = Test-InstallerBusy
    if (-not $t.Busy -and -not $t.RebootPending) { return $true }
    if ($t.RebootPending) { $global:LblStatus.Text = "Pending reboot detected — please reboot for best results." }
    if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) { return $false }
    Start-Sleep -Seconds $PollSec
  }
}

function Read-JsonFile { param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
  } catch {
    [System.Windows.MessageBox]::Show(("Local JSON error: {0}" -f $_.Exception.Message),"JSON error",
        [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    return $null
  }
}

function Test-PSObject { param($o) try { return ($null -ne $o -and $o.PSObject -and $o.PSObject.Properties.Count -ge 0) } catch { return $false } }

function Convert-ApplicationsToRows { param($json)
  $rows=@(); if ($null -eq $json) { return $rows }
  function Add-AppRow { param($obj,[string]$category="General")
    $name=$null
    if ($obj -is [string]) { $name=$obj } else {
      if     ($obj.psobject.Properties['name'])  { $name=[string]$obj.name }
      elseif ($obj.psobject.Properties['Name'])  { $name=[string]$obj.Name }
      elseif ($obj.psobject.Properties['title']) { $name=[string]$obj.title }
      elseif ($obj.psobject.Properties['Title']) { $name=[string]$obj.Title }
      elseif ($obj.psobject.Properties['app'])   { $name=[string]$obj.app }
    }
    if (-not $name) { return }
    $wingetId=$null
    if ($obj -isnot [string]) {
      if     ($obj.psobject.Properties['Id'])               { $wingetId=[string]$obj.Id }
      elseif ($obj.psobject.Properties['id'])               { $wingetId=[string]$obj.id }
      elseif ($obj.psobject.Properties['PackageIdentifier']){ $wingetId=[string]$obj.PackageIdentifier }
      elseif ($obj.psobject.Properties['winget'] -and $obj.winget) {
        if     ($obj.winget.psobject.Properties['id'])      { $wingetId=[string]$obj.winget.id }
        elseif ($obj.winget.psobject.Properties['package']) { $wingetId=[string]$obj.winget.package }
      } elseif ($obj.psobject.Properties['package'])        { $wingetId=[string]$obj.package }
    }
    $rows += [PSCustomObject]@{ Select=$false; Name=[string]$name; Category=[string]$category; Id=[string]$wingetId }
  }
  if (Test-PSObject $json) {
    foreach ($prop in $json.PSObject.Properties) {
      $category=$prop.Name; $apps=$prop.Value
      if ($apps -is [System.Collections.IEnumerable]) { foreach ($a in $apps) { Add-AppRow -obj $a -category $category } }
    }
  } elseif ($json -is [System.Collections.IEnumerable]) {
    foreach ($item in $json) {
      if (Test-PSObject $item) {
        $category="General"
        if     ($item.psobject.Properties['category']) { $category=[string]$item.category }
        elseif ($item.psobject.Properties['name'])     { $category=[string]$item.name } # khi root = category
        Add-AppRow -obj $item -category $category
      } elseif ($item -is [string]) { Add-AppRow -obj $item -category 'General' }
    }
  }
  return $rows
}

# ================ XAML (khung GUI) ================
$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HDP App Store" Height="560" Width="900" WindowStartupLocation="CenterScreen">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,8">
      <TextBlock x:Name="LblTitle" Text="HDP App Store" FontSize="20" FontWeight="Bold"/>
      <TextBlock Text="  - Embedded catalog" Foreground="Gray" Margin="6,0,0,0"/>
      <TextBox x:Name="SearchBox" Width="340" Margin="16,0,0,0" VerticalAlignment="Center" ToolTip="Search (name or category)"/>
      <Button x:Name="BtnReload" Content="Reload" Margin="8,0,0,0" />
      <TextBlock x:Name="LblStatus" Margin="16,0,0,0" Foreground="Gray"/>
    </StackPanel>

    <!-- Tabs -->
    <TabControl Grid.Row="1">
      <TabItem Header="Apps">
        <Grid>
          <DataGrid x:Name="GridApps" AutoGenerateColumns="False" CanUserSortColumns="True"
                    HeadersVisibility="All" CanUserAddRows="False" SelectionMode="Extended" IsReadOnly="False">
            <DataGrid.Columns>
              <DataGridCheckBoxColumn Binding="{Binding Select}" Width="50" Header="Pick"/>
              <DataGridTextColumn Binding="{Binding Name}" Header="Name" Width="*"/>
              <DataGridTextColumn Binding="{Binding Category}" Header="Category" Width="200"/>
              <DataGridTextColumn Binding="{Binding Id}" Header="Winget Id" Width="260"/>
            </DataGrid.Columns>
          </DataGrid>
        </Grid>
      </TabItem>
      <TabItem Header="Tweaks"><TextBlock Margin="12" Foreground="Gray">(Trống — sẽ thêm sau)</TextBlock></TabItem>
      <TabItem Header="Features"><TextBlock Margin="12" Foreground="Gray">(Trống — sẽ thêm sau)</TextBlock></TabItem>
      <TabItem Header="Updates"><TextBlock Margin="12" Foreground="Gray">(Trống — sẽ thêm sau)</TextBlock></TabItem>
      <TabItem Header="Automation"><TextBlock Margin="12" Foreground="Gray">(Trống — sẽ thêm sau)</TextBlock></TabItem>
    </TabControl>

    <!-- Footer -->
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
      <CheckBox x:Name="ChkExact" Content="Exact match (-e)" IsChecked="True" VerticalAlignment="Center"/>
      <CheckBox x:Name="ChkSilent" Content="--silent" IsChecked="True" Margin="12,0,0,0" VerticalAlignment="Center"/>
      <CheckBox x:Name="ChkAccept" Content="Accept agreements" IsChecked="True" Margin="12,0,0,0" VerticalAlignment="Center"/>
      <CheckBox x:Name="ChkUserScope" Content="--scope user (no Admin)" IsChecked="False" Margin="12,0,0,0" VerticalAlignment="Center"/>
      <Button x:Name="BtnInstall" Content="Install selected" Margin="12,0,0,0" Padding="16,6"/>
      <Button x:Name="BtnClose" Content="Close" Margin="8,0,0,0" Padding="16,6"/>
    </StackPanel>
  </Grid>
</Window>
"@

[xml]$xml = $Xaml
$reader = (New-Object System.Xml.XmlNodeReader $xml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# find controls
$global:LblTitle   = $window.FindName('LblTitle')
$global:LblStatus  = $window.FindName('LblStatus')
$grid      = $window.FindName('GridApps')
$search    = $window.FindName('SearchBox')
$btnReload = $window.FindName('BtnReload')
$btnClose  = $window.FindName('BtnClose')
$btnInstall= $window.FindName('BtnInstall')
$chkExact  = $window.FindName('ChkExact')
$chkSilent = $window.FindName('ChkSilent')
$chkAccept = $window.FindName('ChkAccept')
$chkUser   = $window.FindName('ChkUserScope')
$global:LblTitle.Text = $AppTitle

# ================ Data & binding ================
$global:AllRows = @()
$global:View    = @()

function Set-Status([string]$t) { $global:LblStatus.Text = $t }

function Refresh-View {
  $q = [string]$search.Text
  if ([string]::IsNullOrWhiteSpace($q)) {
    $global:View = $global:AllRows
  } else {
    $q = $q.Trim(); $qLower=$q.ToLowerInvariant()
    $global:View = @($global:AllRows | Where-Object { $_.Name.ToLowerInvariant().Contains($qLower) -or $_.Category.ToLowerInvariant().Contains($qLower) })
  }
  $grid.ItemsSource = $null; $grid.ItemsSource = $global:View
}

function Load-From-Embedded {
  try {
    $json = $EmbeddedCatalogJson | ConvertFrom-Json
    $rows = Convert-ApplicationsToRows -json $json
    if ($rows) { $global:AllRows = $rows }
    Set-Status ("Source: Embedded | Items: {0}" -f $global:AllRows.Count)
  } catch {
    [System.Windows.MessageBox]::Show(("Embedded JSON error: {0}" -f $_.Exception.Message),"JSON error",
        [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    $global:AllRows = @()
    Set-Status "Embedded catalog error"
  }
  Refresh-View
}

function Load-Catalog {
  if ($CatalogPath -and (Test-Path -LiteralPath $CatalogPath)) {
    $json = Read-JsonFile -Path $CatalogPath
    $rows = Convert-ApplicationsToRows -json $json
    if ($rows -and $rows.Count -gt 0) {
      $global:AllRows = $rows
      Set-Status ("Source: File ({0}) | Items: {1}" -f $CatalogPath, $global:AllRows.Count)
      Refresh-View
      return
    }
  }
  # fallback về catalog nhúng
  Load-From-Embedded
}

# ================ Events =================
$btnReload.Add_Click({ Load-Catalog })
$search.Add_TextChanged({ Refresh-View })
$btnClose.Add_Click({ $window.Close() })

$btnInstall.Add_Click({
  if (-not (Ensure-Winget)) { return }
  $selected = @($global:View | Where-Object { $_.Select })
  if ($selected.Count -eq 0) {
    [System.Windows.MessageBox]::Show("Nothing selected.","Info",
        [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
    return
  }
  # Chờ nếu Installer đang bận
  if (-not (Wait-InstallerIdle -TimeoutSec 900 -PollSec 5)) {
    [System.Windows.MessageBox]::Show("Timeout waiting for other installer. Please reboot and try again.","Busy",
        [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
    return
  }

  $exact  = $chkExact.IsChecked  -eq $true
  $silent = $chkSilent.IsChecked -eq $true
  $accept = $chkAccept.IsChecked -eq $true
  $scopeUser = $chkUser.IsChecked -eq $true

  $err=0; $ok=0; $i=0; $n=$selected.Count
  $grid.IsEnabled=$false; $btnInstall.IsEnabled=$false; $btnReload.IsEnabled=$false
  foreach ($row in $selected) {
    $i++
    Set-Status ("Installing {0}/{1}: {2}" -f $i,$n,$row.Name)
    $cmd = @('winget','install')
    if ($row.Id) { $cmd += '--id'; $cmd += $row.Id } else { $cmd += $row.Name }
    if ($exact)  { $cmd += '-e' }
    if ($silent) { $cmd += '--silent' }
    if ($accept) { $cmd += '--accept-package-agreements'; $cmd += '--accept-source-agreements' }
    $cmd += '--disable-interactivity'
    if ($scopeUser) { $cmd += '--scope'; $cmd += 'user' }

    $p = Start-Process -FilePath $cmd[0] -ArgumentList ($cmd[1..($cmd.Length-1)]) -NoNewWindow -PassThru -Wait
    if ($p.ExitCode -eq 0) { $ok++ }
    else {
      # Fallback theo Name nếu --id thất bại
      if ($row.Id) {
        $cmd2 = @('winget','install',$row.Name)
        if ($exact)  { $cmd2 += '-e' }
        if ($silent) { $cmd2 += '--silent' }
        if ($accept) { $cmd2 += '--accept-package-agreements'; $cmd2 += '--accept-source-agreements' }
        $cmd2 += '--disable-interactivity'
        if ($scopeUser) { $cmd2 += '--scope'; $cmd2 += 'user' }
        $p2 = Start-Process -FilePath $cmd2[0] -ArgumentList ($cmd2[1..($cmd2.Length-1)]) -NoNewWindow -PassThru -Wait
        if ($p2.ExitCode -eq 0) { $ok++ } else { $err++ }
      } else { $err++ }
    }
  }
  $grid.IsEnabled=$true; $btnInstall.IsEnabled=$true; $btnReload.IsEnabled=$true

  if ($err -eq 0) {
    [System.Windows.MessageBox]::Show("All done.","Success",
        [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
  } else {
    [System.Windows.MessageBox]::Show(("Completed with {0} failure(s)." -f $err),"Partial",
        [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
  }
  Set-Status ("Installed OK: {0} | Failed: {1}" -f $ok,$err)
})

# ================ Run ================
$window.Title = $AppTitle
Load-Catalog
$null = $window.ShowDialog()
