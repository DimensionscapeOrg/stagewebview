# StageWebView


[![browser](https://i.gyazo.com/6e82316b36a9be133e250423ab435d53.png)](https://i.gyazo.com/9c896762c7ddd5fe7b5e2c480367ef87.mp4)

`StageWebView` is a webview library for Haxe on Windows, Linux, macOS, iOS and Android.

It exposes two public APIs:

- `webview.WebView` for plain Haxe projects
- `openfl.media.StageWebView` for OpenFL projects that want AIR-style behavior

The native backend is vendored in this repository. hxcpp talks to it directly, HashLink uses a shipped `stagewebview.hdll` (Windows), and the OpenFL layer stays optional unless you actually import it.

Source: `https://github.com/dimensionscapeOrg/stagewebview`

## Platforms

| Platform | Engine | Glue | Status |
| --- | --- | --- | --- |
| Windows | WebView2 | vendored `webview.h` + `lib/WebViewBackend.cpp` | built and run |
| Linux | WebKitGTK 4.1 (GTK 3) | vendored `webview.h` + `lib/gtk` | built and run on Ubuntu 24.04, X11 and Wayland (through XWayland) |
| macOS | WKWebView | `lib/apple` (Objective-C++) | written, not yet compiled: CI builds and runs it |
| iOS | WKWebView | `lib/apple` (Objective-C++) | written, not yet compiled: CI compiles it, nothing runs it |
| Android | `android.webkit.WebView` | Haxe over `lime.system.JNI` + `android/src` | built and run on an Android 14 emulator (x86_64) |

Windows keeps the code paths it had before the other platforms were added. Every other platform implements the same `WebViewBackend` C++ class through a `PlatformWebView` engine (`lib/WebViewBackendPlatform.cpp`), except Android, which implements the Haxe backend interface directly because the webview lives in Java.

Linux needs the GTK and WebKitGTK development files to build (`sudo apt install pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev`); the build reads their flags from `pkg-config`. At run time it needs a display: an X server, Xvfb, or a Wayland session with XWayland.

Linux and Android deliver page events, messages and PDF results only when the host calls `WebView.processEvents()`. The OpenFL facade does that every frame; plain Haxe hosts call it from their own loop. On Windows, macOS and iOS the host's event loop already does the same work.

## Why it exists

This project is trying to solve two related problems without making either side awkward.

OpenFL projects should have a real `StageWebView` implementation with a familiar AIR-shaped API. Non-OpenFL projects should be able to use the same backend through `webview.WebView` without inheriting OpenFL concepts, source paths, or editor noise they never asked for.

The internal backend is kept separate on purpose. That makes the public API cleaner today, and it keeps the lower layer easier to move closer to Lime later if that ever becomes the right call.

## What is here now

- Vendored webview backend for Windows and Linux, WKWebView for macOS and iOS, and a Java host for Android
- Direct hxcpp bindings
- HashLink hdll support (Windows)
- Public `webview.WebView` API
- Optional OpenFL `StageWebView` facade
- Hidden webviews (`startHidden`) and `printToPDF()` on every platform
- Dox-generated API docs
- Samples for basic embedding, live sites, JavaScript bridging, browser UI, docs browsing and PDF reports
- Release prebuilts for `Windows64`

## `webview.WebView`

`webview.WebView` is the framework-agnostic API. You can embed it inside an existing native host window, or let it create and own a top-level native window of its own.

```haxe
import webview.WebView;
import webview.WebViewHint;

var webView = new WebView(null, {
	debug: true
});

webView.onMessage = function (message:String):Void
{
	trace("Page says: " + message);
};

webView.setTitle("StageWebView Solo Deck");
webView.setSize(1280, 720, WebViewHint.NONE);
webView.loadString("<h1>Hello from plain Haxe</h1>");
webView.run();
```

This library provides the webview backend. It does not try to be a full general-purpose windowing toolkit, but it is comfortable embedding into one or standing up a small top-level window when that is all you need.

## `openfl.media.StageWebView`

The OpenFL API sits on top of the same backend and aims for AIR parity where that is practical on Windows.

```haxe
import openfl.geom.Rectangle;
import openfl.media.StageWebView;

var webView = new StageWebView();
webView.stage = stage;
webView.viewPort = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
webView.loadURL("https://www.openfl.org");
```

## JavaScript bridge

Pages talk to the host through WebView2's `window.chrome.webview` API on every platform. Where there is no WebView2, the library installs an equivalent object before page scripts run, so one page works everywhere:

```js
window.chrome.webview.addEventListener("message", function (event) {
	console.log("Haxe says " + event.data);
});
window.chrome.webview.postMessage("ready");
```

Messages are strings. The emulated bridge sends a non-string passed to `postMessage` as JSON; WebView2 itself drops it, since `onMessage` reads messages as strings.

On Android the bridge is written into the HTML for `loadString()`. For pages loaded by URL it is injected when the page starts loading, which can be after the page's first scripts have run.

## PDF output

`printToPDF()` saves the loaded page as a paginated PDF with the platform's own print engine. It works on a webview created with `startHidden`, so reports can be produced without any visible window.

```haxe
var webView = new WebView(null, {startHidden: true});
webView.onComplete = function ():Void
{
	webView.printToPDF("report.pdf", {marginTop: 0.5, marginBottom: 0.5}, function (success:Bool, error:String):Void
	{
		trace(success ? "saved" : error);
	});
};
webView.loadString(html);
```

| Platform | How | Notes |
| --- | --- | --- |
| Windows | WebView2 `PrintToPdf` | |
| Linux | `WebKitPrintOperation` to GTK's print-to-file printer | |
| macOS | `NSPrintOperation` from `printOperationWithPrintInfo:`, run for an off-screen window | `createPDF` makes one tall page, so it is not used |
| iOS | `UIPrintPageRenderer` with the web view's print formatter | |
| Android | `WebView.createPrintDocumentAdapter` driven to a file | uses the result callbacks' hidden constructors (`android/src/android/print`); `scale` and `printBackground` are not supported |

`PdfOptions` takes the paper size and margins in inches. The defaults are US Letter with 0.4 inch margins, which is what WebView2 uses on its own, so documents come out the same everywhere unless you say otherwise.

Things learned from the report sample:

- Chromium (Windows, Android) repeats a table's `<thead>` on every printed page. WebKit (Linux, macOS, iOS) does not. With `repeatTableHeaders` (on by default) the library splits tables at the page boundaries before printing on WebKit, clones the header onto each part, and restores the page afterwards. It measures the screen layout, so styles that only exist under `@media print` are not taken into account.
- WebKit lays print pages out at 90 CSS pixels per inch where Chromium uses 96, so the same template prints about 6% larger on Linux, macOS and iOS.
- Set `print-color-adjust: exact` in templates as well as `printBackground`; engines differ in which they honour.

The callback runs from the event loop, never inside the engine's own handler, so it may dispose the webview or open another.

## Embedding

The OpenFL facade places a native child over the stage at `viewPort`:

- Windows: a child `HWND`.
- Linux: a GTK popup window reparented into SDL's X11 window. Lime 8.3.2's SDL has no Wayland driver, so in a Wayland session the app runs on XWayland and the library asks GDK for X11 as well; embedding then works the same way. If GTK is forced onto Wayland (`GDK_BACKEND=wayland`) there is no X11 window to embed into: hidden webviews and PDF output still work, and the facade dispatches an `ErrorEvent` instead of showing the view.
- macOS and iOS: a container view added over SDL's view, sized in points.
- Android: a `FrameLayout` added over SDL's surface.

## Classpath behavior

The published haxelib keeps `classPath` pointed at `src`, so pure Haxe projects only see `webview.*` by default.

When `openfl` is defined, `extraParams.hxml` adds `src-openfl` automatically. That makes `openfl.media.StageWebView` available for OpenFL users without dumping `openfl.*` completion noise into projects that do not use OpenFL at all.

## Samples

The repository includes a few demo projects:

- `project.xml`: minimal sample
- `project-intermediate.xml`: live-site demo
- `project-bridge.xml`: JavaScript-to-Haxe bridge demo
- `project-browser.xml`: browser-style sample with tabs and controls
- `project-docs.xml`: local viewer for the generated API docs
- `project-report.xml`: renders a report in a hidden webview, fills it over the bridge, prints it to PDF and shows the filled report on stage; runs on every platform
- `samples/pure-haxe/build-cpp.hxml`: standalone `webview.WebView` sample with its own native window, local HTML deck, bridge messaging, window resizing, and Haxelib search routing
- `samples/pdf/build-cpp.hxml`: headless plain-Haxe PDF sample for Windows, Linux and macOS; exits 0 once the PDF is written

Generated sample output goes under `bin`.

## Tests

The tests use [utest](https://lib.haxe.org/p/utest/) (`haxelib install utest`). The unit suite runs on the interpreter with a fake backend:

```bash
haxe build/tests.hxml
```

The native suite builds with hxcpp and drives the real platform webview through hidden instances: page load events, the JavaScript bridge in both directions, and `printToPDF()` writing a two-page file. On Linux it needs a display (`xvfb-run` works).

```bash
haxe build/tests-native.hxml
bin/tests/native/NativeTestMain
```

The unit suite covers:

- `webview.WebView` state and callback behavior through a fake backend
- `openfl.media.StageWebView` constructor behavior, viewport validation, and offline state handling
- `printToPDF()` option defaults and result reporting

CI (`.github/workflows/ci.yml`) builds every platform and, where the runner can show a webview, runs the PDF samples and checks the result with `.github/scripts/check_report_pdf.py`: two pages, the table header on both.

## Docs

The docs are generated in two steps:

```bash
haxe build/docs-cpp.hxml
haxelib run dox -i docs/xml/cpp.xml -o docs/api --title StageWebView -in "^webview$" -in "^webview[.]" -in "^openfl$" -in "^openfl[.]media$" -in "^openfl[.]media[.]StageWebView$" -in "^openfl[.]events$" -in "^openfl[.]events[.](LocationChangeEvent|WebViewDrawEvent)$"
```

The generated site ends up in `docs/api`.

## Scope

- Windows, Linux, macOS, iOS and Android
- hxcpp everywhere; HashLink on Windows x64
- AIR-style `StageWebView` parity where the platform allows it
- Public APIs kept library-owned, with the backend kept internal
