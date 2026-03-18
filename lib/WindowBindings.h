#pragma once

#include <hxcpp.h>

namespace stagewebview {

class HxcppWindowBindings
{
public:
	static void *getWindowHandle(String name);
	static void *createChildWindow(void *windowHandle, int x, int y, int width, int height);
	static void showWindow(void *handle);
	static void hideWindow(void *handle);
	static void destroyWindow(void *handle);
	static void moveWindow(void *handle, int x, int y, int width, int height);
	static void setFocus(void *handle);
	static String getHandleKey(void *handle);
};

} // namespace stagewebview
