param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$root = $PSScriptRoot
$node = Join-Path $root 'runtime\node.exe'
if (!(Test-Path $node)) { $node = (Get-Command node -ErrorAction SilentlyContinue).Source }
if (!$node) { [System.Windows.MessageBox]::Show('Run Setup-Portable-Node.cmd first.'); exit 1 }
& $node --no-warnings -e "require('node:sqlite')" 2>$null
if ($LASTEXITCODE -ne 0) { [System.Windows.MessageBox]::Show('Node 22.13 or newer is required. Run Setup-Portable-Node.cmd.'); exit 1 }
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="KTRU / shelf lookup" Width="380" Height="245" ResizeMode="CanMinimize" Topmost="True" Background="#080808" Foreground="#FFBF00" FontFamily="Courier New" WindowStartupLocation="CenterScreen">
 <StackPanel Margin="18">
  <TextBlock Text="+- KTRU / SHELF LOOKUP -+" FontSize="14" HorizontalAlignment="Center" Margin="0,0,0,12"/>
  <DockPanel><Button Name="Choose" Content="DB" DockPanel.Dock="Right" Background="#080808" Foreground="#FFBF00" BorderBrush="#FFBF00" Padding="4,1" ToolTip="Choose database"/><TextBlock Name="Database" Text="Choose DB to begin" FontSize="10" Foreground="#C39B35" TextTrimming="CharacterEllipsis" Margin="0,0,0,6"/></DockPanel>
  <DockPanel><TextBlock Text="&gt; " FontSize="22" VerticalAlignment="Center"/><TextBox Name="Scan" FontSize="22" Padding="4" Background="#080808" Foreground="#FFBF00" CaretBrush="#FFBF00" BorderBrush="#FFBF00" BorderThickness="0,0,0,1" ToolTip="Scan or type barcode, then Enter"/></DockPanel>
  <TextBlock Name="Result" Text="Shelf: [ ]" FontSize="26" FontWeight="Bold" Margin="0,16,0,4"/>
  <TextBlock Name="Album" Text="" FontSize="12" Foreground="#C39B35" TextTrimming="CharacterEllipsis"/>
 </StackPanel>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
if ($SmokeTest) { $window.Close(); Write-Host 'WPF window loaded successfully'; exit 0 }
$scan=$window.FindName('Scan'); $result=$window.FindName('Result'); $album=$window.FindName('Album'); $database=$window.FindName('Database')
$script:db=$env:KTRU_DB
function Set-DatabaseLabel {
 if ($script:db) { $database.Text=[IO.Path]::GetFileName($script:db); $database.ToolTip=$script:db }
}
Set-DatabaseLabel
$window.FindName('Choose').Add_Click({
 $picker=New-Object Microsoft.Win32.OpenFileDialog
 $picker.Title='Select existing masterAlbums.db (read-only)'; $picker.Filter='SQLite catalog|*.db;*.sqlite;*.sqlite3|All files|*.*'
 if ($picker.ShowDialog()) { $script:db=$picker.FileName; Set-DatabaseLabel; $result.Text='Shelf: [ ]'; $album.Text='' }
 $scan.Focus() | Out-Null
})
$scan.Add_KeyDown({
 if ($_.Key -ne 'Return') { return }
 $_.Handled=$true
 $code=$scan.Text.Trim(); $scan.Clear()
 if (!$script:db) { $result.Text='Choose a database first'; return }
 # Pass barcode through the environment to avoid shell interpretation or argument quoting.
 $env:KTRU_SCAN=$code; $env:KTRU_CATALOG=$script:db
 try {
  $json=& $node --no-warnings -e "console.log(JSON.stringify(require(process.argv[1]).lookup(process.env.KTRU_CATALOG,process.env.KTRU_SCAN)))" (Join-Path $root 'lookup.cjs') 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Database unavailable, busy, or incompatible. Check path and try again.' }
  $r=$json | ConvertFrom-Json
  $album.Text=$r.message
  if ($r.status -eq 'found') {
   $position='?'; if ($null -ne $r.position) {$position=$r.position}
   $result.Text="Shelf [ $($r.shelf).$position ]"
   $album.Text="$($r.album.artist) - $($r.album.title)"
  } else { $result.Text= switch ($r.status) { 'unknown' {'Unknown barcode'} 'duplicate' {'Duplicate barcode'} 'unassigned' {'No shelf assigned'} default {'Check barcode'} }; if ($r.status -eq 'unknown') { $album.Text='Try typing the barcode, then Enter.' } }
 } catch { $result.Text='Lookup failed'; $album.Text=$_.Exception.Message }
 finally { Remove-Item Env:KTRU_SCAN -ErrorAction SilentlyContinue; Remove-Item Env:KTRU_CATALOG -ErrorAction SilentlyContinue; $scan.Focus() | Out-Null }
})
$window.Add_ContentRendered({$scan.Focus() | Out-Null})
$window.ShowDialog() | Out-Null
