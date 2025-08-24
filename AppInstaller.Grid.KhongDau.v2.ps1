# AppInstaller.Grid.KhongDau.ps1
# UI: PowerShell + WPF (XAML)
# Tabs: Install / CSVV / FONT (CSVV & FONT as placeholders to edit later)
# Labels: ASCII (khong dau)
# Tested on PowerShell 5.1+ (no ternary operator)

Add-Type -AssemblyName PresentationFramework

# ---- XAML ----
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="App Installer - Khong Dau" Width="1100" Height="700" Background="#1e1e1e" Foreground="White" WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <Style x:Key="TileCheckBox" TargetType="CheckBox">
      <Setter Property="Margin" Value="6"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Background" Value="#2a2a2a"/>
      <Setter Property="BorderBrush" Value="#3f3f3f"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
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
                <Setter Property="Background" Value="#3a3a3a"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter Property="Background" Value="#0f6cbd"/>
                <Setter Property="BorderBrush" Value="#0f6cbd"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.6"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GroupHeader" TargetType="TextBlock">
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Margin" Value="0,6,0,8"/>
    </Style>
  </Window.Resources>

  <DockPanel Margin="10">
    <!-- Top bar -->
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
      <Button Name="BtnInstallSelected" Content="Install Selected" Width="140" Height="32" Margin="0,0,8,0"/>
      <Button Name="BtnClear" Content="Clear Selection" Width="140" Height="32" Margin="0,0,8,0"/>
      <Button Name="BtnGetInstalled" Content="Get Installed" Width="120" Height="32" Margin="0,0,8,0"/>
      <CheckBox Name="ChkSilent" IsChecked="True" Content="Silent" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <CheckBox Name="ChkAccept" IsChecked="True" Content="Accept EULA" VerticalAlignment="Center" Margin="0,0,8,0"/>
    </StackPanel>

    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="160"/>
      </Grid.RowDefinitions>

      <TabControl Grid.Row="0">
        <TabItem Header="Install">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Name="PanelGroups" Margin="6"/>
          </ScrollViewer>
        </TabItem>

        <TabItem Header="CSVV">
          <Grid>
            <TextBlock Margin="10" Text="Tab CSVV (de trong de sua sau)" />
          </Grid>
        </TabItem>

        <TabItem Header="FONT">
          <Grid>
            <TextBlock Margin="10" Text="Tab FONT (de trong de sua sau)"/>
          </Grid>
        </TabItem>
      </TabControl>

      <!-- Log -->
      <Grid Grid.Row="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Log" FontWeight="Bold" Margin="0,0,0,4"/>
        <TextBox Grid.Row="1" Name="TxtLog" Background="#181818" Foreground="White" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      </Grid>
    </Grid>
  </DockPanel>
</Window>
"@

# ---- Load XAML ----
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$PanelGroups        = $window.FindName("PanelGroups")
$BtnInstallSelected = $window.FindName("BtnInstallSelected")
$BtnClear           = $window.FindName("BtnClear")
$BtnGetInstalled    = $window.FindName("BtnGetInstalled")
$TxtLog             = $window.FindName("TxtLog")
$ChkSilent          = $window.FindName("ChkSilent")
$ChkAccept          = $window.FindName("ChkAccept")

# ---- Data: Apps & Groups ----
# Use "Keys" to map to $AppCatalog entries
$AppCatalog = @{
  "7zip"          = @{ Name = "7zip";            Ids = @("7zip.7zip") }
  "Chrome"        = @{ Name = "Chrome";          Ids = @("Google.Chrome") }
  "Notepad++"     = @{ Name = "Notepad++";       Ids = @("Notepad++.Notepad++") }
  "VS Code"       = @{ Name = "VS Code";         Ids = @("Microsoft.VisualStudioCode") }
  "PowerToys"     = @{ Name = "PowerToys";       Ids = @("Microsoft.PowerToys") }
  "PC Manager"    = @{ Name = "PC Manager";      Ids = @("Microsoft.PCManager") }
  "Rainmeter"     = @{ Name = "Rainmeter";       Ids = @("Rainmeter.Rainmeter") }
  "Zalo"          = @{ Name = "Zalo";            Ids = @("VNG.ZaloPC","Zalo.Zalo","VNG.Zalo","VNGCorp.Zalo") }
  "EVKey"         = @{ Name = "EVKey";           Ids = @("tranxuanthang.EVKey","EVKey.EVKey","EVKey") }
  "Office ODT"    = @{ Name = "Office ODT";      Ids = @("Microsoft.OfficeDeploymentTool") }
  "Creative Cloud"= @{ Name = "Creative Cloud";  Ids = @("Adobe.CreativeCloud","Adobe.Photoshop") }
  "AutoCAD"       = @{ Name = "AutoCAD";         Ids = @("Autodesk.AutoCAD","Autodesk.AutoCADLT") }
}

$Groups = @(
  @{ Title = "Essentials";       Keys = @("7zip","Chrome","Notepad++","VS Code","PowerToys","PC Manager","Rainmeter") },
  @{ Title = "VN Chat & Input";  Keys = @("Zalo","EVKey") },
  @{ Title = "Office";           Keys = @("Office ODT") },
  @{ Title = "Design & CAD";     Keys = @("Creative Cloud","AutoCAD") }
)

