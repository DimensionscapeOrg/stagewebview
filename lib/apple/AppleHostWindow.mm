// macOS and iOS child-window plumbing for the OpenFL facade. Compiled with ARC.
//
// Parent handles are the SDL window (NSWindow found by title on macOS, the key UIWindow on iOS).
// Child handles are plain container views added on top of SDL's view; the webview fills its container.
// Coordinates arrive in points with a top-left origin; on macOS they are flipped into AppKit's
// bottom-left space against the parent view's height.
#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
typedef UIView PlatformView;
#else
#import <Cocoa/Cocoa.h>
typedef NSView PlatformView;
#endif

#include <cstdio>
#include <string>

#include "../WindowBackend.h"

namespace stagewebview {

namespace {

static PlatformView *rootViewOf(id window)
{
	#if TARGET_OS_IPHONE
	UIWindow *uiWindow = window;
	return uiWindow.rootViewController.view != nil ? uiWindow.rootViewController.view : uiWindow;
	#else
	return ((NSWindow *)window).contentView;
	#endif
}

static CGRect frameIn(PlatformView *parent, int x, int y, int width, int height)
{
	#if TARGET_OS_IPHONE
	(void)parent;
	return CGRectMake(x, y, width, height);
	#else
	CGFloat flippedY = parent.isFlipped ? y : parent.bounds.size.height - y - height;
	return NSMakeRect(x, flippedY, width, height);
	#endif
}

static bool isWindow(id object)
{
	#if TARGET_OS_IPHONE
	return [object isKindOfClass:[UIWindow class]];
	#else
	return [object isKindOfClass:[NSWindow class]];
	#endif
}

} // namespace

void *windowGetHandle(const char *name)
{
	#if TARGET_OS_IPHONE
	(void)name;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
	{
		if ([scene isKindOfClass:[UIWindowScene class]])
		{
			for (UIWindow *window in ((UIWindowScene *)scene).windows)
			{
				if (window.isKeyWindow)
				{
					return (__bridge void *)window;
				}
			}
		}
	}

	return (__bridge void *)UIApplication.sharedApplication.windows.firstObject;
	#else
	if (name == nullptr)
	{
		return nullptr;
	}

	NSString *title = [NSString stringWithUTF8String:name];
	for (NSWindow *window in NSApplication.sharedApplication.windows)
	{
		if ([window.title isEqualToString:title])
		{
			return (__bridge void *)window;
		}
	}

	return nullptr;
	#endif
}

void *windowFromAddress(int high, int low)
{
	return windowAddress(high, low);
}

void *windowCreateChildWindow(void *parentHandle, int x, int y, int width, int height)
{
	id parent = (__bridge id)parentHandle;
	if (parent == nil || !isWindow(parent))
	{
		return nullptr;
	}

	PlatformView *root = rootViewOf(parent);
	PlatformView *container = [[PlatformView alloc] initWithFrame:frameIn(root, x, y, width, height)];
	container.hidden = YES;
	[root addSubview:container];

	// The facade owns the container until windowDestroy releases it.
	return (__bridge_retained void *)container;
}

void windowShow(void *handle)
{
	id object = (__bridge id)handle;
	if (object != nil && !isWindow(object))
	{
		((PlatformView *)object).hidden = NO;
	}
}

void windowHide(void *handle)
{
	id object = (__bridge id)handle;
	if (object != nil && !isWindow(object))
	{
		((PlatformView *)object).hidden = YES;
	}
}

void windowDestroy(void *handle)
{
	if (handle == nullptr)
	{
		return;
	}

	id object = (__bridge id)handle;
	if (isWindow(object))
	{
		return;
	}

	PlatformView *container = (__bridge_transfer PlatformView *)handle;
	[container removeFromSuperview];
}

void windowMove(void *handle, int x, int y, int width, int height)
{
	id object = (__bridge id)handle;
	if (object == nil || isWindow(object))
	{
		return;
	}

	PlatformView *container = object;
	PlatformView *parent = container.superview;
	if (width < 0 || height < 0)
	{
		width = static_cast<int>(container.frame.size.width);
		height = static_cast<int>(container.frame.size.height);
	}

	container.frame = frameIn(parent, x, y, width, height);
}

void windowSetFocus(void *handle)
{
	id object = (__bridge id)handle;
	if (object == nil)
	{
		return;
	}

	#if TARGET_OS_IPHONE
	if (isWindow(object))
	{
		[rootViewOf(object) becomeFirstResponder];
	}
	#else
	if (isWindow(object))
	{
		// Hand keyboard focus back to SDL's view.
		NSWindow *window = object;
		[window makeFirstResponder:window.contentView];
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
