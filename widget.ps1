param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$root = $PSScriptRoot
$node = Join-Path $root 'runtime\node.exe'
if (!(Test-Path $node)) { $node = (Get-Command node -ErrorAction SilentlyContinue).Source }
if (!$node) { [System.Windows.MessageBox]::Show('Node was not found. Start with Launch.cmd using the station Node path.'); exit 1 }
& $node --no-warnings -e "require('node:sqlite')" 2>$null
if ($LASTEXITCODE -ne 0) { [System.Windows.MessageBox]::Show('Node 22.13 or newer is required. Check the Node path in Launch.cmd.'); exit 1 }
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="KTRU / shelf lookup" Width="290" Height="160" WindowStyle="None" ResizeMode="NoResize" Topmost="True" Background="#080808" Foreground="#FFBF00" FontFamily="Courier New" WindowStartupLocation="CenterScreen">
 <Border BorderBrush="#FFBF00" BorderThickness="1" Padding="10">
  <Grid>
   <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
   <Grid Name="Header" Background="#080808" Margin="0,0,0,16" ToolTip="Drag to move">
    <TextBlock Text="+- KTRU / SHELF LOOKUP -+" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    <Button Name="Close" Content="x" HorizontalAlignment="Right" Width="20" Height="20" Background="#080808" Foreground="#FFBF00" BorderThickness="0" FontFamily="Courier New" FontSize="14" ToolTip="Close" AutomationProperties.Name="Close widget"/>
   </Grid>
   <StackPanel Name="IdlePanel" Grid.Row="1" VerticalAlignment="Center" Margin="0,-10,0,0">
    <TextBlock Text="forgot where an album goes?" Foreground="#FFBF00" FontSize="16" HorizontalAlignment="Center" Margin="0,-8,0,20"/>
    <Button Name="Locate" Content="[ click to locate ]" FontFamily="Courier New" FontSize="16" Cursor="Hand" Padding="10,5" HorizontalAlignment="Center" AutomationProperties.Name="Click to locate an album">
     <Button.Template>
      <ControlTemplate TargetType="Button">
       <Border Name="ButtonBorder" Background="#080808" BorderBrush="#FFBF00" BorderThickness="1" Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
       </Border>
       <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#FFBF00"/><Setter Property="Foreground" Value="#080808"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#D9A300"/></Trigger>
       </ControlTemplate.Triggers>
      </ControlTemplate>
     </Button.Template>
     <Button.Style><Style TargetType="Button"><Setter Property="Foreground" Value="#FFBF00"/></Style></Button.Style>
    </Button>
   </StackPanel>
   <StackPanel Name="ScanPanel" Grid.Row="1" Visibility="Collapsed">
   <DockPanel>
    <TextBlock Text="&gt; " FontSize="18" VerticalAlignment="Center"/>
    <Grid>
     <TextBox Name="Scan" FontSize="18" Padding="4" Background="#080808" Foreground="#FFBF00" CaretBrush="#FFBF00" BorderBrush="#FFBF00" BorderThickness="0,0,0,1" ToolTip="Scan or type barcode, then Enter" AutomationProperties.Name="Barcode"/>
     <TextBlock Text="scan barcode..." Foreground="#808080" FontSize="18" Margin="4,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False">
      <TextBlock.Style>
       <Style TargetType="TextBlock">
        <Setter Property="Visibility" Value="Collapsed"/>
        <Style.Triggers>
         <DataTrigger Binding="{Binding Text, ElementName=Scan}" Value="">
          <Setter Property="Visibility" Value="Visible"/>
         </DataTrigger>
        </Style.Triggers>
       </Style>
      </TextBlock.Style>
     </TextBlock>
    </Grid>
   </DockPanel>
   <TextBlock Name="Result" Text="Shelf: [ ]" FontSize="21" FontWeight="Bold" Margin="0,18,0,0" TextTrimming="CharacterEllipsis"/>
   </StackPanel>
  </Grid>
 </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$script:scan=$window.FindName('Scan'); $script:result=$window.FindName('Result')
