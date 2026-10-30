package webview;

/**
	Page geometry for `webview.WebView.printToPDF()`.

	Lengths are in inches. The defaults are US Letter with 0.4 inch margins,
	which is also what WebView2 uses when it is given no settings, so a document
	prints the same on every platform unless you change them.

	Available fields:

	- `pageWidth`, `pageHeight`: Paper size in inches.
	- `marginTop`, `marginRight`, `marginBottom`, `marginLeft`: Margins in inches.
	- `landscape`: Rotates the paper.
	- `printBackground`: Prints CSS backgrounds and background images.
	- `scale`: Content scale factor, where `1.0` is 100%.
	- `repeatTableHeaders`: Repeats each table's `<thead>` on every page it
	  spans. Chromium (Windows, Android) does this itself; on WebKit (Linux,
	  macOS, iOS) the library splits tables at page breaks before printing and
	  restores the page afterwards.

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
@:structInit
class PdfOptions
{
	/** Paper width in inches. **/
	public var pageWidth:Float = 8.5;

	/** Paper height in inches. **/
	public var pageHeight:Float = 11;

	/** Top margin in inches. **/
	public var marginTop:Float = 0.4;

	/** Right margin in inches. **/
	public var marginRight:Float = 0.4;

	/** Bottom margin in inches. **/
	public var marginBottom:Float = 0.4;

	/** Left margin in inches. **/
	public var marginLeft:Float = 0.4;

	/** Rotates the paper to landscape. **/
	public var landscape:Bool = false;

	/** Prints CSS backgrounds and background images. **/
	public var printBackground:Bool = true;

	/** Content scale factor, where `1.0` is 100%. **/
	public var scale:Float = 1.0;

	/**
		Repeats each table's `<thead>` on every page the table spans.

		Chromium engines (Windows, Android) repeat headers natively. WebKit
		engines (Linux, macOS, iOS) do not, so before printing the library splits
		tables at the page boundaries in a copy of the layout measured at the
		printable width, clones the header onto each continuation, prints, and
		then restores the page. Styles that only apply under `@media print` are
		not seen by that measurement.
	**/
	public var repeatTableHeaders:Bool = true;
}
