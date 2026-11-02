# KTRU Shelf Widget

Native Windows always-on-top shelf locator. Black and marigold, Courier New. Scan or type a barcode + Enter: `Shelf [ 12C ]`.

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

Canonical allocator and capacities are preserved from [final-sorter](https://github.com/matthewlbitz/final-sorter), commit `94ac916fbf7ec25f040d9a8f803c3630f4a6b8c1`. Stored final_shelf is authoritative. The lookup backend retains canonical position calculations, but the widget intentionally displays only final_shelf until physical positions are accurate. Physical placement is not verified. Unknown and duplicate barcodes, missing assignments, and unresolved sorting metadata are handled explicitly. Type manually when a scanner cannot read a label; artist/title search is not included.

Lookup tests passed on macOS / Node 22.23.3, including read-only enforcement and WAL visibility; 464 reference-catalog shelf position samples passed with the database hash unchanged. Native Windows interaction and scanner hardware have not been tested here. Window size is 300 × 145 at 100% scaling.

The earlier ZIP remains available for historical reference. It contains a different launcher with portable-runtime setup; the source installation above does not use it. No antivirus verdict or false-positive determination has been established for that earlier ZIP.

## Compact widget update — November 2, 2026

- Window reduced by about one-sixth to 300 × 145.
- Results show only `Shelf [ 12C ]`; no position suffix.
- Gray `scan barcode...` hint appears whenever the textbox is empty, even when focused. It is an overlay, never barcode input.
- After every nonempty submitted scan (including unknown codes and lookup errors), the result resets to `Shelf: [ ]` after 30 seconds. Each subsequent scan restarts that countdown. Timer is stopped on close. Blank Enter presses do not count as scans; partially typed text is preserved during reset.

To update the existing booth installation, close the widget. Open PowerShell in the folder containing widget.ps1 and Launch.vbs, then run:

```powershell
Copy-Item .\widget.ps1 .\widget.ps1.bak -Force
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/matthewlbitz/ktruwidget/main/widget.ps1' -OutFile .\widget.ps1 -ErrorAction Stop
```

Reopen with the existing Launch.vbs shortcut. Only widget.ps1 is replaced; the data folder, database and silent launcher are retained. Keep the backup if you customized the old script. The older ZIP is not the current source update.

Validation for this update: XAML XML structure and timer placement checked locally. Windows WPF timer and layout require a booth-side check: scan, wait 30 seconds, confirm default; scan twice 20 seconds apart and confirm reset occurs 30 seconds after the latest scan. Confirm typing hides the hint and deleting text restores it.

## Click-to-locate update

The default screen asks `forgot where an album goes?` with a `[ click to locate ]` button. Click it before scanning: this reveals and focuses the scan box. A 30-second countdown starts on click, restarts after each nonempty submitted scan, and returns to the click screen on expiry. Switching to another application returns to idle immediately. Reset clears partially typed barcode text and the previous result. Pressing Enter from a scanner while idle does not activate the button. Results remain shelf-only; the window stays 300 × 145 with the same colors and font. The textbox and shelf result have slightly more top spacing.

This is a focus cue, not scanner interception: scanning while a metadata app is focused still sends keystrokes to that app. Always click the locator before scanning.

Use the same widget.ps1-only update commands above and your existing Launch.vbs shortcut. The source update leaves the catalog untouched. Structural XML and handler wiring were checked here. `powershell.exe -NoProfile -STA -File .\widget.ps1 -SmokeTest` exercises idle/scan/reset state transitions on Windows. Windows runtime/focus behavior has not been executed on this Mac. Manually confirm idle → click → scan → timeout, switching apps → idle, and a new click restores scanner focus.
