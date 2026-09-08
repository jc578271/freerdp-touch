#!/bin/bash
# Regression: the applied quilt patch must call the monitor-scale helper.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dsc="$root/src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc"
patch="$root/patches/onemix-touch.patch"
td=$(mktemp -d "${TMPDIR:-/tmp}/patch-application.XXXXXX")
trap 'rm -rf "$td"' EXIT HUP INT TERM

[ -r "$dsc" ] || { printf 'FAIL: missing source package: %s\n' "$dsc" >&2; exit 1; }
[ -r "$patch" ] || { printf 'FAIL: missing patch: %s\n' "$patch" >&2; exit 1; }

dpkg-source -x "$dsc" "$td/src" >/dev/null 2>&1
cp "$patch" "$td/src/debian/patches/onemix-touch.patch"
printf 'onemix-touch.patch\n' >> "$td/src/debian/patches/series"
(
	cd "$td/src"
	export QUILT_PATCHES=debian/patches
	quilt push -a >/dev/null
)

monitor="$td/src/client/X11/xf_monitor.c"
occurrences=$(grep -Fc 'xf_monitor_apply_scale_attributes(' "$monitor")
if [ "$occurrences" -ne 2 ]; then
	printf 'FAIL: expected helper definition and production call, got %s occurrences\n' "$occurrences" >&2
	exit 1
fi

call_line=$(grep -nF 'if (!xf_monitor_apply_scale_attributes(' "$monitor" | cut -d: -f1)
store_line=$(grep -nF 'freerdp_settings_set_monitor_def_array_sorted' "$monitor" | cut -d: -f1)
if [ -z "$call_line" ] || [ -z "$store_line" ] || [ "$call_line" -ge "$store_line" ]; then
	printf 'FAIL: scale helper must run before monitor-array storage\n' >&2
	exit 1
fi

printf 'PASS: applied monitor-scale helper invocation verified\n'
