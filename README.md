# KTRU Shelf Widget

Minimal Windows always-on-top barcode shelf locator. Black and marigold, Courier New. Scan a barcode and see **Shelf [ 12C.1 ]** (shelf label + canonical position). Read-only catalog access.

## Download on the Windows station

1. [Download the complete widget ZIP](https://github.com/matthewlbitz/ktruwidget/raw/refs/heads/main/ktru-shelf-widget.zip).
2. Right-click the downloaded ZIP → **Extract All** into a new folder.
3. Open the extracted `ktru-shelf-widget` folder.
4. Double-click **Setup-Portable-Node.cmd** once if Node 22.13+ is not installed (internet required; no administrator access needed).
5. Double-click **Launch.cmd**.
6. Click **DB** and choose the existing station `masterAlbums.db` used by the other KTRU tools. The widget never replaces or edits it.
7. Scan or type a barcode and press Enter.

For a quick demo, run **Launch-Demo.cmd** and type `001234`. You should see **Shelf [ 12C.1 ]**. Demo data are synthetic.

Unknown barcodes show a message; the input remains ready. If a scanner cannot read a label, type the barcode manually. Artist/title search is not included.

The complete source, tests, canonical allocator reference, Windows launchers, and Mac browser preview are inside the ZIP. Full instructions and test results are included. Window size: 380 × 245 at 100% scaling. Lookup logic tested against the reference catalog; Windows UI and scanner hardware still require a station-side check.

Source reference: [final-sorter](https://github.com/matthewlbitz/final-sorter), commit `94ac916fbf7ec25f040d9a8f803c3630f4a6b8c1`. Positions follow canonical catalog order; physical placement is not verified. No live station database is included.
