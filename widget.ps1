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
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="KTRU / shelf lookup" Width="300" Height="145" WindowStyle="None" ResizeMode="NoResize" Topmost="True" Background="#080808" Foreground="#FFBF00" FontFamily="Courier New" WindowStartupLocation="CenterScreen">
 <Border BorderBrush="#FFBF00" BorderThickness="1" Padding="10">
  <StackPanel>
   <Grid Name="Header" Background="#080808" Margin="0,0,0,10" ToolTip="Drag to move">
    <TextBlock Text="+- KTRU / SHELF LOOKUP -+" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    <Button Name="Close" Content="x" HorizontalAlignment="Right" Width="20" Height="20" Background="#080808" Foreground="#FFBF00" BorderThickness="0" FontFamily="Courier New" FontSize="14" ToolTip="Close" AutomationProperties.Name="Close widget"/>
   </Grid>
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
   <TextBlock Name="Result" Text="Shelf: [ ]" FontSize="21" FontWeight="Bold" Margin="0,12,0,0" TextTrimming="CharacterEllipsis"/>
  </StackPanel>
 </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
if ($SmokeTest) { $window.Close(); Write-Host 'WPF window loaded successfully'; exit 0 }
$scan=$window.FindName('Scan'); $script:result=$window.FindName('Result')
$script:db=Join-Path $root 'data\masterAlbums.db'
$script:idleTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:idleTimer.Interval = [TimeSpan]::FromSeconds(30)
$script:idleTimer.Add_Tick({
 $script:idleTimer.Stop()
 $script:result.Text='Shelf: [ ]'
 $script:result.ToolTip=$null
})
$window.Add_Closed({$script:idleTimer.Stop()})
$window.FindName('Close').Add_Click({$window.Close()})
$window.FindName('Header').Add_MouseLeftButtonDown({if ($_.ButtonState -eq 'Pressed') {$window.DragMove()}})
if (!(Test-Path -LiteralPath $script:db -PathType Leaf)) { $result.Text='Database missing'; $result.ToolTip="Put masterAlbums.db in: $(Join-Path $root 'data')" }
$scan.Add_KeyDown({
 if ($_.Key -ne 'Return') { return }
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
  $script:idleTimer.Start()
  $scan.Focus() | Out-Null
 }
})
$window.Add_ContentRendered({$scan.Focus() | Out-Null})
$window.ShowDialog() | Out-Null
