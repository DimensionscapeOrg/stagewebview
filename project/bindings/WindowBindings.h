#pragma once

// Guarded like hxcpp's generated headers: these are included after hxcpp.h, and GCC cannot reuse the
// precompiled hxcpp.h for a second include.
#ifndef HXCPP_H
#include <hxcpp.h>
#endif

namespace stagewebview {

class HxcppWindowBindings
{
public:
	static void *getWindowHandle(String name);
	static void *fromAddress(int high, int low);
	static void *createChildWindow(void *windowHandle, int x, int y, int width, int height);
	static void showWindow(void *handle);
	static void hideWindow(void *handle);
	static void destroyWindow(void *handle);
	static void moveWindow(void *handle, int x, int y, int width, int height);
	static void setFocus(void *handle);
	static String getHandleKey(void *handle);
};

} // namespace stagewebview
