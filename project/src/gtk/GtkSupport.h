#pragma once

namespace stagewebview {
namespace gtk {

// Initializes GTK once per process. Prefers the X11 backend so webviews can be embedded into the
// X11 window SDL creates (Lime's SDL build has no Wayland driver, so it runs on XWayland under Wayland).
// GDK_BACKEND, when set, still wins.
bool ensureInitialized();

// GDK takes any X error it does not expect as fatal. While this lasts it does not, and what GTK has queued goes out before
// the host's window does, on a connection of the host's own: the requests would otherwise name a window that died with it.
class WindowErrorTrap
{
public:
	WindowErrorTrap();
	~WindowErrorTrap();
};

} // namespace gtk
} // namespace stagewebview
