#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/versions.sh
work=build/alpha05-smoke
tests=build/kbase/tests
ndk=build/android-ndk-$NDK_RELEASE
cc="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android$ANDROID_API-clang"
app=build/kbase/apps/panvk-test/app/src/main/cpp
mkdir -p "$work" dist
"$ndk/shader-tools/linux-x86_64/glslc" "$tests/features/texture.comp" -o "$work/texture.comp.spv"
python3 - "$work" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
shader = (root / "texture.comp.spv").read_bytes()
(root / "texture.comp.spv.h").write_text(
    "_Alignas(4) static const unsigned char texture_comp_spv[] = {"
    + ",".join(map(str, shader))
    + "};\nstatic const unsigned texture_comp_spv_len = sizeof(texture_comp_spv);\n"
)
PY
flags=(-O2 -Ibuild/mesa/include -I"$work")
"$cc" "${flags[@]}" "$tests/offscreen/triangle.c" -ldl -o "$work/triangle"
"$cc" "${flags[@]}" "$tests/dxvk/vulkan/depth-stencil/depth_stencil.c" -lm -ldl -o "$work/depth-stencil"
"$cc" "${flags[@]}" "$tests/features/texture-features.c" -lm -ldl -o "$work/texture-features"
"$cc" "${flags[@]}" "$tests/ahb/fdimport.c" -ldl -o "$work/fdimport"
"$cc" "${flags[@]}" -shared -I"$tests/dxvk/vulkan/clip-cull" "$app/swapchain.c" \
    -landroid -llog -ldl -o "$work/libpanprobe-swapchain.so"
python3 - "$work" <<'PY'
from pathlib import Path
import sys
from zipfile import ZipFile, ZIP_DEFLATED

work = Path(sys.argv[1])
with ZipFile("dist/PanVK_G615_Alpha_05_WSI_smoke.zip", "w", ZIP_DEFLATED) as out:
    for name in ("triangle", "depth-stencil", "texture-features", "fdimport",
                 "libpanprobe-swapchain.so"):
        binary = work / name
        assert binary.read_bytes()[:6] == b"\x7fELF\x02\x01"
        assert int.from_bytes(binary.read_bytes()[18:20], "little") == 183
        out.write(binary, name)
    out.write("docs/alpha05-wsi.md", "TESTING.md")
    out.write("build/kbase/LICENSES/MIT.txt", "LICENSE.txt")
PY
