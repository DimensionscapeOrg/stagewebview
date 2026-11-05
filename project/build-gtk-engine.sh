#!/bin/sh
# Builds stagewebview-gtk.so for this machine, the engine for frameworks that cannot link WebKitGTK: see include/stagewebview/Engine.h.
# Needs pkg-config, libgtk-3-dev and libwebkit2gtk-4.1-dev. Build on the oldest system it should run on.
set -e
cd "$(dirname "$0")"

case "$(uname -m)" in
	x86_64) folder=Linux64 ;;
	aarch64) folder=LinuxArm64 ;;
	*) echo "No ndll folder for $(uname -m)" >&2; exit 1 ;;
esac

library=../ndll/$folder/stagewebview-gtk.so
mkdir -p "../ndll/$folder"

# shellcheck disable=SC2046
${CXX:-g++} -std=c++14 -O2 -fPIC -shared -fvisibility=hidden -fvisibility-inlines-hidden -static-libstdc++ -static-libgcc \
	-Iinclude -Wl,--no-undefined -Wl,--as-needed -Wl,--version-script=src/gtk/GtkEngine.map -o "$library" \
	src/WebViewBackendPlatform.cpp src/gtk/GtkWebView.cpp src/gtk/GtkHostWindow.cpp src/gtk/GtkEngine.cpp \
	$(pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.1 x11)

strip --strip-unneeded "$library"
