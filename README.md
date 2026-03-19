# StageWebView


[![browser](https://i.gyazo.com/6e82316b36a9be133e250423ab435d53.png)](https://i.gyazo.com/9c896762c7ddd5fe7b5e2c480367ef87.mp4)

`StageWebView` is a Windows webview library for Haxe.

It exposes two public APIs:

- `webview.WebView` for plain Haxe projects
- `openfl.media.StageWebView` for OpenFL projects that want AIR-style behavior

The native backend is vendored in this repository. hxcpp talks to it directly, HashLink uses a shipped `stagewebview.hdll`, and the OpenFL layer stays optional unless you actually import it.

Source: `https://github.com/dimensionscape/stagewebview`

## Why it exists

This project is trying to solve two related problems without making either side awkward.

OpenFL projects should have a real `StageWebView` implementation with a familiar AIR-shaped API. Non-OpenFL projects should be able to use the same backend through `webview.WebView` without inheriting OpenFL concepts, source paths, or editor noise they never asked for.

The internal backend is kept separate on purpose. That makes the public API cleaner today, and it keeps the lower layer easier to move closer to Lime later if that ever becomes the right call.

## What is here now

- Vendored Windows webview backend
- Direct hxcpp bindings
- HashLink hdll support
- Public `webview.WebView` API
- Optional OpenFL `StageWebView` facade
- Dox-generated API docs
- Samples for basic embedding, live sites, JavaScript bridging, browser UI, and docs browsing
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
- `samples/pure-haxe/build-cpp.hxml`: standalone `webview.WebView` sample with its own native window, local HTML deck, bridge messaging, window resizing, and Haxelib search routing

Generated sample output goes under `bin`.

## Tests

The lightweight test suite runs with:

```bash
haxe build/tests.hxml
```

That covers:

- `webview.WebView` state and callback behavior through a fake backend
- `openfl.media.StageWebView` constructor behavior, viewport validation, and offline state handling

## Docs

The docs are generated in two steps:

```bash
haxe build/docs-cpp.hxml
haxelib run dox -i docs/xml/cpp.xml -o docs/api --title StageWebView -in "^webview$" -in "^webview[.]" -in "^openfl$" -in "^openfl[.]media$" -in "^openfl[.]media[.]StageWebView$" -in "^openfl[.]events$" -in "^openfl[.]events[.](LocationChangeEvent|WebViewDrawEvent)$"
```

The generated site ends up in `docs/api`.

## Scope

- Windows only
- Windows x64 only for the first release
- hxcpp and HashLink
- AIR-style `StageWebView` parity where the platform allows it
- Public APIs kept library-owned, with the backend kept internal
