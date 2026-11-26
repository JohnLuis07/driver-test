#!/usr/bin/env python3
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / "build/mesa/src/vulkan/runtime/vk_android.c").read_text()
begin = source.index("static bool\nvk_android_mtk_linear_layout(")
end = source.index("\nVkResult\nvk_android_get_anb_layout_fd(", begin)
harness = r"""
#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <vulkan/vulkan_core.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define mesa_logi(...) ((void)0)
#define HAL_PIXEL_FORMAT_RGBA_8888 1
#define HAL_PIXEL_FORMAT_RGBX_8888 2
#define HAL_PIXEL_FORMAT_BGRA_8888 5

typedef struct { int numFds, numInts, data[80]; } native_handle_t;
typedef struct { const native_handle_t *handle; int format, stride; } VkNativeBufferANDROID;
"""
tests = r"""
static int make_fd(off_t size)
{
   char path[] = "/tmp/panvk-layout-XXXXXX";
   int fd = mkstemp(path);
   assert(fd >= 0 && unlink(path) == 0 && ftruncate(fd, size) == 0);
   return fd;
}

int main(void)
{
   native_handle_t handle = { .numFds = 3, .numInts = 62 };
   handle.data[0] = make_fd(4096);
   handle.data[1] = make_fd(128 * 4 * 64);
   handle.data[2] = -1;
   handle.data[21] = 0x03141592;
   const VkNativeBufferANDROID anb = { &handle, HAL_PIXEL_FORMAT_RGBA_8888, 128 };
   VkImageCreateInfo create = {
      .format = VK_FORMAT_R8G8B8A8_UNORM, .arrayLayers = 1, .extent = {117, 63, 1},
   };
   VkSubresourceLayout layout;
   int selected = -1;

   int *fields = &handle.data[21];
   fields[2] = 117;
   fields[3] = 63;
   fields[4] = 1;
   fields[16] = 1;
   fields[21] = 512;
   fields[22] = 128;
   fields[23] = 64;
   assert(vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   assert(selected == handle.data[1] && layout.offset == 0 && layout.rowPitch == 512);

   fields[17] = 0x311;
   assert(!vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   fields[17] = 0;
   fields[21] = 256;
   assert(!vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   fields[21] = 512;
   create.flags = VK_IMAGE_CREATE_PROTECTED_BIT;
   assert(!vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   create.flags = 0;
   handle.numInts = 30;
   assert(!vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   handle.numInts = 62;
   assert(ftruncate(handle.data[0], 128 * 4 * 64) == 0);
   assert(!vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   assert(ftruncate(handle.data[0], 4096) == 0);

   fields[1] = 117;
   fields[2] = 63;
   fields[3] = 1;
   fields[16] = 512;
   fields[17] = 128;
   fields[18] = 64;
   assert(vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));
   assert(selected == handle.data[1] && layout.rowPitch == 512);
   fields[12] = 0x0c410000;
   assert(!vk_android_mtk_linear_layout(&create, &anb, &layout, &selected));

   close(handle.data[0]);
   close(handle.data[1]);
   puts("MTK native-buffer layout fixture checks passed");
}
"""
with tempfile.TemporaryDirectory(prefix="panvk-mtk-layout-") as temp:
    test = Path(temp) / "layout.c"
    exe = Path(temp) / "layout"
    test.write_text(harness + source[begin:end] + tests)
    subprocess.run(
        ["cc", "-std=c11", "-O2", "-I", str(root / "build/mesa/include"),
         str(test), "-o", str(exe)],
        check=True,
    )
    subprocess.run([str(exe)], check=True)
