#pragma once

#include <cstdint>
#include <string>

// Child-window plumbing for the OpenFL facade. WindowBackend.cpp is the Windows implementation;
// gtk/GtkHostWindow.cpp and apple/AppleHostWindow.mm implement the same functions elsewhere.
#if defined(_WIN32)
#include <Windows.h>
#endif

namespace stagewebview {

void *windowGetHandle(const char *name);
void *windowFromAddress(int high, int low);
void *windowCreateChildWindow(void *parentHandle, int x, int y, int width, int height);
void windowShow(void *handle);
void windowHide(void *handle);
void windowDestroy(void *handle);
void windowMove(void *handle, int x, int y, int width, int height);
void windowSetFocus(void *handle);
std::string windowGetHandleKey(void *handle);

// Haxe holds an address as the two halves of an Int64.
inline void *windowAddress(int high, int low)
{
	return reinterpret_cast<void *>(static_cast<uintptr_t>((static_cast<uint64_t>(static_cast<uint32_t>(high)) << 32) | static_cast<uint32_t>(low)));
}

} // namespace stagewebview
