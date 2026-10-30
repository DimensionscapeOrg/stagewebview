#pragma once

namespace stagewebview {
namespace gtk {

// Initializes GTK once per process. Prefers the X11 backend so webviews can be embedded into the
// X11 window SDL creates (Lime's SDL build has no Wayland driver, so it runs on XWayland under Wayland).
// GDK_BACKEND, when set, still wins.
bool ensureInitialized();

} // namespace gtk
} // namespace stagewebview
