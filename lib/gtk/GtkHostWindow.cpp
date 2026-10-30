// Linux child-window plumbing for the OpenFL facade.
//
// Parent handles are X11 window ids (SDL's window, found by title). Child handles are GtkWindow pointers:
// an override-redirect GTK popup whose X11 window is reparented into the parent, so the window manager
// leaves it alone and it moves with the host. This needs GDK on X11; under Wayland the same path runs on
// XWayland because Lime's SDL is X11-only. When GDK is not on X11 the child stays a separate popup.
#include <gtk/gtk.h>

#ifdef GDK_WINDOWING_X11
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <gdk/gdkx.h>
#endif

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_set>

#include "../WindowBackend.h"
#include "GtkSupport.h"

namespace stagewebview {

namespace gtk {

bool ensureInitialized()
{
	static int state = 0;
	if (state == 0)
	{
		if (std::getenv("GDK_BACKEND") == nullptr)
		{
			gdk_set_allowed_backends("x11,*");
		}

		state = gtk_init_check(nullptr, nullptr) ? 1 : -1;
	}

	return state == 1;
}

} // namespace gtk

namespace {

static const char *PARENT_KEY = "stagewebview-parent";

#ifdef GDK_WINDOWING_X11
static Display *x11Display()
{
	GdkDisplay *display = gdk_display_get_default();
	return display != nullptr && GDK_IS_X11_DISPLAY(display) ? gdk_x11_display_get_xdisplay(display) : nullptr;
}

static bool windowTitleMatches(Display *display, Window window, Atom netWmName, Atom utf8String, const char *name)
{
	bool matches = false;
	Atom type = None;
	int format = 0;
	unsigned long count = 0;
	unsigned long remaining = 0;
	unsigned char *value = nullptr;

	if (XGetWindowProperty(display, window, netWmName, 0, 1024, False, utf8String, &type, &format, &count, &remaining, &value) == Success
		&& value != nullptr)
	{
		matches = std::strcmp(reinterpret_cast<const char *>(value), name) == 0;
		XFree(value);
		if (matches)
		{
			return true;
		}
	}

	char *legacyName = nullptr;
	if (XFetchName(display, window, &legacyName) && legacyName != nullptr)
	{
		matches = std::strcmp(legacyName, name) == 0;
		XFree(legacyName);
	}

	return matches;
}

static Window findWindowByTitle(Display *display, Window root, Atom netWmName, Atom utf8String, const char *name, int depth)
{
	if (windowTitleMatches(display, root, netWmName, utf8String, name))
	{
		return root;
	}

	if (depth > 4)
	{
		return None;
	}

	Window rootReturn = None;
	Window parentReturn = None;
	Window *children = nullptr;
	unsigned int count = 0;
	Window found = None;

	if (XQueryTree(display, root, &rootReturn, &parentReturn, &children, &count))
	{
		for (unsigned int index = 0; index < count && found == None; index++)
		{
			found = findWindowByTitle(display, children[index], netWmName, utf8String, name, depth + 1);
		}

		if (children != nullptr)
		{
			XFree(children);
		}
	}

	return found;
}

static Window childXid(GtkWidget *window)
{
	GdkWindow *gdkWindow = gtk_widget_get_window(window);
	return gdkWindow != nullptr && GDK_IS_X11_WINDOW(gdkWindow) ? gdk_x11_window_get_xid(gdkWindow) : None;
}
#endif

// Parent handles are X11 ids, not pointers, so a handle is only treated as a GtkWindow when this file created it.
static std::unordered_set<void *> &childWindows()
{
	static std::unordered_set<void *> windows;
	return windows;
}

static GtkWidget *asGtkWindow(void *handle)
{
	return handle != nullptr && childWindows().count(handle) > 0 ? GTK_WIDGET(handle) : nullptr;
}

} // namespace

void *windowGetHandle(const char *name)
{
	#ifdef GDK_WINDOWING_X11
	if (name == nullptr || !gtk::ensureInitialized())
	{
		return nullptr;
	}

	Display *display = x11Display();
	if (display == nullptr)
	{
		return nullptr;
	}

	// SDL renames its window on its own X connection; sync so this connection sees the new title.
	XSync(display, False);
	Atom netWmName = XInternAtom(display, "_NET_WM_NAME", False);
	Atom utf8String = XInternAtom(display, "UTF8_STRING", False);

	for (int attempt = 0; attempt < 20; attempt++)
	{
		Window found = findWindowByTitle(display, DefaultRootWindow(display), netWmName, utf8String, name, 0);
		if (found != None)
		{
			return reinterpret_cast<void *>(static_cast<uintptr_t>(found));
		}

		g_usleep(10000);
		XSync(display, False);
	}
	#else
	(void)name;
	#endif

	return nullptr;
}

void *windowCreateChildWindow(void *parentHandle, int x, int y, int width, int height)
{
	if (parentHandle == nullptr || !gtk::ensureInitialized())
	{
		return nullptr;
	}

	GtkWidget *window = gtk_window_new(GTK_WINDOW_POPUP);
	gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
	gtk_window_set_default_size(GTK_WINDOW(window), width > 0 ? width : 1, height > 0 ? height : 1);
	g_object_set_data(G_OBJECT(window), PARENT_KEY, parentHandle);
	gtk_widget_realize(window);

	#ifdef GDK_WINDOWING_X11
	Display *display = x11Display();
	Window child = childXid(window);
	if (display != nullptr && child != None)
	{
		XReparentWindow(display, child, static_cast<Window>(reinterpret_cast<uintptr_t>(parentHandle)), x, y);
		XFlush(display);
	}
	#else
	(void)x;
	(void)y;
	#endif

	childWindows().insert(window);
	return window;
}

void windowShow(void *handle)
{
	if (GtkWidget *window = asGtkWindow(handle))
	{
		gtk_widget_show_all(window);
	}
}

void windowHide(void *handle)
{
	if (GtkWidget *window = asGtkWindow(handle))
	{
		gtk_widget_hide(window);
	}
}

void windowDestroy(void *handle)
{
	if (GtkWidget *window = asGtkWindow(handle))
	{
		childWindows().erase(handle);
		gtk_widget_destroy(window);
	}
}

void windowMove(void *handle, int x, int y, int width, int height)
{
	GtkWidget *window = asGtkWindow(handle);
	if (window == nullptr)
	{
		return;
	}

	if (width > 0 && height > 0)
	{
		gtk_window_resize(GTK_WINDOW(window), width, height);
	}

	#ifdef GDK_WINDOWING_X11
	Display *display = x11Display();
	Window child = childXid(window);
	if (display != nullptr && child != None)
	{
		// GTK believes the popup is a top-level at the root origin, so position it with Xlib inside the parent.
		if (width > 0 && height > 0)
		{
			XMoveResizeWindow(display, child, x, y, static_cast<unsigned int>(width), static_cast<unsigned int>(height));
		}
		else
		{
			XMoveWindow(display, child, x, y);
		}

		XFlush(display);
		return;
	}
	#endif

	gtk_window_move(GTK_WINDOW(window), x, y);
}

void windowSetFocus(void *handle)
{
	if (handle == nullptr)
	{
		return;
	}

	if (GtkWidget *window = asGtkWindow(handle))
	{
		gtk_window_present(GTK_WINDOW(window));
		return;
	}

	#ifdef GDK_WINDOWING_X11
	// Parent handles are SDL's X11 window: hand keyboard focus back to it.
	if (Display *display = x11Display())
	{
		XSetInputFocus(display, static_cast<Window>(reinterpret_cast<uintptr_t>(handle)), RevertToParent, CurrentTime);
		XFlush(display);
	}
	#endif
}

std::string windowGetHandleKey(void *handle)
{
	if (handle == nullptr)
	{
		return std::string();
	}

	char buffer[32];
	std::snprintf(buffer, sizeof(buffer), "%p", handle);
	return buffer;
}

} // namespace stagewebview
