#pragma once

namespace stagewebview {

// Focuses the first or last element of the page that takes the focus, for assignFocus with a direction
// (0 for the bottom, as Shift+Tab enters a page, and 2 for the top, as Tab does) where the platform has no
// call that does it. Elements are in document order, and positive tabindex values are not ordered first.
inline const char *focusEdgeScript(bool last)
{
	return last
		? "(function(l){var s='a[href],area[href],button:not([disabled]),input:not([disabled]):not([type=\"hidden\"]),select:not([disabled]),textarea:not([disabled]),iframe,summary,[tabindex]:not([tabindex=\"-1\"]),[contenteditable]:not([contenteditable=\"false\"])';var n=Array.prototype.filter.call(document.querySelectorAll(s),function(e){var r=e.getBoundingClientRect();return r.width>0||r.height>0;});if(n.length)n[l?n.length-1:0].focus();})(true)"
		: "(function(l){var s='a[href],area[href],button:not([disabled]),input:not([disabled]):not([type=\"hidden\"]),select:not([disabled]),textarea:not([disabled]),iframe,summary,[tabindex]:not([tabindex=\"-1\"]),[contenteditable]:not([contenteditable=\"false\"])';var n=Array.prototype.filter.call(document.querySelectorAll(s),function(e){var r=e.getBoundingClientRect();return r.width>0||r.height>0;});if(n.length)n[l?n.length-1:0].focus();})(false)";
}

}
