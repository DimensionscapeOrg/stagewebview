package demo.report;

import haxe.Json;

/**
	The report the PDF samples print: an HTML template whose table rows arrive
	from Haxe over the JavaScript bridge, long enough to break across two pages
	with the table header repeated on the second.

	Bridge protocol (all messages are JSON strings):

	- page to host `{"type":"ready","engine":navigator.userAgent}` once the page
	  script runs;
	- host to page `{"type":"fill","title":...,"rows":[...]}` with the values;
	- page to host `{"type":"filled","rows":n,"height":px}` after the DOM is built.
**/
class ReportDocument
{
	public static inline final ROW_COUNT:Int = 40;

	public static function html():String
	{
		return '<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>StageWebView PDF sample</title>
<style>
	html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
	body { margin: 0; font: 11pt/1.35 "DejaVu Sans", "Helvetica Neue", Arial, sans-serif; color: #1b2733; }
	h1 { margin: 0 0 4pt; font-size: 18pt; color: #1f4e79; }
	.meta { margin: 0 0 12pt; color: #52606d; }
	table { width: 100%; border-collapse: collapse; }
	thead { display: table-header-group; }
	tr { break-inside: avoid; page-break-inside: avoid; }
	th { background: #1f4e79; color: #ffffff; text-align: left; padding: 5pt 6pt; }
	td { padding: 4pt 6pt; border-bottom: 1px solid #c9d3dd; }
	td.number, th.number { text-align: right; }
	tbody tr:nth-child(even) td { background: #eef3f8; }
	.end { margin-top: 12pt; font-style: italic; color: #52606d; }
</style>
</head>
<body>
<h1 id="title">Waiting for values</h1>
<p class="meta" id="bridge">Bridge: not connected</p>
<table>
	<thead>
		<tr><th>#</th><th>Component</th><th>Location</th><th class="number">Annual kWh</th><th class="number">Cost (USD)</th></tr>
	</thead>
	<tbody id="rows"></tbody>
</table>
<p class="end">End of report.</p>
<script>
(function () {
	var bridge = window.chrome && window.chrome.webview;
	if (!bridge) {
		document.getElementById("bridge").textContent = "Bridge: window.chrome.webview is missing";
		return;
	}

	bridge.addEventListener("message", function (event) {
		var message = JSON.parse(event.data);
		if (message.type !== "fill") {
			return;
		}

		document.getElementById("title").textContent = message.title;
		document.getElementById("bridge").textContent = "Bridge: values received from " + message.host;

		var body = document.getElementById("rows");
		message.rows.forEach(function (row, index) {
			var tr = document.createElement("tr");
			[String(index + 1), row.component, row.location, row.kwh.toFixed(1), row.cost.toFixed(2)].forEach(function (value, column) {
				var td = document.createElement("td");
				if (column >= 3) { td.className = "number"; }
				td.textContent = value;
				tr.appendChild(td);
			});
			body.appendChild(tr);
		});

		bridge.postMessage(JSON.stringify({ type: "filled", rows: message.rows.length, height: document.documentElement.scrollHeight }));
	});

	bridge.postMessage(JSON.stringify({ type: "ready", engine: navigator.userAgent }));
})();
</script>
</body>
</html>';
	}

	/** The `fill` message the host sends once the page reports `ready`. **/
	public static function fillMessage(host:String):String
	{
		var components = ["Wall", "Ceiling", "Slab", "Window", "Door", "Duct", "Water heater", "Furnace", "Heat pump", "Lighting"];
		var locations = ["Conditioned", "Attic", "Crawlspace", "Garage", "Exterior"];
		var rows = [];

		for (index in 0...ROW_COUNT)
		{
			rows.push({
				component: components[index % components.length] + " " + (Std.int(index / components.length) + 1),
				location: locations[index % locations.length],
				kwh: 120.5 + index * 37.25,
				cost: 14.75 + index * 4.6
			});
		}

		return Json.stringify({
			type: "fill",
			title: "Annual energy summary",
			host: host,
			rows: rows
		});
	}
}