$script:idlePanel=$window.FindName('IdlePanel'); $script:scanPanel=$window.FindName('ScanPanel')
$script:armed=$false
$script:db=Join-Path $root 'data\masterAlbums.db'
$script:idleTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:idleTimer.Interval = [TimeSpan]::FromSeconds(30)
function Reset-Locator {
 $script:idleTimer.Stop()
 $script:armed=$false
 $script:scan.Clear()
 $script:result.Text='Shelf: [ ]'
 $script:result.ToolTip=$null
 $script:scanPanel.Visibility='Collapsed'
 $script:idlePanel.Visibility='Visible'
}
function Start-Locator {
 $script:idlePanel.Visibility='Collapsed'
 $script:scanPanel.Visibility='Visible'
 $script:armed=$true
 $script:scan.Focus() | Out-Null
 [System.Windows.Input.Keyboard]::Focus($script:scan) | Out-Null
 $script:idleTimer.Stop()
 $script:idleTimer.Start()
}
$script:idleTimer.Add_Tick({Reset-Locator})
$window.Add_Deactivated({Reset-Locator})
$window.Add_Closed({$script:idleTimer.Stop()})
$window.FindName('Locate').Add_Click({Start-Locator})
$window.FindName('Close').Add_Click({$window.Close()})
$window.FindName('Header').Add_MouseLeftButtonDown({if ($_.ButtonState -eq 'Pressed') {$window.DragMove()}})
# A keyboard-wedge scanner's Enter must not activate the idle button.
$window.Add_PreviewKeyDown({
 if (!$script:armed -and ($_.Key -eq 'Return' -or $_.Key -eq 'Space')) { $_.Handled=$true }
})
$scan.Add_KeyDown({
 if (!$script:armed -or $_.Key -ne 'Return') { return }
 $_.Handled=$true
 $code=$scan.Text.Trim()
 if (!$code) { return }
 $scan.Clear()
 $script:idleTimer.Stop()
 $script:result.ToolTip=$null
 # Pass barcode through the environment to avoid shell interpretation or argument quoting.
 try {
  if (!(Test-Path -LiteralPath $script:db -PathType Leaf)) {
   $script:result.Text='Database missing'
   $script:result.ToolTip="Put masterAlbums.db in: $(Join-Path $root 'data')"
   return
  }
  $env:KTRU_SCAN=$code; $env:KTRU_CATALOG=$script:db
  $json=& $node --no-warnings -e "console.log(JSON.stringify(require(process.argv[1]).lookup(process.env.KTRU_CATALOG,process.env.KTRU_SCAN)))" (Join-Path $root 'lookup.cjs') 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Database unavailable, busy, or incompatible. Check path and try again.' }
  $r=$json | ConvertFrom-Json
  if ($r.status -eq 'found') {
   $script:result.Text="Shelf [ $($r.shelf) ]"
  } else {
   $script:result.Text= switch ($r.status) {
    'unknown' {'Unknown barcode'}
    'duplicate' {'Duplicate barcode'}
    'unassigned' {'No shelf assigned'}
    default {'Check barcode'}
   }
  }
 } catch {
  $script:result.Text='Lookup failed'
  $script:result.ToolTip=$_.Exception.Message
 } finally {
  Remove-Item Env:KTRU_SCAN -ErrorAction SilentlyContinue
  Remove-Item Env:KTRU_CATALOG -ErrorAction SilentlyContinue
  if ($script:armed) {
   $script:idleTimer.Start()
   if ($window.IsActive) { $scan.Focus() | Out-Null }
  }
 }
})
Reset-Locator
if ($SmokeTest) {
 # Exercise state transitions without a database or real scan. Run on Windows/STA.
 if ($script:armed -or $script:scanPanel.Visibility -ne 'Collapsed') { throw 'Must start idle' }
 Start-Locator
 if (!$script:armed -or $script:scanPanel.Visibility -ne 'Visible') { throw 'Click must arm scanning' }
 if (!$script:idleTimer.IsEnabled -or $script:idleTimer.Interval.TotalSeconds -ne 30) { throw '30-second timer must run after click' }
 $script:scan.Text='partial barcode'
 $script:result.Text='Shelf [ 12C ]'
 Reset-Locator
 if ($script:armed -or $script:scan.Text -ne '' -or $script:idleTimer.IsEnabled) { throw 'Reset must disarm and clear' }
 if ($script:result.Text -ne 'Shelf: [ ]' -or $script:idlePanel.Visibility -ne 'Visible') { throw 'Reset must show idle prompt' }
 $window.Close()
 Write-Host 'Window and click/idle transitions passed; live focus and scanner behavior still need manual checks.'
 exit 0
}
$window.ShowDialog() | Out-Null
