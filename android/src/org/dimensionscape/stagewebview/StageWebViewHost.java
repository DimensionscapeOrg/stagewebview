package org.dimensionscape.stagewebview;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.StageWebViewPdfWriter;
import android.util.Base64;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import org.haxe.extension.Extension;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Java side of StageWebView on Android, called from Haxe through lime.system.JNI.
 *
 * <p>Haxe runs on SDL's thread; android.webkit.WebView must only be touched on the UI thread. Every
 * call here posts its work to the UI thread and returns at once. Results travel back as events in a
 * queue that Haxe drains with {@link #pollEvents()} from WebView.processEvents(). Getters read values
 * cached on the UI thread.</p>
 *
 * <p>Event wire format: records separated by U+001E, fields (view id, type, payload) by U+001F.</p>
 */
public final class StageWebViewHost {

	private static final String BRIDGE_NAME = "__stagewebview";
	private static final int HIDDEN_WIDTH = 1024;
	private static final int HIDDEN_HEIGHT = 1366;
	private static final long DECISION_TIMEOUT_MS = 250;

	private static final Handler UI = new Handler(Looper.getMainLooper());
	private static final AtomicInteger NEXT_ID = new AtomicInteger(1);
	private static final ConcurrentHashMap<Integer, Entry> VIEWS = new ConcurrentHashMap<>();
	private static final ConcurrentHashMap<Integer, FrameLayout> CONTAINERS = new ConcurrentHashMap<>();
	private static final ConcurrentHashMap<Integer, ArrayBlockingQueue<Boolean>> DECISIONS = new ConcurrentHashMap<>();
	private static final ConcurrentLinkedQueue<String> EVENTS = new ConcurrentLinkedQueue<>();

	private StageWebViewHost() {}

	private static final class Entry {
		final int id;
		final String bridgeScript;
		final List<String> initScripts = new ArrayList<>();
		WebView view;
		boolean loadFailed;
		boolean scriptsInMarkup;
		volatile boolean interceptNavigation;
		volatile String location = "";
		volatile String title = "";
		volatile boolean canGoBack;
		volatile boolean canGoForward;

		Entry(int id, String bridgeScript) {
			this.id = id;
			this.bridgeScript = bridgeScript;
		}

		/** Bridge plus init scripts, in the order a page must see them. */
		String documentStartScript() {
			StringBuilder script = new StringBuilder(bridgeScript);
			for (String init : initScripts) {
				script.append(";\n").append(init);
			}
			return script.toString();
		}
	}

	private static void emit(int id, String type, String payload) {
		EVENTS.add(id + "\u001F" + type + "\u001F" + (payload != null ? payload : ""));
	}

	private static Context context() {
		Activity activity = Extension.mainActivity;
		return activity != null ? activity : Extension.mainContext;
	}

	// ---- events ----

	public static String pollEvents() {
		StringBuilder out = null;
		String event;
		while ((event = EVENTS.poll()) != null) {
			if (out == null) {
				out = new StringBuilder();
			} else {
				out.append('\u001E');
			}
			out.append(event);
		}
		return out != null ? out.toString() : null;
	}

	/** Answers a "changing" event: Haxe decided whether the page-initiated navigation is cancelled. */
	public static void resolveNavigation(int token, boolean cancel) {
		ArrayBlockingQueue<Boolean> decision = DECISIONS.get(token);
		if (decision != null) {
			decision.offer(cancel);
		}
	}

	// ---- webviews ----

	public static int create(final int containerId, final boolean debug, final String userAgent, final int mediaRequiresGesture,
			final String bridgeScript) {
		final int id = NEXT_ID.getAndIncrement();
		final Entry entry = new Entry(id, bridgeScript);
		VIEWS.put(id, entry);

		UI.post(new Runnable() {
			@Override
			public void run() {
				if (debug) {
					WebView.setWebContentsDebuggingEnabled(true);
				}

				WebView view = new WebView(context());
				WebSettings settings = view.getSettings();
				settings.setJavaScriptEnabled(true);
				settings.setDomStorageEnabled(true);
				settings.setAllowFileAccess(true);
				if (userAgent != null && userAgent.length() > 0) {
					settings.setUserAgentString(userAgent);
				}
				if (mediaRequiresGesture != -1) {
					settings.setMediaPlaybackRequiresUserGesture(mediaRequiresGesture == 1);
				}

				view.addJavascriptInterface(new Bridge(id), BRIDGE_NAME);
				view.setWebViewClient(new Client(entry));
				view.setWebChromeClient(new WebChromeClient() {
					@Override
					public void onReceivedTitle(WebView webView, String title) {
						entry.title = title != null ? title : "";
					}
				});
				view.setOnFocusChangeListener(new View.OnFocusChangeListener() {
					@Override
					public void onFocusChange(View v, boolean hasFocus) {
						emit(id, hasFocus ? "focusIn" : "focusOut", null);
					}
				});
				entry.view = view;

				FrameLayout container = CONTAINERS.get(containerId);
				if (container != null) {
					container.addView(view, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
				} else {
					// Hidden: never attached to a window. Give it a size so pages lay out as they would on screen.
					view.measure(View.MeasureSpec.makeMeasureSpec(HIDDEN_WIDTH, View.MeasureSpec.EXACTLY),
						View.MeasureSpec.makeMeasureSpec(HIDDEN_HEIGHT, View.MeasureSpec.EXACTLY));
					view.layout(0, 0, HIDDEN_WIDTH, HIDDEN_HEIGHT);
				}
			}
		});

		return id;
	}

	public static void destroy(final int id) {
		final Entry entry = VIEWS.remove(id);
		if (entry == null) {
			return;
		}

		UI.post(new Runnable() {
			@Override
			public void run() {
				WebView view = entry.view;
				if (view == null) {
					return;
				}
				ViewGroup parent = (ViewGroup) view.getParent();
				if (parent != null) {
					parent.removeView(view);
				}
				view.removeJavascriptInterface(BRIDGE_NAME);
				view.destroy();
				entry.view = null;
			}
		});
	}

	public static void setInterceptNavigation(int id, boolean intercept) {
		Entry entry = VIEWS.get(id);
		if (entry != null) {
			entry.interceptNavigation = intercept;
		}
	}

	public static void loadUrl(final int id, final String url) {
		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				view.loadUrl(url);
			}
		});
	}

	public static void loadHtml(final int id, final String html) {
		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				// No document-start script API without androidx.webkit, so the bridge and init scripts go
				// into the markup ahead of the page's own scripts.
				String script = "<script>" + entry.documentStartScript().replace("</script", "<\\/script") + "</script>";
				entry.scriptsInMarkup = true;
				view.loadDataWithBaseURL(null, injectScript(html, script), "text/html", "UTF-8", null);
			}
		});
	}

	public static void addInitScript(final int id, final String script) {
		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				entry.initScripts.add(script);
			}
		});
	}

	public static void evaluate(final int id, final String script) {
		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				view.evaluateJavascript(script, null);
			}
		});
	}

	public static void command(final int id, final String command) {
		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				switch (command) {
					case "back":
						view.goBack();
						break;
					case "forward":
						view.goForward();
						break;
					case "reload":
						view.reload();
						break;
					case "stop":
						view.stopLoading();
						break;
					case "focus":
						view.requestFocus();
						break;
					default:
						break;
				}
			}
		});
	}

	public static String getLocation(int id) {
		Entry entry = VIEWS.get(id);
		return entry != null ? entry.location : "";
	}

	public static String getTitle(int id) {
		Entry entry = VIEWS.get(id);
		return entry != null ? entry.title : "";
	}

	public static boolean canGoBack(int id) {
		Entry entry = VIEWS.get(id);
		return entry != null && entry.canGoBack;
	}

	public static boolean canGoForward(int id) {
		Entry entry = VIEWS.get(id);
		return entry != null && entry.canGoForward;
	}

	/** Blocks the calling (SDL) thread for up to five seconds while the UI thread draws the view. */
	public static String capture(final int id, final int format) {
		final String[] result = new String[1];
		final CountDownLatch done = new CountDownLatch(1);

		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				try {
					int width = Math.max(1, view.getWidth());
					int height = Math.max(1, view.getHeight());
					Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
					view.draw(new Canvas(bitmap));
					ByteArrayOutputStream bytes = new ByteArrayOutputStream();
					bitmap.compress(format == 1 ? Bitmap.CompressFormat.JPEG : Bitmap.CompressFormat.PNG, 90, bytes);
					bitmap.recycle();
					result[0] = Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP);
				} finally {
					done.countDown();
				}
			}
		});

		try {
			done.await(5, TimeUnit.SECONDS);
		} catch (InterruptedException ignored) {
		}
		return result[0];
	}

	/**
	 * Prints the page with WebView.createPrintDocumentAdapter. Lengths are inches. The result arrives as a
	 * "pdf" event whose payload is token, success flag and error, separated by U+001D.
	 */
	public static void printToPdf(final int id, final int token, final String path, final double pageWidth, final double pageHeight,
			final double marginTop, final double marginRight, final double marginBottom, final double marginLeft, final boolean landscape) {
		if (!VIEWS.containsKey(id)) {
			emit(id, "pdf", token + "\u001D0\u001DThe webview has been disposed");
			return;
		}

		withView(id, new ViewAction() {
			@Override
			public void run(Entry entry, WebView view) {
				PrintAttributes.MediaSize media = new PrintAttributes.MediaSize("stagewebview", "StageWebView",
					mils(Math.min(pageWidth, pageHeight)), mils(Math.max(pageWidth, pageHeight)));
				media = landscape || pageWidth > pageHeight ? media.asLandscape() : media.asPortrait();

				PrintAttributes attributes = new PrintAttributes.Builder()
					.setMediaSize(media)
					.setResolution(new PrintAttributes.Resolution("stagewebview", "StageWebView", 600, 600))
					.setMinMargins(new PrintAttributes.Margins(mils(marginLeft), mils(marginTop), mils(marginRight), mils(marginBottom)))
					.setColorMode(PrintAttributes.COLOR_MODE_COLOR)
					.build();

				PrintDocumentAdapter adapter = view.createPrintDocumentAdapter("StageWebView");
				StageWebViewPdfWriter.write(adapter, attributes, new File(path), new StageWebViewPdfWriter.Listener() {
					@Override
					public void onFinished(boolean success, String error) {
						emit(id, "pdf", token + "\u001D" + (success ? "1" : "0") + "\u001D" + (error != null ? error : ""));
					}
				});
			}
		});
	}

	// ---- child containers for the OpenFL facade ----

	public static int createContainer(final int x, final int y, final int width, final int height) {
		final int id = NEXT_ID.getAndIncrement();
		UI.post(new Runnable() {
			@Override
			public void run() {
				Activity activity = Extension.mainActivity;
				if (activity == null) {
					return;
				}
				FrameLayout container = new FrameLayout(activity);
				container.setVisibility(View.GONE);
				activity.addContentView(container, layout(x, y, width, height));
				CONTAINERS.put(id, container);
			}
		});
		return id;
	}

	public static void moveContainer(final int id, final int x, final int y, final int width, final int height) {
		UI.post(new Runnable() {
			@Override
			public void run() {
				FrameLayout container = CONTAINERS.get(id);
				if (container != null) {
					FrameLayout.LayoutParams params = layout(x, y, width >= 0 ? width : container.getWidth(), height >= 0 ? height : container.getHeight());
					container.setLayoutParams(params);
				}
			}
		});
	}

	public static void setContainerVisible(final int id, final boolean visible) {
		UI.post(new Runnable() {
			@Override
			public void run() {
				FrameLayout container = CONTAINERS.get(id);
				if (container != null) {
					container.setVisibility(visible ? View.VISIBLE : View.GONE);
				}
			}
		});
	}

	public static void destroyContainer(final int id) {
		UI.post(new Runnable() {
			@Override
			public void run() {
				FrameLayout container = CONTAINERS.remove(id);
				if (container != null && container.getParent() instanceof ViewGroup) {
					((ViewGroup) container.getParent()).removeView(container);
				}
			}
		});
	}

	/** Returns keyboard focus to SDL's view. */
	public static void focusHost() {
		UI.post(new Runnable() {
			@Override
			public void run() {
				if (Extension.mainView != null) {
					Extension.mainView.requestFocus();
				}
			}
		});
	}

	// ---- helpers ----

	private interface ViewAction {
		void run(Entry entry, WebView view);
	}

	private static void withView(final int id, final ViewAction action) {
		UI.post(new Runnable() {
			@Override
			public void run() {
				Entry entry = VIEWS.get(id);
				if (entry != null && entry.view != null) {
					action.run(entry, entry.view);
				}
			}
		});
	}

	/** A negative width or height fills the activity. */
	private static FrameLayout.LayoutParams layout(int x, int y, int width, int height) {
		FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(width < 0 ? ViewGroup.LayoutParams.MATCH_PARENT : width,
			height < 0 ? ViewGroup.LayoutParams.MATCH_PARENT : height);
		params.leftMargin = x;
		params.topMargin = y;
		return params;
	}

	private static int mils(double inches) {
		return (int) Math.round(inches * 1000.0);
	}

	private static String injectScript(String html, String script) {
		String lower = html.toLowerCase();
		int head = lower.indexOf("<head");
		if (head >= 0) {
			int close = lower.indexOf('>', head);
			if (close >= 0) {
				return html.substring(0, close + 1) + script + html.substring(close + 1);
			}
		}

		int doctype = lower.startsWith("<!doctype") ? lower.indexOf('>') : -1;
		return doctype >= 0 ? html.substring(0, doctype + 1) + script + html.substring(doctype + 1) : script + html;
	}

	private static final class Bridge {
		private final int id;

		Bridge(int id) {
			this.id = id;
		}

		@JavascriptInterface
		public void postMessage(String message) {
			emit(id, "message", message);
		}
	}

	private static final class Client extends WebViewClient {
		private final Entry entry;

		Client(Entry entry) {
			this.entry = entry;
		}

		/** Page-initiated main-frame navigations ask Haxe, waiting briefly on the UI thread for the answer. */
		private boolean shouldCancel(String url) {
			if (!entry.interceptNavigation) {
				emit(entry.id, "changing", "0\u001D" + url);
				return false;
			}

			int token = NEXT_ID.getAndIncrement();
			ArrayBlockingQueue<Boolean> decision = new ArrayBlockingQueue<>(1);
			DECISIONS.put(token, decision);
			emit(entry.id, "changing", token + "\u001D" + url);
			Boolean cancel = null;
			try {
				cancel = decision.poll(DECISION_TIMEOUT_MS, TimeUnit.MILLISECONDS);
			} catch (InterruptedException ignored) {
			}
			DECISIONS.remove(token);
			return cancel != null && cancel;
		}

		@Override
		public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
			return request.isForMainFrame() && shouldCancel(request.getUrl().toString());
		}

		@Override
		@SuppressWarnings("deprecation")
		public boolean shouldOverrideUrlLoading(WebView view, String url) {
			return shouldCancel(url);
		}

		@Override
		public void onPageStarted(WebView view, String url, Bitmap favicon) {
			entry.loadFailed = false;
			if (entry.scriptsInMarkup) {
				entry.scriptsInMarkup = false;
				return;
			}

			// Pages loaded by URL get the bridge as early as WebView allows without androidx.webkit.
			view.evaluateJavascript(entry.documentStartScript(), null);
		}

		@Override
		public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
			entry.location = url != null ? url : "";
			entry.canGoBack = view.canGoBack();
			entry.canGoForward = view.canGoForward();
			emit(entry.id, "location", entry.location);
		}

		@Override
		public void onPageFinished(WebView view, String url) {
			entry.title = view.getTitle() != null ? view.getTitle() : "";
			entry.canGoBack = view.canGoBack();
			entry.canGoForward = view.canGoForward();
			if (!entry.loadFailed) {
				emit(entry.id, "complete", null);
			}
		}

		@Override
		public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
			if (Build.VERSION.SDK_INT >= 23 && request.isForMainFrame()) {
				entry.loadFailed = true;
				emit(entry.id, "error", "Navigation failed: " + error.getDescription());
			}
		}

		@Override
		@SuppressWarnings("deprecation")
		public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
			if (Build.VERSION.SDK_INT < 23) {
				entry.loadFailed = true;
				emit(entry.id, "error", "Navigation failed: " + description);
			}
		}
	}
}
