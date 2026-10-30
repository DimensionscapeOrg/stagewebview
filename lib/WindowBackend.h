#pragma once

#include <string>

// Child-window plumbing for the OpenFL facade. WindowBackend.cpp is the Windows implementation;
// gtk/GtkHostWindow.cpp and apple/AppleHostWindow.mm implement the same functions elsewhere.
#if defined(_WIN32)
#include <Windows.h>
#endif

namespace stagewebview {

void *windowGetHandle(const char *name);
void *windowCreateChildWindow(void *parentHandle, int x, int y, int width, int height);
void windowShow(void *handle);
void windowHide(void *handle);
void windowDestroy(void *handle);
void windowMove(void *handle, int x, int y, int width, int height);
void windowSetFocus(void *handle);
std::string windowGetHandleKey(void *handle);

} // namespace stagewebview
