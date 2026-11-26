# Alpha 06 kbase presentation synchronization

On the Infinix X6873 running Android 16 build `X6873-16.3.0.160SP02(OP003PF001AZ)`, Peanuts Native 0.1.8 identified the loaded driver as Alpha 05 and passed readiness. In Pokémon Legends: Z-A, mapper picked FD 1 for the 1224×2720 RGBA8 swapchain, reported ARM modifier `0x0800000000000072`, and imported and bound the buffers successfully. Android's `QueueSignalReleaseImageANDROID` then repeatedly failed with one wait semaphore and `VK_ERROR_UNKNOWN` (`-13`). The game reported `vkQueuePresentKHR -13`. The black-screen run repeatedly recreated the swapchain.

The released ELF assigns `vk_drm_syncobj_copy_payloads` to `vk_device.copy_sync_payloads`. The Android HAL release path selects that callback when present. It expects DRM syncobj payloads, while Mali kbase supplies its own sync implementation. Alpha 06 leaves the callback unset for kbase so Mesa uses its existing `QueueSubmit2` path followed by `SYNC_FD` export. This preserves the application's semaphore waits and the compositor's release fence, without a queue-idle wait per frame. [Mesa PanVK device setup](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/323d32bb0030f6253f67cc66b4e850fa144e27a9/src/panfrost/vulkan/panvk_vX_device.c) · [Android native-fence contract](https://source.android.com/docs/core/graphics/implement-vulkan#release-images)

The Alpha 06 Preview phone run successfully submitted and exported release fences. Android's screenshot showed the game character and room, while the phone panel showed a washed-out, blurry image. SurfaceFlinger was handing the compressed game layer to the hardware composer. The [Alpha 07 comparison](alpha07-linear-display.md) tests whether a linear display buffer resolves the panel issue.

## Preview package

`dist/PanVK_G615_Alpha_06_Preview.adpkg.zip` comes from the exact Alpha 05 release ELF. `python3 scripts/package-alpha06-preview.py` verifies the input package digest, clears the callback in each ARM64 device initializer, updates the driver identity and ELF build ID, and checks the two-member package. The adjacent build manifest records the original digest, modified offsets, source patch, and preview build ID. The Ubuntu build applies `patches/alpha06-kbase-present-sync.patch` as part of the patch series. See the [build commands](../BUILD.md).

## Device validation

1. Add the preview ZIP in Peanuts Native and select **PanVK G615 Alpha 06 Preview** for Pokémon Legends: Z-A. Keep the same game build, graphics settings and save used for the Alpha 05 capture.
2. Run the game and check that logcat shows the `Alpha06` HAL marker followed by a `[PANVK-PRESENT]` line with `submit=0` and `export=0`, and that `vkQueuePresentKHR -13` stops. Record whether the menu and gameplay actually appear.
3. If output is visible, replay the same route with a warmed cache. Record flickering, frame-time dips and the thermal state. If output stays black after successful presentation, capture the selected buffer modifier and the first present result for the next investigation.
