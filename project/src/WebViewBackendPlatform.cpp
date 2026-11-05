// WebViewBackend for every platform except Windows. Each call is forwarded to the platform engine
// created by createPlatformWebView (gtk/GtkWebView.cpp on Linux, apple/AppleWebView.mm on macOS and iOS).
#if !defined(_WIN32)

#include <utility>

#include "PlatformWebView.h"

namespace stagewebview {

namespace {

static const char *BASE64_TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

} // namespace

std::string PlatformWebView::base64Encode(const unsigned char *data, size_t length)
{
	if (data == nullptr || length == 0)
	{
		return std::string();
	}

	std::string encoded;
	encoded.reserve(((length + 2) / 3) * 4);

	for (size_t index = 0; index < length; index += 3)
	{
		const size_t remaining = length - index;
		const unsigned int chunk = (static_cast<unsigned int>(data[index]) << 16)
			| (remaining > 1 ? static_cast<unsigned int>(data[index + 1]) << 8 : 0)
			| (remaining > 2 ? static_cast<unsigned int>(data[index + 2]) : 0);

		encoded.push_back(BASE64_TABLE[(chunk >> 18) & 0x3F]);
		encoded.push_back(BASE64_TABLE[(chunk >> 12) & 0x3F]);
		encoded.push_back(remaining > 1 ? BASE64_TABLE[(chunk >> 6) & 0x3F] : '=');
		encoded.push_back(remaining > 2 ? BASE64_TABLE[chunk & 0x3F] : '=');
	}

	return encoded;
}

std::string PlatformWebView::jsonString(const std::string &value)
{
	std::string out;
	out.reserve(value.size() + 2);
	out.push_back('"');

	for (unsigned char c : value)
	{
		switch (c)
		{
			case '"':
				out += "\\\"";
				break;

			case '\\':
				out += "\\\\";
				break;

			case '\n':
				out += "\\n";
				break;

			case '\r':
				out += "\\r";
				break;

			case '\t':
				out += "\\t";
				break;

			default:
				if (c < 0x20)
				{
					static const char *HEX = "0123456789abcdef";
					out += "\\u00";
					out.push_back(HEX[c >> 4]);
					out.push_back(HEX[c & 0xF]);
				}
				else
				{
					out.push_back(static_cast<char>(c));
				}
				break;
		}
	}

	// U+2028 and U+2029 are valid in JSON but end a line in older JavaScript parsers.
	std::string::size_type position = 0;
	while ((position = out.find("\xE2\x80\xA8", position)) != std::string::npos)
	{
		out.replace(position, 3, "\\u2028");
	}

	position = 0;
	while ((position = out.find("\xE2\x80\xA9", position)) != std::string::npos)
	{
		out.replace(position, 3, "\\u2029");
	}

	out.push_back('"');
	return out;
}

std::string PlatformWebView::bridgeScript(const std::string &postFunction)
{
	return std::string() + "(function () {\n"
		"\tif (window.chrome && window.chrome.webview) { return; }\n"
		"\tvar post = " + postFunction + ";\n"
		"\tvar listeners = [];\n"
		"\tvar bridge = {\n"
		"\t\tpostMessage: function (message) { post(typeof message === 'string' ? message : JSON.stringify(message)); },\n"
		"\t\taddEventListener: function (type, listener) {\n"
		"\t\t\tif (type === 'message' && typeof listener === 'function' && listeners.indexOf(listener) < 0) { listeners.push(listener); }\n"
		"\t\t},\n"
		"\t\tremoveEventListener: function (type, listener) {\n"
		"\t\t\tvar index = listeners.indexOf(listener);\n"
		"\t\t\tif (type === 'message' && index >= 0) { listeners.splice(index, 1); }\n"
		"\t\t}\n"
		"\t};\n"
		"\tObject.defineProperty(bridge, '__stagewebviewDispatch', { value: function (data) {\n"
		"\t\tvar event = { data: data, source: bridge };\n"
		"\t\tlisteners.slice().forEach(function (listener) {\n"
		"\t\t\ttry { listener.call(bridge, event); } catch (error) { setTimeout(function () { throw error; }); }\n"
		"\t\t});\n"
		"\t} });\n"
		"\twindow.chrome = window.chrome || {};\n"
		"\twindow.chrome.webview = bridge;\n"
		"})();";
}

std::string PlatformWebView::tableHeaderScript(const WebViewPdfOptions &options, double cssPixelsPerInch)
{
	// Defaults match PdfOptions: US Letter, 0.4 inch margins.
	double pageWidth = options.pageWidth > 0 ? options.pageWidth : 8.5;
	double pageHeight = options.pageHeight > 0 ? options.pageHeight : 11.0;
	if (options.landscape == 1)
	{
		std::swap(pageWidth, pageHeight);
	}

	double scale = options.scale > 0 ? options.scale : 1.0;
	double contentWidth = (pageWidth - (options.marginLeft >= 0 ? options.marginLeft : 0.4) - (options.marginRight >= 0 ? options.marginRight : 0.4)) * cssPixelsPerInch / scale;
	double contentHeight = (pageHeight - (options.marginTop >= 0 ? options.marginTop : 0.4) - (options.marginBottom >= 0 ? options.marginBottom : 0.4)) * cssPixelsPerInch / scale;

	return std::string() + "(function (pageWidth, pageHeight) {\n"
		"\tif (window.__stagewebviewTables) { window.__stagewebviewTables.restore(); }\n"
		"\tvar root = document.documentElement;\n"
		"\tvar savedWidth = root.style.width;\n"
		"\tvar savedMaxWidth = root.style.maxWidth;\n"
		"\troot.style.width = pageWidth + 'px';\n"
		"\troot.style.maxWidth = pageWidth + 'px';\n"
		"\tvar undo = [];\n"
		"\tvar touched = 0;\n"
		"\tfunction top(element) { return element.getBoundingClientRect().top + window.pageYOffset; }\n"
		"\tfunction bottom(element) { return element.getBoundingClientRect().bottom + window.pageYOffset; }\n"
		"\tfunction startPage(element, pageEnd) {\n"
		"\t\telement.style.marginTop = '0px';\n"
		"\t\telement.style.marginTop = Math.max(0, pageEnd - top(element)) + 'px';\n"
		"\t\telement.style.breakBefore = 'page';\n"
		"\t\telement.style.pageBreakBefore = 'always';\n"
		"\t}\n"
		"\tfunction stripIds(element) {\n"
		"\t\telement.removeAttribute('id');\n"
		"\t\tArray.prototype.forEach.call(element.querySelectorAll('[id]'), function (node) { node.removeAttribute('id'); });\n"
		"\t\treturn element;\n"
		"\t}\n"
		"\tArray.prototype.slice.call(document.querySelectorAll('table')).forEach(function (table) {\n"
		"\t\tif (!table.tHead || table.tBodies.length !== 1 || (table.parentElement && table.parentElement.closest('table'))) { return; }\n"
		"\t\tvar original = { table: table, body: table.tBodies[0], foot: table.tFoot, style: table.getAttribute('style'), marginTop: table.style.marginTop, pieces: [] };\n"
		"\t\tvar current = table;\n"
		"\t\tvar movedWhole = false;\n"
		"\t\tfor (var guard = 0; guard < 10000; guard++) {\n"
		"\t\t\tvar rows = current.tBodies[0].rows;\n"
		"\t\t\tif (rows.length === 0) { break; }\n"
		"\t\t\tvar pageEnd = (Math.floor((top(current) + 0.5) / pageHeight) + 1) * pageHeight;\n"
		"\t\t\tvar split = -1;\n"
		"\t\t\tfor (var i = 0; i < rows.length; i++) {\n"
		"\t\t\t\tif (bottom(rows[i]) > pageEnd + 0.5) { split = i; break; }\n"
		"\t\t\t}\n"
		"\t\t\tif (split < 0) { break; }\n"
		"\t\t\tif (split === 0) {\n"
		"\t\t\t\tif (current !== table || movedWhole) { break; }\n"
		"\t\t\t\tmovedWhole = true;\n"
		"\t\t\t\tstartPage(table, pageEnd);\n"
		"\t\t\t\tcontinue;\n"
		"\t\t\t}\n"
		"\t\t\tvar piece = stripIds(current.cloneNode(false));\n"
		"\t\t\tpiece.appendChild(stripIds(current.tHead.cloneNode(true)));\n"
		"\t\t\tvar body = stripIds(current.tBodies[0].cloneNode(false));\n"
		"\t\t\tpiece.appendChild(body);\n"
		"\t\t\tArray.prototype.slice.call(rows, split).forEach(function (row) { body.appendChild(row); });\n"
		"\t\t\tif (original.foot) { piece.appendChild(original.foot); }\n"
		"\t\t\tcurrent.parentNode.insertBefore(piece, current.nextSibling);\n"
		"\t\t\tstartPage(piece, pageEnd);\n"
		"\t\t\toriginal.pieces.push(piece);\n"
		"\t\t\tcurrent = piece;\n"
		"\t\t}\n"
		"\t\tif (original.pieces.length > 0 || movedWhole) { touched++; undo.push(original); }\n"
		"\t});\n"
		"\tundo.forEach(function (original) {\n"
		"\t\toriginal.pieces.forEach(function (piece) { piece.style.marginTop = ''; });\n"
		"\t\toriginal.table.style.marginTop = original.marginTop;\n"
		"\t});\n"
		"\troot.style.width = savedWidth;\n"
		"\troot.style.maxWidth = savedMaxWidth;\n"
		"\twindow.__stagewebviewTables = { restore: function () {\n"
		"\t\tundo.forEach(function (original) {\n"
		"\t\t\toriginal.pieces.forEach(function (piece) {\n"
		"\t\t\t\tArray.prototype.slice.call(piece.tBodies[0].rows).forEach(function (row) { original.body.appendChild(row); });\n"
		"\t\t\t\tpiece.parentNode.removeChild(piece);\n"
		"\t\t\t});\n"
		"\t\t\tif (original.foot) { original.table.appendChild(original.foot); }\n"
		"\t\t\tif (original.style === null) { original.table.removeAttribute('style'); } else { original.table.setAttribute('style', original.style); }\n"
		"\t\t});\n"
		"\t\tdelete window.__stagewebviewTables;\n"
		"\t\treturn undo.length;\n"
		"\t} };\n"
		"\treturn touched;\n"
		"})(" + std::to_string(contentWidth) + ", " + std::to_string(contentHeight) + ");";
}

std::string PlatformWebView::tableHeaderRestoreScript()
{
	return "window.__stagewebviewTables ? window.__stagewebviewTables.restore() : 0;";
}

int PlatformWebView::postMessage(const char *message)
{
	std::string script = "window.chrome && window.chrome.webview && window.chrome.webview.__stagewebviewDispatch && window.chrome.webview.__stagewebviewDispatch("
		+ jsonString(message != nullptr ? message : "") + ");";
	return evaluateJavaScript(script.c_str(), nullptr, nullptr);
}

WebViewBackend *WebViewBackend::create(int debug, void *window, const WebViewCreateOptions &options)
{
	auto *platform = createPlatformWebView(debug, window, options);
	if (platform == nullptr)
	{
		return nullptr;
	}

	auto *backend = new WebViewBackend();
	backend->createOptions = options;
	backend->platform = platform;
	return backend;
}

WebViewBackend::~WebViewBackend()
{
	delete platform;
	platform = nullptr;
}

int WebViewBackend::setSize(int width, int height, int hints)
{
	return platform != nullptr ? platform->setSize(width, height, hints) : -1;
}

int WebViewBackend::navigate(const char *url)
{
	return platform != nullptr ? platform->navigate(url) : -1;
}

int WebViewBackend::setHtml(const char *html)
{
	return platform != nullptr ? platform->setHtml(html) : -1;
}

int WebViewBackend::addInitScript(const char *script)
{
	return platform != nullptr ? platform->addInitScript(script != nullptr ? script : "") : -1;
}

int WebViewBackend::evaluateJavaScript(const char *script, WebViewResultCallback callback, void *userData)
{
	return platform != nullptr ? platform->evaluateJavaScript(script != nullptr ? script : "", callback, userData) : -1;
}

void WebViewBackend::setCallbacks(const WebViewCallbackSet &value)
{
	callbacks = value;

	if (platform != nullptr)
	{
		platform->setCallbacks(value);
	}
}

int WebViewBackend::historyBack()
{
	return platform != nullptr ? platform->historyBack() : -1;
}

int WebViewBackend::historyForward()
{
	return platform != nullptr ? platform->historyForward() : -1;
}

int WebViewBackend::reload()
{
	return platform != nullptr ? platform->reload() : -1;
}

int WebViewBackend::stop()
{
	return platform != nullptr ? platform->stop() : -1;
}

int WebViewBackend::run()
{
	return platform != nullptr ? platform->run() : -1;
}

int WebViewBackend::terminate()
{
	return platform != nullptr ? platform->terminate() : -1;
}

int WebViewBackend::setTitle(const char *title)
{
	return platform != nullptr ? platform->setTitle(title != nullptr ? title : "") : -1;
}

int WebViewBackend::postMessage(const char *message)
{
	return platform != nullptr ? platform->postMessage(message) : -1;
}

int WebViewBackend::assignFocus(int direction)
{
	return platform != nullptr ? platform->assignFocus(direction) : -1;
}

int WebViewBackend::canGoBack() const
{
	return platform != nullptr ? platform->canGoBack() : 0;
}

int WebViewBackend::canGoForward() const
{
	return platform != nullptr ? platform->canGoForward() : 0;
}

std::string WebViewBackend::capturePreviewBase64(int format) const
{
	return platform != nullptr ? platform->capturePreviewBase64(format) : std::string();
}

std::string WebViewBackend::getLocation() const
{
	return platform != nullptr ? platform->getLocation() : std::string();
}

std::string WebViewBackend::getTitle() const
{
	return platform != nullptr ? platform->getTitle() : std::string();
}

void *WebViewBackend::getNativeHandle(int kind) const
{
	return platform != nullptr ? platform->getNativeHandle(kind) : nullptr;
}

int WebViewBackend::printToPdf(const char *path, const WebViewPdfOptions &options, WebViewResultCallback callback, void *userData)
{
	if (path == nullptr || path[0] == '\0')
	{
		return -1;
	}

	return platform != nullptr ? platform->printToPdf(path, options, callback, userData) : -1;
}

void WebViewBackend::webView2ControllerSetBounds(void *controllerHandle, int width, int height)
{
	(void)controllerHandle;
	(void)width;
	(void)height;
}

bool WebViewBackend::isSupported()
{
	return PlatformWebView::isSupported();
}

int WebViewBackend::processEvents()
{
	return PlatformWebView::processEvents();
}

} // namespace stagewebview

#endif
