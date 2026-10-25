# KTRU Shelf Widget

Native Windows always-on-top shelf locator. Black and marigold, Courier New. Scan or type a barcode + Enter: `Shelf [ 12C.1 ]`.

## Install source files without Git

Open **PowerShell** normally (no administrator needed), then paste:

```powershell
$widgetFolder = Join-Path $env:USERPROFILE 'Downloads\ktruwidget-source'
New-Item -ItemType Directory -Force $widgetFolder | Out-Null
$sourceBase = 'https://raw.githubusercontent.com/matthewlbitz/ktruwidget/main/'
$sourceFiles = @('Launch.cmd', 'widget.ps1', 'lookup.cjs', 'shelf-allocation.js', 'shelf-capacities.json')
foreach ($sourceFile in $sourceFiles) {
    Invoke-WebRequest -UseBasicParsing ($sourceBase + $sourceFile) -OutFile (Join-Path $widgetFolder $sourceFile) -ErrorAction Stop
}
New-Item -ItemType Directory -Force (Join-Path $widgetFolder 'data') | Out-Null
Set-Location $widgetFolder
.\Launch.cmd
```

Uses the station's existing Node at `C:\Users\RCS\Downloads\node-v24.21.0-win-x64\node-v24.21.0-win-x64`. Edit Launch.cmd if that location differs. No runtime download or npm install is required.

If Windows Security blocks a file, leave it blocked and stop. This method does not disable antivirus, unblock files, or override PowerShell execution policy. If your computer's policy prohibits scripts, this launcher cannot override it; an approved station launch process is required.

## Database location

Place a **consistent SQLite backup/export** of the station catalog here:

`C:\Users\RCS\Downloads\ktruwidget-source\data\masterAlbums.db`

Create the `data` folder if needed. Do not move or overwrite the station's live database. If the sorter is running in WAL mode, copying only its .db file can omit committed data; use its existing SQLite backup process, or close all catalog apps cleanly before making the copy. The widget reads this dedicated copy without modifying it. Refresh that copy when you need updated assignments, with the widget closed.

There is no DB selector or album-name line. The custom black/marigold header replaces the standard Windows title bar; drag it to move, click x or press Alt+F4 to close. The window stays on top. Missing databases display `Database missing`; hover over the result for the expected folder. No station database is included.

## Start again later

From Command Prompt:

```cmd
cd /d "%USERPROFILE%\Downloads\ktruwidget-source"
Launch.cmd
```

## Source and validation

Canonical allocator and capacities are preserved from [final-sorter](https://github.com/matthewlbitz/final-sorter), commit `94ac916fbf7ec25f040d9a8f803c3630f4a6b8c1`. Stored final_shelf is authoritative. Position is computed in canonical order among all albums assigned to that shelf, including unbarcoded albums. Physical placement is not verified. Unknown and duplicate barcodes, missing assignments, and unresolved sorting metadata are handled explicitly. Type manually when a scanner cannot read a label; artist/title search is not included.

Lookup tests passed on macOS / Node 22.23.3, including read-only enforcement and WAL visibility; 464 reference-catalog shelf position samples passed with the database hash unchanged. Native Windows interaction and scanner hardware have not been tested here. Window size is 360 × 174 at 100% scaling.

The earlier ZIP remains available for historical reference. It contains a different launcher with portable-runtime setup; the source installation above does not use it. No antivirus verdict or false-positive determination has been established for that earlier ZIP.
