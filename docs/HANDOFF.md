# Codespace handoff

The current device test candidate is **PanVK G615 Alpha 07 Linear Preview**. Follow the [Alpha 07 test plan](alpha07-linear-display.md) to compare the panel image and buffer layout with Alpha 06. Alpha 05 failed during frame presentation after successfully importing the swapchain buffers. Alpha 04 failed earlier with `VK_ERROR_INVALID_EXTERNAL_HANDLE` during swapchain creation.

## Get the Alpha 05 baseline packages

Open a new Codespace from `main` in `JohnLuis07/driver-test`. The artifacts for Alpha 01 through Alpha 05 are in `dist/`. Git LFS stores the patched source archives and diagnostic symbols. From the repository root, fetch any large files still represented by pointers and verify both Alpha 05 driver builds:

```bash
git lfs pull
(cd dist && sha256sum -c PanVK_G615_Alpha_05.SHA256SUMS)
(cd dist && sha256sum -c PanVK_G615_Alpha_05_Diagnostic.SHA256SUMS)
```

The [Alpha 05 prerelease](https://github.com/JohnLuis07/driver-test/releases/tag/panvk-g615-alpha05) includes the install ZIP, diagnostic ZIP and symbols, patched Mesa source, notices, patch, build verification, and smoke tests. Earlier packages are available from [GitHub releases](https://github.com/JohnLuis07/driver-test/releases).

## Rebuild the current source

```bash
./scripts/setup.sh --install-system
./scripts/build.sh
./scripts/package.sh
./scripts/check-mtk-layout.py
./scripts/build.sh --diagnostic
./scripts/package.sh --diagnostic
```

The scripts fetch pinned inputs and generate the build tree. Unstripped libraries and compiler logs are generated locally under `build/`. See [BUILD.md](../BUILD.md) for toolchain details.

## Capture the Alpha 05 baseline result

ADB runs on a computer connected to the phone over USB. Install Alpha 05 in Peanuts Native, select it for the game, and confirm the driver info includes `Alpha 05`. Run the following on the USB-connected computer and launch the game. Stop the capture after the first complete swapchain attempt.

```bash
adb devices
adb logcat -v threadtime -s MESA Vulkan vulkan AndroidRuntime > alpha05-logcat.txt
```

If the filtered capture misses the Peanuts error, capture again with `adb logcat -v threadtime` and retain the nearby driver messages. Review the log before sharing and keep device logs out of Git. The important lines contain `PANVK-WSI05`, `PANVK-GRALLOC`, `PANVK-DMABUF`, `PANVK-IMPORT`, `PANVK-PRESENT`, or `vkCreateSwapchainKHR`. Report whether the game visibly renders. A new Codespace by itself has no USB access to the phone.