# ---- Helpers ----
function Log-Msg([string]$msg){
  $TxtLog.AppendText(("{0}  {1}`r`n" -f (Get-Date).ToString("HH:mm:ss"), $msg))
  $TxtLog.ScrollToEnd()
}

function Resolve-Id([string[]]$candidates){
  foreach($id in $candidates){
    # Use 'winget show -e --id' to verify existence
    $p = Start-Process -FilePath "winget" -ArgumentList @("show","-e","--id",$id) -PassThru -WindowStyle Hidden
    $p.WaitForExit()
    if($p.ExitCode -eq 0){ return $id }
  }
  return $null
}

function Install-ById([string]$id){
  if(-not $id){ return $false }
  $args = @("install","-e","--id",$id)
  if($ChkSilent.IsChecked){ $args += "--silent" }
  if($ChkAccept.IsChecked){
    $args += @("--accept-package-agreements","--accept-source-agreements")
  }
  Log-Msg ("Install: {0}" -f $id)
  $p = Start-Process -FilePath "winget" -ArgumentList $args -PassThru -WindowStyle Hidden
  $p.WaitForExit()
  $code = $p.ExitCode
  # Treat -1978335189 (0x8A15002B, APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE) as success
  if(($code -eq 0) -or ($code -eq -1978335189)){
    if($code -eq -1978335189){
      Log-Msg ("[OK] already installed / no applicable update: {0}" -f $id)
    } else {
      Log-Msg ("[OK] installed: {0}" -f $id)
    }
    return $true
  } else {
    Log-Msg ("[WARN] install failed (ExitCode={0})" -f $code)
    return $false
  }
}

# Dictionary to keep generated CheckBoxes
$CheckBoxes = @{}  # key -> CheckBox

# Build UI groups dynamically
foreach($g in $Groups){
  $gb = New-Object System.Windows.Controls.GroupBox
  $gb.Header = $g.Title
  $gb.Margin = "0,0,0,10"

  $panel = New-Object System.Windows.Controls.WrapPanel
  $panel.Margin = "0,0,0,0"

  foreach($k in $g.Keys){
    $info = $AppCatalog[$k]
    if(-not $info){ continue }
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Style = $window.Resources["TileCheckBox"]
    $cb.Content = $info.Name
    $cb.Tag = $k
    $cb.Width = 180
    $cb.Height = 38
    $panel.Children.Add($cb) | Out-Null
    $CheckBoxes[$k] = $cb

    # Left-click on checkbox text also triggers single install immediately (optional)
    $cb.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{ param($s,$e)
      # If user just toggles selection, do nothing else; to immediate install on double click would need extra code.
    })
    # Double-click to install immediately
    $cb.AddHandler([System.Windows.Controls.Control]::MouseDoubleClickEvent, [System.Windows.Input.MouseButtonEventHandler]{ param($s,$e)
      $key = $s.Tag
      $info2 = $AppCatalog[$key]
      if($null -eq $info2){ return }
      $id = Resolve-Id -candidates $info2.Ids
      if($null -eq $id){
        Log-Msg ("[ERR] not found on winget: {0}" -f ($info2.Ids -join " | "))
        return
      }
      $s.IsEnabled = $false
      try { [void](Install-ById -id $id) } finally { $s.IsEnabled = $true }
    })
  }

  $gb.Content = $panel
  $PanelGroups.Children.Add($gb) | Out-Null
}

# Button handlers
$BtnClear.Add_Click({
  foreach($cb in $CheckBoxes.Values){ $cb.IsChecked = $false }
  Log-Msg "Selection cleared."
})

$BtnGetInstalled.Add_Click({
  Log-Msg "winget list ..."
  $p = Start-Process -FilePath "winget" -ArgumentList @("list") -PassThru -WindowStyle Hidden -RedirectStandardOutput ([System.IO.Path]::GetTempFileName())
  $p.WaitForExit()
  try {
    $out = Get-Content -Raw $p.RedirectStandardOutput
    Log-Msg $out
  } catch {
    Log-Msg "[WARN] cannot read output."
  }
})

$BtnInstallSelected.Add_Click({
  $selectedKeys = @()
  foreach($kv in $CheckBoxes.GetEnumerator()){
    if($kv.Value.IsChecked){ $selectedKeys += $kv.Key }
  }
  if($selectedKeys.Count -eq 0){ Log-Msg "Chua chon ung dung nao."; return }
  Log-Msg ("Installing {0} item(s)..." -f $selectedKeys.Count)
  foreach($k in $selectedKeys){
    $info = $AppCatalog[$k]
    $id = Resolve-Id -candidates $info.Ids
    if($null -eq $id){
      Log-Msg ("[ERR] not found on winget: {0}" -f ($info.Ids -join " | "))
      continue
    }
    # Disable checkbox while installing
    $cb = $CheckBoxes[$k]
    $cb.IsEnabled = $false
    try { [void](Install-ById -id $id) } finally { $cb.IsEnabled = $true }
  }
  Log-Msg "Done."
})

# Show
$window.ShowDialog() | Out-Null
