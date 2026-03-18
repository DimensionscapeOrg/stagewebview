#pragma once

#include <string>
#include <Windows.h>

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
