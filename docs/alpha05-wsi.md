# Alpha 05 Android 16 swapchain investigation

## Device evidence and source findings

The supplied run reported `VK_ERROR_INVALID_EXTERNAL_HANDLE` on all 1,044 Android swapchain creation attempts. Device creation, placed guest memory, timeline synchronization, shader prewarm and guest execution worked. Peanuts `swap_create` propagates the return from Android's Vulkan loader and returns before acquiring a swapchain image. No Alpha 04 driver-side WSI/import lines were included in the excerpt. The failing internal function on the Infinix is still unknown.

In Android 16 AOSP, `CreateSwapchainKHR` calls `getProducerUsage`. That calls `getProducerUsageGPDIFP2` first and uses the returned `VkAndroidHardwareBufferUsageANDROID` on success. The legacy gralloc callbacks run only if that query is unavailable or fails. Vulkan then configures the `ANativeWindow`, dequeues native buffers and passes them to the driver's `CreateImage`. The loader returns errors from that driver call. Deferred allocation instead binds the native buffer through `BindImageMemory2` on acquisition. [Android 16 loader source](https://android.googlesource.com/platform/frameworks/native/+/android-16.0.0_r1/vulkan/libvulkan/swapchain.cpp)

Alpha 04 only added the uncompressed allocation preference to `GetSwapchainGrallocUsageANDROID` and `GetSwapchainGrallocUsage2ANDROID`. Its successful primary AHB properties query had no corresponding preference. This is a confirmed source gap, although the supplied phone excerpt does not establish which usage path it took. Alpha 05 applies the preference on the primary query for kbase RGBA8/BGRA8 color targets when the loader asks for usage. It checks the exact proposed usage combination with the existing AHB support probe and reports both the preference and the supported usage selected. The hint is excluded for protected images.

The successful-mapper branch had another independent defect. Its plane decoder initialized `fd_index` to zero and incremented only for later planes at offset zero. A single-plane handle with a metadata FD before its DMA-BUF therefore always selected FD 0, even after Alpha 04. The gralloc wire layout supplies plane extent and pitch, but this path has no explicit FD index. Alpha 05 selects the unique allocation-size match, or a unique descriptor large enough for the declared allocation and plane extent. It rejects ambiguity and preserves the mapper's modifier, offset, pitch, layer count and allocation size. The subsequent kbase import still validates the backing object. Unknown raw layouts continue to fail closed. [AOSP metadata encoding](https://android.googlesource.com/platform/frameworks/native/+/fcf7524db0/libs/gralloc/types/Gralloc4.cpp) · [Public MediaTek reference](https://github.com/JimVulkan/mali-panvk/blob/58f2c55854bd48b18df756edb11f187af9cd2fde/src/util/u_gralloc/u_gralloc_fallback.c)

Faux123's original source is unavailable. The public v1.1.8 binary exposes matching HAL/ICD entry points and string/function evidence of additional ANB usage and layout handling. This does not establish its exact MediaTek layouts, synchronization, or fixes. Alpha 05 retains Alpha 02's descriptor bounds, Alpha 03's ICD staging path, and Alpha 04's narrow MTK layout fallback. It changes no Vulkan feature advertisements or guest-buffer, timeline, shader, frame pacing, or rendering behavior. [Faux123 source disclosure](https://github.com/faux123/panvk-faux123-driver-ace#where-the-driver-comes-from)

## Failure paths and ownership

- The window's advertised extent, requested format 37, image usage, transform, image count and FIFO presentation are independent of the guest's 1920×1080 render textures. Peanuts requests RGBA8 transfer destination and color attachment usage and uses the window's dimensions. The patch imposes no landscape extent.
- A native image can fail the gralloc query, modifier/layout initialization, DMA-BUF properties query, compatible memory-type intersection, backing size check, kbase import, VA mapping, or bind. The new markers and existing Alpha 04 errors expose these stages. Kbase's FD properties implementation avoids a transient import, so a positive size/type result is not proof that the actual MEM_IMPORT ioctl will accept the FD.
- The mapper keeps its imported handle only while reading metadata and frees it afterwards. FD selection uses the still-borrowed raw handle, so mapper cleanup cannot close the selected FD. The Vulkan helper duplicates the selected FD for allocation. On failure it closes that duplicate. On success Vulkan consumes the duplicate, and kbase owns its separate BO FD until release. Android retains the original window buffer and FD.
- Acquire and release import/export SYNC_FD payloads using the existing implementation. They run after swapchain creation. The device's timeline result does not exercise the native-window fence path. No fence ownership transfer is changed.
- The ICD staging path records an image-to-buffer copy and host barrier and reads the completed staging buffer before posting to the window. Android's platform loader can bypass this path. The patch retains both paths and tags them separately.

## Changed source

| File | Functions |
| --- | --- |
| `src/vulkan/runtime/vk_android.c` and `vk_android.h` | `vk_android_get_ahb_image_properties_with_usage`, the existing default wrapper, `vk_android_hal_open`, `vk_android_get_anb_layout_fd`, `vk_android_import_anb_memory_fd` |
| `src/panfrost/vulkan/panvk_physical_device.c` | `panvk_GetPhysicalDeviceImageFormatProperties2` |
| `src/util/u_gralloc/u_gralloc_fallback.c` | `panvk_v19_find_plane_fd`, `panvk_v19_decode_planes`, `panvk_v19_query_mapper` |
| `src/panfrost/vulkan/panvk_android.c` | `panvk_android_create_gralloc_image`, `panvk_android_get_wsi_memory` |
| `src/panfrost/vulkan/panvk_wsi.c` | `panvk_wsi_android_create_swapchain` |
| `src/panfrost/lib/kmod/kbase_kmod.c` | DMA-BUF import error logging |
| `src/panfrost/vulkan/panvk_vX_physical_device.c` | Alpha 05 driver identity string |

## Device validation

1. Select Alpha 05 and confirm the driver info includes `Alpha 05`. For the controlled launch, use frame generation, NDSR and FSR off. Keep the previous driver configurations available for rollback.
2. Capture Android **logcat**, since the Peanuts game log may omit the driver library's `MESA` messages. On a connected computer, run `adb logcat -v threadtime | grep -E 'PANVK-(WSI05|WSI|GRALLOC|DMABUF|IMPORT|PRESENT)|vkCreateSwapchainKHR'` during launch. Preserve the first complete attempt. Keep the `driver=Alpha05`, usage selection, route, mapper, FD, import and GPU fence lines.
3. For a standalone WSI test, import the Alpha 05 library extracted from the ZIP into PanProbe and run **swapchain_lifecycle**. This test creates the Android surface, queries the capabilities, draws a colored triangle and presents 300 frames before testing recreation. The bundled JNI library is an ARM64 build of this test and requires PanProbe's Android-Surface harness. PanProbe loads the ICD directly. Use Peanuts for the app's Android HAL path. The marker identifies which route actually ran. [Pinned smoke source](https://github.com/zenithblue-oss/panvk-kbase-android/blob/5b87b74d3e2580d5816e7f2c629f6f016a462f28/apps/panvk-test/app/src/main/cpp/swapchain.c)
4. If the game renders, continue into gameplay and record visible rendering, stalls, corruption or native crashes. If it fails, select faux123 or an earlier Alpha in the per-game picker and restart.

Device execution is pending. The fixture test uses regular host files to validate FD selection and cannot test the Infinix gralloc, kbase ioctls or Android display.
