package webview;

/**
	How `webview.WebView.printToPDF()` lays the page out. Sizes are in inches, and
	everything is optional: the defaults are US Letter with 0.4 inch margins,
	which is also what WebView2 uses when it is given no settings, so a document
	prints the same on every platform unless you change them.

	## Example

	```haxe
	webView.printToPDF("report.pdf", {
		pageWidth: 8.27,
		pageHeight: 11.69,
		marginTop: 0.5,
		marginBottom: 0.5
	}, function(success, error) {
		trace(success ? "saved" : error);
	});
	```
**/
typedef PDFOptions =
{
	/**
		Whether the page is turned on its side. `false` by default.
	**/
	@:optional var landscape:Bool;

	@:optional var marginBottom:Float;

	@:optional var marginLeft:Float;

	@:optional var marginRight:Float;

	@:optional var marginTop:Float;

	@:optional var pageHeight:Float;

	@:optional var pageWidth:Float;

	/**
		Whether CSS backgrounds and background images print. `true` by default.
	**/
	@:optional var printBackground:Bool;

	/**
		Whether each table's `<thead>` repeats on every page the table spans. `true`
		by default.

		Chromium engines (Windows, Android) repeat headers natively. WebKit
		engines (Linux, macOS, iOS) do not, so before printing the library splits
		tables at the page boundaries in a copy of the layout measured at the
		printable width, clones the header onto each continuation, prints, and
		then restores the page. Styles that only apply under `@media print` are
		not seen by that measurement.
	**/
	@:optional var repeatTableHeaders:Bool;

	/**
		The size of the page's content, where `1` is its own size. `1` by default.
	**/
	@:optional var scale:Float;
}
