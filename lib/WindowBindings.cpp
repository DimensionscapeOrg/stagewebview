#include <climits>
#include <hxcpp.h>
#include "WindowBackend.h"
#include "WindowBindings.h"

namespace stagewebview {

void *HxcppWindowBindings::getWindowHandle(String name)
{
	return windowGetHandle(name.c_str());
}

void *HxcppWindowBindings::createChildWindow(void *windowHandle, int x, int y, int width, int height)
{
	return windowCreateChildWindow(windowHandle, x, y, width, height);
}

void HxcppWindowBindings::showWindow(void *handle)
{
	windowShow(handle);
}

void HxcppWindowBindings::hideWindow(void *handle)
{
	windowHide(handle);
}

void HxcppWindowBindings::destroyWindow(void *handle)
{
	windowDestroy(handle);
}

void HxcppWindowBindings::moveWindow(void *handle, int x, int y, int width, int height)
{
	windowMove(handle, x, y, width, height);
}

void HxcppWindowBindings::setFocus(void *handle)
{
	windowSetFocus(handle);
}

String HxcppWindowBindings::getHandleKey(void *handle)
{
	return String(windowGetHandleKey(handle).c_str());
}

} // namespace stagewebview
