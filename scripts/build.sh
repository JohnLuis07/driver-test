#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/versions.sh
root=$PWD
mesa="$root/build/mesa"
kbase="$root/build/kbase"
ndk="$root/build/android-ndk-$NDK_RELEASE/toolchains/llvm/prebuilt/linux-x86_64"
host="$root/build/host"
target="$root/build/android"
debug=false
if [[ ${1:-} == --diagnostic && $# == 1 ]]; then
    target="${PANVK_DIAGNOSTIC_BUILDDIR:-$root/build/android-diagnostic}"
    debug=true
elif [[ $# != 0 ]]; then
    echo "Usage: $0 [--diagnostic]" >&2
    exit 2
fi
jobs=${JOBS:-$(nproc)}
export PATH="$root/build/venv/bin:/usr/lib/llvm-18/bin:$PATH"
export LC_ALL=C TZ=UTC
export SOURCE_DATE_EPOCH=$(git -C "$mesa" show -s --format=%ct "$MESA_COMMIT")

[[ $(git -C "$mesa" rev-parse HEAD) == "$MESA_COMMIT" ]]
[[ $(git -C "$kbase" rev-parse HEAD) == "$KBASE_COMMIT" ]]
if [[ ! -f build/patch.complete ]]; then
    if [[ -n $(git -C "$mesa" status --porcelain) ]]; then
        echo "Mesa checkout has changes. Use a clean checkout before applying the baseline series." >&2
        exit 1
    fi
    "$kbase/scripts/apply-patches.sh" --profile "$PROFILE" --mesa "$mesa" > build/patch.log 2>&1
    touch build/patch.complete
fi
for patch in "$root"/patches/alpha02-*.patch; do
    if git -C "$mesa" apply --check "$patch" 2>/dev/null; then
        git -C "$mesa" apply "$patch"
    else
        git -C "$mesa" apply --reverse --check "$patch"
    fi
done

common=(-Dbuildtype=release -Dgallium-drivers= -Dvulkan-drivers=panfrost
        -Dpanfrost-kmds=kbase -Dglx=disabled -Degl=disabled -Dgbm=disabled
        -Dopengl=false -Dgles1=disabled -Dgles2=disabled -Dzstd=disabled)
if [[ ! -f $host/build.ninja ]]; then
    meson setup "$host" "$mesa" "${common[@]}" -Dplatforms= \
        -Dmesa-clc=enabled -Dinstall-mesa-clc=true -Dprecomp-compiler=enabled \
        -Dinstall-precomp-compiler=true -Dllvm=enabled
fi
ninja -j "$jobs" -C "$host" src/compiler/clc/mesa_clc \
    src/compiler/spirv/vtn_bindgen2 src/panfrost/clc/panfrost_compile
export PATH="$host/src/compiler/clc:$host/src/compiler/spirv:$host/src/panfrost/clc:$PATH"

mkdir -p build/android-pc
cat > build/android-pc/zlib.pc <<'PC'
Name: zlib
Description: Android NDK system zlib
Version: 1.3.1
Libs: -lz
PC
cat > build/android.ini <<CROSS
[binaries]
c = '$ndk/bin/aarch64-linux-android$ANDROID_API-clang'
cpp = '$ndk/bin/aarch64-linux-android$ANDROID_API-clang++'
ar = '$ndk/bin/llvm-ar'
strip = '$ndk/bin/llvm-strip'
pkg-config = '/usr/bin/pkg-config'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[properties]
pkg_config_libdir = ['$root/build/android-pc']
CROSS
if [[ ! -f $target/build.ninja ]]; then
    PKG_CONFIG_PATH= meson setup "$target" "$mesa" --cross-file build/android.ini \
        --wrap-mode=nodownload "${common[@]}" -Ddebug="$debug" -Dplatforms=android \
        -Dallow-fallback-for=libdrm -Dlibdrm:default_library=static \
        -Dlibdrm:auto_features=disabled -Dlibdrm:tests=false \
        -Dandroid-stub=true -Dandroid-strict=false -Dllvm=disabled \
        -Dmesa-clc=system -Dprecomp-compiler=system -Dxlib-lease=disabled \
        -Dlibunwind=disabled -Dzlib=enabled -Dcpp_link_args=-static-libstdc++
fi
ninja -j "$jobs" -C "$target"
