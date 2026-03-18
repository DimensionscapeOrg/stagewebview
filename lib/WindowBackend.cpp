#include <climits>
#include <cstdio>
#include <hxcpp.h>

#include "WindowBackend.h"

namespace stagewebview {

namespace {

LRESULT CALLBACK WebViewWindowProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
	return DefWindowProcW(hwnd, msg, wp, lp);
}

static HINSTANCE moduleHandle()
{
	return GetModuleHandle(nullptr);
}

} // namespace

void *windowGetHandle(const char *name)
{
	return FindWindowA(nullptr, name);
}

void *windowCreateChildWindow(void *parentHandle, int x, int y, int width, int height)
{
	auto parent = reinterpret_cast<HWND>(parentHandle);
	if (parent == nullptr)
	{
		return nullptr;
	}

	CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

	static constexpr LPCWSTR className = L"OpenFLStageWebViewChild";
	WNDCLASSEXW wc{};
	wc.cbSize = sizeof(WNDCLASSEXW);
	wc.lpfnWndProc = WebViewWindowProc;
	wc.hInstance = moduleHandle();
	wc.lpszClassName = className;

	WNDCLASSEXW existing{};
	if (!GetClassInfoExW(moduleHandle(), className, &existing))
	{
		if (!RegisterClassExW(&wc))
		{
			return nullptr;
		}
	}

	return CreateWindowExW(WS_EX_CONTROLPARENT, className, nullptr, WS_CHILD | WS_CLIPCHILDREN, x, y, width, height, parent, nullptr, moduleHandle(),
		nullptr);
}

void windowShow(void *handle)
{
	if (handle != nullptr)
	{
		ShowWindow(reinterpret_cast<HWND>(handle), SW_SHOW);
	}
}

void windowHide(void *handle)
{
	if (handle != nullptr)
	{
		ShowWindow(reinterpret_cast<HWND>(handle), SW_HIDE);
	}
}

void windowDestroy(void *handle)
{
	if (handle != nullptr)
	{
		DestroyWindow(reinterpret_cast<HWND>(handle));
	}
}

void windowMove(void *handle, int x, int y, int width, int height)
{
	if (handle == nullptr)
	{
		return;
	}

	UINT flags = SWP_NOZORDER;
	if (width < 0 || height < 0)
	{
		flags |= SWP_NOSIZE;
	}

	SetWindowPos(reinterpret_cast<HWND>(handle), nullptr, x, y, width, height, flags);
}

void windowSetFocus(void *handle)
{
	if (handle != nullptr)
	{
		SetFocus(reinterpret_cast<HWND>(handle));
	}
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
