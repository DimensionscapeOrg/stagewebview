#!/usr/bin/env bash
# Installs the exact lib.haxe.org releases the rem client pins (and utest for the test suites) into a
# project-local haxelib repository.
set -euo pipefail

haxelib newrepo
haxelib install hxcpp 4.3.2 --always --quiet
haxelib install lime 8.3.2 --always --quiet
haxelib install openfl 9.5.2 --always --quiet
haxelib install utest 1.13.2 --always --quiet
# The checkout itself, as consumers install it. Xcode's build phase finds the native build files this way.
haxelib dev StageWebView .
haxelib list
