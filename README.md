# StageWebView


[![browser](https://i.gyazo.com/6e82316b36a9be133e250423ab435d53.png)](https://i.gyazo.com/9c896762c7ddd5fe7b5e2c480367ef87.mp4)

`StageWebView` is a webview library for Haxe on Windows, Linux, macOS, iOS and Android.

Its public API is `webview.WebView`, for plain Haxe projects.

The native backend is vendored in this repository. hxcpp talks to it directly, and HashLink uses a shipped `stagewebview.hdll` (Windows). Lime builds the same engines into its own binaries for `lime.ui.WebView`, so a Lime application does not need this library's Haxe API at all.

From 2.0 there is no OpenFL facade here: OpenFL 9.7 has an `openfl.media.StageWebView` of its own, on `lime.ui.WebView`. For an older OpenFL, use StageWebView 1.x.

Source: `https://github.com/dimensionscapeOrg/stagewebview`

## Platforms

| Platform | Engine | Glue | Status |
| --- | --- | --- | --- |
| Windows | WebView2 | vendored `webview.h` + `project/src/WebViewBackend.cpp` | built and run in CI |
| Linux | WebKitGTK 4.1 (GTK 3) | vendored `webview.h` + `project/src/gtk` | built and run on Ubuntu 24.04, X11 and Wayland (through XWayland); the engine library for frameworks ships for x86-64 and ARM64 |
| macOS | WKWebView | `project/src/apple` (Objective-C++) | built and run in CI (macOS 14, arm64): native tests and both samples |
| iOS | WKWebView | `project/src/apple` (Objective-C++) | built in CI for the simulator, through hxcpp and as a Lime app; not run |
| Android | `android.webkit.WebView` | Haxe over `lime.system.JNI` + `android/src` | built and run in CI on an Android 14 emulator (x86_64) |

Windows keeps the code paths it had before the other platforms were added. Every other platform implements the same `WebViewBackend` C++ class through a `PlatformWebView` engine (`project/src/WebViewBackendPlatform.cpp`), except Android, which implements the Haxe backend interface directly because the webview lives in Java.

Windows needs nothing shipped beside the application: `webview.h` finds the installed WebView2 Runtime through the registry. Windows 11 includes the runtime, and most Windows 10 machines have it with Edge. Where it is missing, `WebView.isSupported` is `false`.

Linux needs the GTK and WebKitGTK development files to build (`sudo apt install pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev`); the build reads their flags from `pkg-config`. At run time it needs a display: an X server, Xvfb, or a Wayland session with XWayland.

Linux and Android deliver page events, messages, script values and PDF results only when the host calls `WebView.processEvents()`, which hosts do from their own loop. On Windows, macOS and iOS the host's event loop already does the same work.

## Why it exists

This project is trying to solve two related problems without making either side awkward.

Haxe programs should have a real webview on every native platform without taking on a framework, and frameworks should be able to build the same engines into their own binaries. `webview.WebView` is the first. `project/Files.xml` and the C++ API in `project/include/stagewebview` are the second, and they are how Lime's `lime.ui.WebView` gets its webview.

The internal backend is kept separate on purpose. That keeps the public API clean, and it is what lets a framework build the engines in.

## What is here now

- Vendored webview backend for Windows and Linux, WKWebView for macOS and iOS, and a Java host for Android
- Direct hxcpp bindings
- HashLink hdll support (Windows)
- Public `webview.WebView` API
- Hidden webviews (`hidden`) and `printToPDF()` on every platform
- Dox-generated API docs
- Samples for a standalone window with a JavaScript bridge, and for PDF reports
- A release prebuilt `stagewebview.hdll` for `Windows64`
- `project/Files.xml` and a C++ API for frameworks that build the engines in

## `webview.WebView`

`webview.WebView` is the framework-agnostic API. You can embed it inside an existing native host window, or let it create and own a top-level native window of its own.

```haxe
import webview.WebView;

var webView = new WebView(null, {
	devTools: true
});

webView.onMessage = function (message:String):Void
{
	trace("Page says: " + message);
};

webView.setWindowTitle("StageWebView Solo Deck");
webView.resize(1280, 720);
webView.loadHTML("<h1>Hello from plain Haxe</h1>");
webView.run();
```

This library provides the webview backend. It does not try to be a full general-purpose windowing toolkit, but it is comfortable embedding into one or standing up a small top-level window when that is all you need.

## JavaScript bridge

Pages talk to the host through WebView2's `window.chrome.webview` API on every platform. Where there is no WebView2, the library installs an equivalent object before page scripts run, so one page works everywhere:

```js
window.chrome.webview.addEventListener("message", function (event) {
	console.log("Haxe says " + event.data);
});
window.chrome.webview.postMessage("ready");
```

Messages are strings. The emulated bridge sends a non-string passed to `postMessage` as JSON; WebView2 itself drops it, since `onMessage` reads messages as strings.

On Android the bridge is written into the HTML for `loadHTML()`. For pages loaded by URL it is injected when the page starts loading, which can be after the page's first scripts have run.

`evaluateJavaScript()` runs a script in the page and reports its value as JSON:

```haxe
webView.evaluateJavaScript("document.title", function (success:Bool, result:String):Void
{
	trace(success ? haxe.Json.parse(result) : result);
});
```

`undefined` gives `null`, and a promise is not waited for. What a value JSON has no form for gives depends on the engine: a function is `{}` on WebView2 and `null` elsewhere. A script that throws fails with the reason, except on Android and older WebView2 Runtimes, which give `null`.

## PDF output

`printToPDF()` saves the loaded page as a paginated PDF with the platform's own print engine. It works on a webview created with `hidden`, so reports can be produced without any visible window.

```haxe
var webView = new WebView(null, {hidden: true});
webView.onLoad = function ():Void
{
	webView.printToPDF("report.pdf", {marginTop: 0.5, marginBottom: 0.5}, function (success:Bool, error:String):Void
	{
		trace(success ? "saved" : error);
	});
};
webView.loadHTML(html);
```

| Platform | How | Notes |
| --- | --- | --- |
| Windows | WebView2 `PrintToPdf` | |
| Linux | `WebKitPrintOperation` to GTK's print-to-file printer | |
| macOS | `NSPrintOperation` from `printOperationWithPrintInfo:`, run for an off-screen window | `createPDF` makes one tall page, so it is not used |
| iOS | `UIPrintPageRenderer` with the web view's print formatter | |
| Android | `WebView.createPrintDocumentAdapter` driven to a file | uses the result callbacks' hidden constructors (`android/src/android/print`); `scale` and `printBackground` are not supported |

`PDFOptions` takes the paper size and margins in inches. The defaults are US Letter with 0.4 inch margins, which is what WebView2 uses on its own, so documents come out the same everywhere unless you say otherwise.

Things learned from the report sample:

- Chromium (Windows, Android) repeats a table's `<thead>` on every printed page. WebKit (Linux, macOS, iOS) does not. With `repeatTableHeaders` (on by default) the library splits tables at the page boundaries before printing on WebKit, clones the header onto each part, and restores the page afterwards. It measures the screen layout, so styles that only exist under `@media print` are not taken into account.
- WebKit lays print pages out at 90 CSS pixels per inch where Chromium uses 96, so the same template prints about 6% larger on Linux, macOS and iOS.
- Set `print-color-adjust: exact` in templates as well as `printBackground`; engines differ in which they honour.

The callback runs from the event loop, never inside the engine's own handler, so it may close the webview or open another.

## Embedding

A framework embeds the webview as a native child of its own window, through `WindowBackend.h` (see below), as Lime's `lime.ui.WebView` does. The child is:

- Windows: a child `HWND`.
- Linux: a GTK popup window reparented into SDL's X11 window. Lime's SDL has no Wayland driver, so in a Wayland session the app runs on XWayland and the library asks GDK for X11 as well; embedding then works the same way. If GTK is forced onto Wayland (`GDK_BACKEND=wayland`) there is no X11 window to embed into: hidden webviews and PDF output still work, but no child window can be made.
- macOS and iOS: a container view added over SDL's view, sized in points.
- Android: a `FrameLayout` added over SDL's surface.

## Building it into a framework

The engines know nothing of Haxe, so a framework can build them into its own binary, as Lime does with native-desktop. `project/Files.xml` defines the file groups, `stagewebview` and, for macOS and iOS, `stagewebview-apple`. `project/include/stagewebview` is the C++ API: `WebViewBackend` for the webview and `WindowBackend.h` for a child window to host it. Android's engine is Java, in `android/src`.

```xml
<include name="${haxelib:StageWebView}/project/Files.xml" />
```

A binary that every program loads cannot link WebKitGTK, or a system without it could start none of them. On Linux such a framework builds the `stagewebview-client` group instead of `stagewebview`. It needs no GTK or WebKitGTK to build, and opens `stagewebview-gtk.so`, from `ndll/Linux64` or `ndll/LinuxArm64`, the first time a webview is asked for, looking beside the binary, then beside the program, then wherever the system looks. Where the library or WebKitGTK is missing, `WebViewBackend::isSupported()` is `false`, and nothing else notices. `project/build-gtk-engine.sh` builds the library for the machine it runs on, which CI does on its oldest x86-64 and ARM64 runners.

Depending on this haxelib costs a program nothing unless it uses `webview.WebView`: the GTK flags and the HashLink runtime are only set up as that class's backend is built.

## Classpath behavior

The published haxelib keeps `classPath` pointed at `src`, so projects only see `webview.*`.

## Samples

The repository includes a few demo projects:

- `project-report.xml`: a Lime app that renders a report in a hidden webview, fills it over the bridge and prints it to a PDF; runs on every platform
- `samples/pure-haxe/build-cpp.hxml`: standalone `webview.WebView` sample with its own native window, local HTML deck, bridge messaging, window resizing, and Haxelib search routing
- `samples/pdf/build-cpp.hxml`: headless plain-Haxe PDF sample for Windows, Linux and macOS; exits 0 once the PDF is written

Generated sample output goes under `bin`.

## Tests

The tests use [utest](https://lib.haxe.org/p/utest/) (`haxelib install utest`). The unit suite runs on the interpreter with a fake backend:

```bash
haxe build/tests.hxml
```

The native suite builds with hxcpp and drives the real platform webview through hidden instances. It covers page load events, titles, file navigation and history, init scripts and `evaluateJavaScript()`, the JavaScript bridge in both directions, and `printToPDF()` (page count, paper size, the page left unchanged afterwards, failure reporting, a callback that disposes its webview). On Linux it needs a display (`xvfb-run` works). CI runs it on Windows, Linux and macOS; Android is covered by running the report sample on an emulator.

```bash
haxe build/tests-native.hxml
bin/tests/native/NativeTestMain
```

The unit suite covers:

- `webview.WebView` state and callback behavior through a fake backend
- `printToPDF()` option defaults and result reporting
- script delegation

CI (`.github/workflows/ci.yml`) builds every platform and, where the runner can show a webview, runs the PDF samples and checks the result with `.github/scripts/check_report_pdf.py`: two pages, the table header on both.

## Docs

The docs are generated in two steps:

```bash
haxe build/docs-cpp.hxml
haxelib run dox -i docs/xml/cpp.xml -o docs/api --title StageWebView -in "^webview$" -in "^webview[.]" -ex "^webview[.]_internal"
```

The generated site ends up in `docs/api`.

## Upgrading from 1.x

The OpenFL facade is gone: `openfl.media.StageWebView`, `openfl.events.LocationChangeEvent` and `openfl.events.WebViewDrawEvent`, with `src-openfl`. OpenFL 9.7 has its own `openfl.media.StageWebView`, on Lime's `lime.ui.WebView`, and `lime.ui.WebView` also has what the facade added beyond AIR: `addInitScript()`, `postMessage()`, `evaluateJavaScript()`, `printToPDF()`, and `capture()` for drawing the view. For OpenFL before 9.7, stay on StageWebView 1.x, which Lime 8.4 depends on.

- The demo projects built on the facade (`project.xml`, `project-intermediate.xml`, `project-bridge.xml`, `project-browser.xml` and `project-docs.xml`) are gone. `samples/pure-haxe` is the demo for `webview.WebView`, and `project-report.xml` is now a Lime app.
- `stagewebview_native_handle` is no longer defined.

## Upgrading from 0.7

`webview.WebView` was renamed to read like other Haxe APIs, and each thing now has one name:

| 0.7 | 1.0 |
| --- | --- |
| `loadURL()`, `navigate()` | `load()` |
| `loadString()`, `setHtml()` | `loadHTML()` |
| `historyBack()`, `historyForward()` | `goBack()`, `goForward()` |
| `canGoBack()`, `canGoForward()`, `isHistoryBackEnabled`, `isHistoryForwardEnabled` | `canGoBack`, `canGoForward` |
| `location`, `getLocation()` | `url` |
| `getTitle()` | `title` |
| `assignFocus()` | `focus()` |
| `dispose()`, `destroy()` | `close()` |
| `setSize()`, `setBounds()` | `resize()` |
| `setTitle()` | `setWindowTitle()` |
| `fromWindow()` | `new WebView()` |
| `onComplete` | `onLoad` |
| `onLocationChange` | `onURLChange` |
| `onLocationChanging` | `onNavigate` |
| `PdfOptions` | `PDFOptions` |

Options are now typed, so a misspelled one is a compile error:

| 0.7 | 1.0 |
| --- | --- |
| `debug`, `enableDevTools` | `devTools` |
| `enableContextMenu` | `contextMenu` |
| `enableKeyboardShortcuts` | `keyboardShortcuts` |
| `enableStatusBar` | `statusBar` |
| `enableZoom` | `zoom` |
| `startHidden` | `hidden` |
| `mediaPlaybackRequiresUserAction` | `autoplay`, the other way around |

- `WebView.isSupported` is a property, read at run time, so it is no longer a constant. It is `false` on Windows without the WebView2 Runtime, and on targets with no backend, which an HTML5 build made on Windows used to get wrong.
- `WebView2Loader.dll` and the `EBWebView` folder are no longer shipped or copied beside the application. Nothing needs them, so remove them from any packaging that expects them. Applications still need the WebView2 Runtime, as they always did.
- `evaluateJavaScript()` can report the script's value, on every engine.
- `onNavigate` asks about `load()` on every engine, Android included, and no longer asks about the page from `loadHTML()`, which goes nowhere.
- A navigation cancelled through `onNavigate`, or stopped with `stop()`, no longer reaches `onError`.
- Internal classes moved from `_internal.webview` to `webview._internal`. The native sources moved from `lib` to `project`, and `build/BuildNative.xml` and `build/BuildHashlink.xml` are now `project/Build.xml` and `project/BuildHashlink.xml`.
- `haxelib.json` said MIT in error. The license has always been the Apache License 2.0.

## License

StageWebView is under the Apache License 2.0, as `LICENSE` says. `NOTICE` lists the third-party code it includes.

## Scope

- Windows, Linux, macOS, iOS and Android
- hxcpp everywhere; HashLink on Windows x64
- Engines that a framework can build into its own binaries
- Public APIs kept library-owned, with the backend kept internal
