# Compatibility reference

No user reference files were present in the initial workspace. The public faux123 v1.1.8 ZIP was downloaded from the [release](https://github.com/faux123/panvk-faux123-driver-ace/releases/tag/v1.1.8). It is a compatibility input and is excluded from the output and Git tracking.

The ZIP has two root members, `libvulkan_panfrost.so` and `meta.json`. Metadata keys are `schemaVersion` (1), `name`, `description`, `author`, `packageVersion`, `vendor`, `driverVersion`, `minApi` (29) and `libraryName`. The library is 26,333,336 bytes, ELF64 little-endian AArch64 ET_DYN, with SONAME `libvulkan_panfrost.so`. It exports `HMI`, `vk_icdGetInstanceProcAddr`, `vk_icdGetPhysicalDeviceProcAddr` and `vk_icdNegotiateLoaderICDInterfaceVersion`. Its runtime dependencies are `liblog.so`, `libnativewindow.so`, `libsync.so`, `libm.so`, `libz.so`, `libdl.so` and `libc.so`. The Android note reports API 29 with NDK r27d build 13750724. The load segments have 4 KiB alignment. It has a regular symbol table and some DWARF sections. The GNU build ID is `22e2bb613cb865343916c9e15589db17040d19f6`.

| File | SHA-256 |
| --- | --- |
| ZIP | `1898e89be6256e67762876fe249e9017717f8643cc5fb6194cf11195fe6da6c8` |
| Library | `499e3eae32a27340777cb890aac92468c2519d57223bfad93a2e2a8f71029728` |

At Peanuts tag `v0.1.8-1` (commit `6eb10e52955e8094d7b47a8dd2baba91b656f46d`), `DriverZip.java` flattens entries, limits count and size, and checks that `libraryName` is a basename and resolves to a file. `name` supplies the sanitized install folder. `GpuDriver.java` displays the driver version and vendor. Native code uses `libnxadreno.so` to load the Android Vulkan loader with the custom driver from app-private storage. The app resolves `vkGetInstanceProcAddr` from the loader. The ICD supplies the Android HAL and ICD entry points listed above. [Pinned Peanuts source](https://github.com/igawa6/peanuts-native/tree/6eb10e52955e8094d7b47a8dd2baba91b656f46d)
