#include <climits>
#include <hxcpp.h>

#define HL_NAME(n) stagewebview_##n
#include <hl.h>
#undef DEFINE_PRIM
#define DEFINE_HL_PRIM(t, name, args) DEFINE_PRIM_WITH_NAME(t, name, args, name)

#include "WindowBackend.h"

namespace {

struct HL_CFFIPointer
{
	void *finalizer;
	void *ptr;
};

static HL_CFFIPointer *allocPointer(void *ptr)
{
	if (ptr == nullptr)
	{
		return nullptr;
	}

	auto *value = reinterpret_cast<HL_CFFIPointer *>(hl_gc_alloc_finalizer(sizeof(HL_CFFIPointer)));
	value->finalizer = nullptr;
	value->ptr = ptr;
	return value;
}

} // namespace

#define _TCFFIPOINTER _DYN

HL_PRIM HL_CFFIPointer *HL_NAME(hl_window_get_window_handle)(vstring *name)
{
	return allocPointer(stagewebview::windowGetHandle(name != nullptr ? hl_to_utf8(name->bytes) : nullptr));
}

HL_PRIM HL_CFFIPointer *HL_NAME(hl_window_create_child_window)(HL_CFFIPointer *windowHandle, int x, int y, int width, int height)
{
	return allocPointer(stagewebview::windowCreateChildWindow(windowHandle != nullptr ? windowHandle->ptr : nullptr, x, y, width, height));
}

HL_PRIM void HL_NAME(hl_window_show_window)(HL_CFFIPointer *handle)
{
	stagewebview::windowShow(handle != nullptr ? handle->ptr : nullptr);
}

HL_PRIM void HL_NAME(hl_window_hide_window)(HL_CFFIPointer *handle)
{
	stagewebview::windowHide(handle != nullptr ? handle->ptr : nullptr);
}

HL_PRIM void HL_NAME(hl_window_destroy_window)(HL_CFFIPointer *handle)
{
	stagewebview::windowDestroy(handle != nullptr ? handle->ptr : nullptr);
}

HL_PRIM void HL_NAME(hl_window_move_window)(HL_CFFIPointer *handle, int x, int y, int width, int height)
{
	stagewebview::windowMove(handle != nullptr ? handle->ptr : nullptr, x, y, width, height);
}

HL_PRIM void HL_NAME(hl_window_set_focus)(HL_CFFIPointer *handle)
{
	stagewebview::windowSetFocus(handle != nullptr ? handle->ptr : nullptr);
}

HL_PRIM vstring *HL_NAME(hl_window_get_handle_key)(HL_CFFIPointer *handle)
{
	auto key = stagewebview::windowGetHandleKey(handle != nullptr ? handle->ptr : nullptr);
	return key.empty() ? nullptr : reinterpret_cast<vstring *>(hl_alloc_strbytes(USTR("%s"), key.c_str()));
}

DEFINE_HL_PRIM(_TCFFIPOINTER, hl_window_get_window_handle, _STRING);
DEFINE_HL_PRIM(_TCFFIPOINTER, hl_window_create_child_window, _TCFFIPOINTER _I32 _I32 _I32 _I32);
DEFINE_HL_PRIM(_VOID, hl_window_show_window, _TCFFIPOINTER);
DEFINE_HL_PRIM(_VOID, hl_window_hide_window, _TCFFIPOINTER);
DEFINE_HL_PRIM(_VOID, hl_window_destroy_window, _TCFFIPOINTER);
DEFINE_HL_PRIM(_VOID, hl_window_move_window, _TCFFIPOINTER _I32 _I32 _I32 _I32);
DEFINE_HL_PRIM(_VOID, hl_window_set_focus, _TCFFIPOINTER);
DEFINE_HL_PRIM(_STRING, hl_window_get_handle_key, _TCFFIPOINTER);
