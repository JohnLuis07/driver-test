# Alpha 04 Android native-buffer import

The device passed guest placed-memory, GPU timeline and pipeline prewarm checks and reported `vkCreateSwapchainKHR 1224x2720 format 37: -1000072003`. Peanuts returns from its present path before acquisition when that call fails. This places the observed failure before presentation. The supplied excerpt lacks a driver-side mapper, import, or allocation line, so it cannot identify the exact failing Android function.

## Call paths

| Path or function | Where the error can originate |
| --- | --- |
| Android HAL swapchain | Android's Vulkan loader allocates native window buffers and uses `VK_ANDROID_native_buffer`. The driver-managed CPU swapchain is a different entry path. [AOSP implementation guide](https://source.android.com/docs/core/graphics/implement-vulkan) |
| `panvk_android_create_gralloc_image` or deferred `panvk_android_get_wsi_memory` | `vk_android_get_anb_layout_fd` can reject a missing or malformed native handle. `vk_gralloc_to_drm_explicit_layout` can reject mapper failure, plane count, a disjoint layout, or an invalid selected FD. Without a usable mapper Alpha 03 could fail here before the FD was queried. |
| `panvk_android_anb_init` | `panvk_image_init` consumes modifier, plane offset and row/array stride. An unsupported modifier or an incompatible layout is rejected. |
| `vk_android_import_anb_memory_fd` | `vkGetMemoryFdPropertiesKHR` can return invalid external handle if kbase rejects DMA-BUF import. The helper also rejects incompatible memory types. It duplicates the borrowed FD and closes the duplicate on failed allocation. Successful Vulkan allocation consumes it. |
| `panvk_AllocateMemory` and image binding | The DMA-BUF import path can return invalid external handle on BO import. VA mapping and allocation may produce other errors. Deferred bind propagates failures from native image init and import. |
| AHB memory path | Format discovery, missing DMA-BUF, mapper layout, incompatible image/FD memory types, or BO import can fail. This is distinct from the HAL native-buffer path. |
| Mesa ICD staging path | Alpha 03 configures ordinary render images and stages them with a GPU copy before Android CPU presentation. It does not import a vendor DMA-BUF for swapchain creation. The Android loader's HAL path cannot fall back into it after a platform swapchain failure without changing that loader. |

The `RC3-lowmem` identity is shared by these builds. Alpha 03 selected the FD from mapper plane metadata, but it still required metadata first. The BC low-memory code operates on compressed image formats and shadow images. RGBA8 swapchain format 37 does not enter those paths. The current changes leave BO allocation for guest memory, timeline synchronization, push descriptors, and advertised capabilities intact.

## Reference comparison and correction

The faux123 v1.1.8 ELF includes ANB linear/AFBC selection and a layout trace that mentions the usage flags and a linear-request result. Its source for that implementation is private. Binary inspection therefore establishes that it has additional native-buffer handling, while the exact layout and behavior on MT6897 remain unknown. [Faux123 source disclosure](https://github.com/faux123/panvk-faux123-driver-ace#where-the-driver-comes-from)

Public JimVulkan source describes MediaTek buffers with three FDs, the ARM handle marker at data index 21, two observed field arrangements, and a composer plus no-AFBC allocation request. One documented MediaTek variant can have a non-image FD before the image backing FD. Alpha 04 adopts the documented allocation hint for kbase RGBA/BGRA swapchains and keeps mapper metadata authoritative when available. If it fails, the driver validates the known single-plane linear layouts against the native buffer's extent, format, stride and allocation-format fields. It requires exactly one sized FD consistent with the plane. A compressed, protected, ambiguous, or unrecognized handle fails with an error. No private faux123 code or binaries are included. [Pinned public layout evidence](https://github.com/JimVulkan/mali-panvk/blob/58f2c55854bd48b18df756edb11f187af9cd2fde/src/util/u_gralloc/u_gralloc_fallback.c) · [Pinned allocation hints](https://github.com/JimVulkan/mali-panvk/blob/58f2c55854bd48b18df756edb11f187af9cd2fde/src/panfrost/vulkan/panvk_android.c)

The patch also checks detectable import backing size against Vulkan's image-memory requirement. The ICD staging path from Alpha 03 remains available when that WSI is chosen. Logs identify the negotiated native usage, handle FD/integer counts, mapper result, selected FD index and validity, plane layout, image init, memory requirements, allocation, and early acquire/release activity. On the ICD path they include fence and synchronized pixel-readback status.

## Verification and next phone test

Both Android ARM64 builds are produced from the same patches, with a separate DWARF file for the diagnostic build. The host layout fixture exercises both supported structures, FD selection, and rejection of compressed, truncated, undersized-stride, protected and ambiguous inputs. It models documented fields and uses host files for size checks. It does not establish the Infinix handle layout.

Install Alpha 04 as an additional driver and keep the previous selections for rollback. Start the same game once. Record whether swapchain creation passes and whether menus appear. If it fails, return the first lines beginning with `[PANVK-WSI]`, `[PANVK-GRALLOC]`, `[PANVK-DMABUF]`, `[PANVK-IMPORT]` and `[PANVK-PRESENT]`. If visible output starts, continue into gameplay and check for rendering corruption, SIGSEGV and stalls over 30 minutes. Select Alpha 03, Alpha 02, Alpha 01, or faux123 in the per-game driver picker and restart to roll back.
