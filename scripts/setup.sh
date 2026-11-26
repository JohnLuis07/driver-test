#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
source scripts/versions.sh

if [[ ${1:-} == --install-system ]]; then
    sudo apt-get update
    mapfile -t packages < scripts/ubuntu-noble.lock
    sudo apt-get install -y "${packages[@]}"
elif [[ $# != 0 ]]; then
    echo "Usage: $0 [--install-system]" >&2
    exit 2
fi

if [[ ! -x build/venv/bin/meson ]]; then
    python3 -m venv build/venv
fi
build/venv/bin/pip --cache-dir build/pip-cache install -r scripts/requirements.txt

checkout() {
    local dir=$1 url=$2 commit=$3
    if [[ ! -d $dir/.git ]]; then git init "$dir"; fi
    if ! git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null; then
        git -C "$dir" fetch --depth=1 "$url" "$commit"
    fi
    if [[ $(git -C "$dir" rev-parse HEAD 2>/dev/null || true) != "$commit" ]]; then
        git -C "$dir" checkout --detach "$commit"
    fi
}
checkout build/kbase https://github.com/zenithblue-oss/panvk-kbase-android.git "$KBASE_COMMIT"
checkout build/mesa https://gitlab.freedesktop.org/mesa/mesa.git "$MESA_COMMIT"

if [[ ! -s build/android-ndk.zip ]]; then
    curl --fail --location --retry 2 -o build/android-ndk.zip.part \
        "https://dl.google.com/android/repository/android-ndk-$NDK_RELEASE-linux.zip"
    mv build/android-ndk.zip.part build/android-ndk.zip
fi
printf '%s  %s\n' "$NDK_SHA256" build/android-ndk.zip | sha256sum --check
if [[ ! -x build/android-ndk-$NDK_RELEASE/toolchains/llvm/prebuilt/linux-x86_64/bin/clang ]]; then
    unzip -oq build/android-ndk.zip -d build
fi

drm_wrap=build/mesa/subprojects/libdrm.wrap
drm_name=$(sed -n 's/^source_filename = //p' "$drm_wrap")
drm_url=$(sed -n 's/^source_url = //p' "$drm_wrap")
drm_sum=$(sed -n 's/^source_hash = //p' "$drm_wrap")
drm_archive="build/mesa/subprojects/packagecache/$drm_name"
if [[ ! -s $drm_archive ]]; then
    mkdir -p "$(dirname "$drm_archive")"
    curl --fail --location --retry 2 -o "$drm_archive.part" "$drm_url"
    mv "$drm_archive.part" "$drm_archive"
fi
printf '%s  %s\n' "$drm_sum" "$drm_archive" | sha256sum --check
