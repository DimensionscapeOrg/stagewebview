#!/usr/bin/env bash
# Installs the exact lib.haxe.org releases the rem client pins into a project-local haxelib repository.
set -euo pipefail

haxelib newrepo
haxelib install hxcpp 4.3.2 --always --quiet
haxelib install lime 8.3.2 --always --quiet
haxelib install openfl 9.5.2 --always --quiet
haxelib list
