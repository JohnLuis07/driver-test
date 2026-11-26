#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/versions.sh
export LC_ALL=C TZ=UTC
base=PanVK_G615_Alpha_04
target=build/android
if [[ ${1:-} == --diagnostic && $# == 1 ]]; then
    base=PanVK_G615_Alpha_04_Diagnostic
    target="${PANVK_DIAGNOSTIC_BUILDDIR:-build/android-diagnostic}"
elif [[ $# != 0 ]]; then
    echo "Usage: $0 [--diagnostic]" >&2
    exit 2
fi
lib=libvulkan_panfrost.so
ndk="build/android-ndk-$NDK_RELEASE"
bin="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
so="$target/src/panfrost/vulkan/$lib"
test -s "$so"
mkdir -p build/package dist
stage=$(mktemp -d build/package/stage.XXXXXX)
trap 'find "$stage" -depth -delete' EXIT
mkdir "$stage/install"
DESTDIR="$PWD/$stage/install" build/venv/bin/meson install -C "$target" --no-rebuild
installed=$(find "$stage/install" -name "$lib" -print -quit)
test -s "$installed"
"$bin/llvm-strip" --strip-unneeded -o "$stage/$lib" "$installed"
build/kbase/scripts/validate-binary.sh --abi android "$stage/$lib"

python3 -I - "$stage" "$ANDROID_API" "$MESA_COMMIT" "$KBASE_COMMIT" "$base" <<'PY'
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile

stage, api, mesa, kbase, base = sys.argv[1:]
stage = Path(stage)
library = "libvulkan_panfrost.so"
so = stage / library
data = so.read_bytes()
header = struct.unpack_from("<16sHHIQQQIHHHHHH", data)
assert header[0][:6] == b"\x7fELF\x02\x01"
assert header[1:3] == (3, 183), "expected AArch64 shared ELF"
for i in range(header[10]):
    segment = struct.unpack_from("<IIQQQQQQ", data, header[5] + i * header[9])
    if segment[0] == 1:
        assert segment[-1] >= 16384, "PT_LOAD alignment below 16 KiB"

def readelf(*args):
    return subprocess.check_output(["readelf", *args, "-W", so], text=True)

notes = readelf("-n")
android_note = re.search(r"description data:\s*((?:[0-9a-f]{2}\s+)+)", notes)
assert ".note.android.ident" in notes and android_note
assert int.from_bytes(bytes.fromhex(android_note[1])[:4], "little") == int(api)
build_id = re.search(r"Build ID: ([0-9a-f]+)", notes)[1]
dynamic = readelf("-d")
needed = set(re.findall(r"Shared library: \[([^\]]+)\]", dynamic))
assert "libc.so" in needed
assert needed <= {"libc.so", "libdl.so", "liblog.so", "libm.so",
                  "libnativewindow.so", "libsync.so", "libz.so"}, needed
assert f"Library soname: [{library}]" in dynamic
assert "RPATH" not in dynamic and "RUNPATH" not in dynamic
symbols = {parts[7] for line in readelf("--dyn-syms").splitlines()
           if len(parts := line.split()) >= 8 and parts[6].isdigit()
           and parts[4] in {"GLOBAL", "WEAK"} and parts[5] == "DEFAULT"}
required = {"HMI", "vk_icdGetInstanceProcAddr",
            "vk_icdGetPhysicalDeviceProcAddr", "vk_icdNegotiateLoaderICDInterfaceVersion"}
assert required <= symbols, required - symbols
assert "GLIBC_" not in readelf("--version-info")

meta = {
    "schemaVersion": 1,
    "name": "PanVK G615 Alpha 04",
    "description": "Android arm64 PanVK Android presentation build with validated MediaTek native-buffer layouts.",
    "author": "Mesa and zenithblue-oss contributors",
    "packageVersion": "Alpha04",
    "vendor": "Mesa",
    "driverVersion": "26.3.0-devel",
    "minApi": int(api),
    "libraryName": library,
}
manifest = {
    "mesaCommit": mesa, "kbasePatchCommit": kbase,
    "sha256": hashlib.sha256(data).hexdigest(), "buildId": build_id,
    "localPatchSha256": {
        patch.name: hashlib.sha256(patch.read_bytes()).hexdigest()
        for patch in (Path("patches/alpha02-push-descriptor-slots.patch"),
                      *sorted(Path("patches").glob("alpha0[34]-*.patch")))
    },
    "needed": sorted(needed), "exports": sorted(required),
}
if base.endswith("_Diagnostic"):
    meta["name"] += " Diagnostic"
    meta["packageVersion"] += "-Diagnostic"
    meta["description"] = "Alpha 04 stability build with separately retained debug symbols."

with zipfile.ZipFile(stage / "driver.zip", "w", zipfile.ZIP_DEFLATED) as out:
    for name, contents in {
        library: data,
        "meta.json": (json.dumps(meta, indent=2) + "\n").encode(),
    }.items():
        entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
        entry.external_attr = 0o100644 << 16
        out.writestr(entry, contents, compress_type=zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(stage / "driver.zip") as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {library, "meta.json"}
    assert json.loads(archive.read("meta.json")) == meta
    assert archive.read(meta["libraryName"]) == data
(stage / "BUILD-INFO.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
PY

if [[ $base == *_Diagnostic ]]; then
    "$bin/llvm-objcopy" --only-keep-debug "$installed" "$stage/$lib.debug"
    readelf -SW "$stage/$lib.debug" > "$stage/sections.txt"
    grep -q '\.debug_line' "$stage/sections.txt"
    debug_id=$(readelf -nW "$stage/$lib.debug" | awk '/Build ID:/ {print $3}')
    packaged_id=$(readelf -nW "$stage/$lib" | awk '/Build ID:/ {print $3}')
    [[ -n $debug_id && $debug_id == "$packaged_id" ]]
    gzip -n "$stage/$lib.debug"
    mv "$stage/$lib.debug.gz" "dist/$base.so.debug.gz"
    mv "$stage/driver.zip" "dist/$base.adpkg.zip"
    mv "$stage/BUILD-INFO.json" "dist/$base.build.json"
    (
        cd dist
        sha256sum "$base".{adpkg.zip,build.json,so.debug.gz} > "$base.SHA256SUMS"
        sha256sum -c "$base.SHA256SUMS"
    )
    exit
fi

# Preserve per-file copyright and license notices in the exact patched source.
epoch=$(git -C build/mesa show -s --format=%ct "$MESA_COMMIT")
(
    cd build/mesa
    {
        git ls-files -z --cached --others --exclude-standard
        drm_name=$(sed -n 's/^source_filename = //p' subprojects/libdrm.wrap)
        printf '%s\0' "subprojects/packagecache/$drm_name"
    } |
        sort -zu |
        tar --mtime="@$epoch" --owner=0 --group=0 \
            --numeric-owner --null -T - -cf -
) | gzip -n > "$stage/patched-mesa.tar.gz"

mkdir -p "$stage/notices"
cp -r build/kbase/LICENSES build/kbase/NOTICE.md "$stage/notices/"
cp "$ndk/NOTICE" "$ndk/NOTICE.toolchain" "$stage/notices/"
cp "$stage/BUILD-INFO.json" "$stage/notices/"
tar -C "$stage/notices" --sort=name --mtime="@$epoch" --owner=0 --group=0 \
    --numeric-owner -cf - . | gzip -n > "$stage/notices.tar.gz"
gzip -t "$stage/patched-mesa.tar.gz" "$stage/notices.tar.gz"
tar -tzf "$stage/patched-mesa.tar.gz" > "$stage/source-files.txt"
grep -qx 'src/panfrost/lib/kmod/kbase_kmod.c' "$stage/source-files.txt"
grep -qx 'src/panfrost/lib/kmod/kbase_csf_uapi.h' "$stage/source-files.txt"
for pair in "driver.zip:$base.adpkg.zip" "BUILD-INFO.json:$base.build.json" \
    "patched-mesa.tar.gz:$base.source.tar.gz" "notices.tar.gz:$base.notices.tar.gz"; do
    mv "$stage/${pair%%:*}" "dist/${pair#*:}"
done
(cd dist && sha256sum "$base".{adpkg.zip,build.json,source.tar.gz,notices.tar.gz} > "$base.SHA256SUMS" && sha256sum -c "$base.SHA256SUMS")
