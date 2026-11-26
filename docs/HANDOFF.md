# Codespace handoff

The current test candidate is **PanVK G615 Alpha 05**. Its native-buffer investigation, source changes, and test procedure are in [Alpha 05 WSI](alpha05-wsi.md). Alpha 04 failed on the Infinix GT 30 Pro with `VK_ERROR_INVALID_EXTERNAL_HANDLE` during Android swapchain creation. Alpha 05 passed Codespaces build and package checks. Its phone result is pending.

## Get the exact packages

Open a new Codespace from `main` in `JohnLuis07/driver-test`. From the repository root, download the Alpha 05 release assets and verify both driver builds:

```bash
gh release download panvk-g615-alpha05 --repo JohnLuis07/driver-test --dir dist
(cd dist && sha256sum -c PanVK_G615_Alpha_05.SHA256SUMS)
(cd dist && sha256sum -c PanVK_G615_Alpha_05_Diagnostic.SHA256SUMS)
```

The [Alpha 05 prerelease](https://github.com/JohnLuis07/driver-test/releases/tag/panvk-g615-alpha05) includes the install ZIP, diagnostic ZIP and symbols, patched Mesa source, notices, patch, build verification, and smoke tests. Earlier packages are available from [GitHub releases](https://github.com/JohnLuis07/driver-test/releases).

## Rebuild

```bash
./scripts/setup.sh --install-system
./scripts/build.sh
./scripts/package.sh
./scripts/check-mtk-layout.py
./scripts/build.sh --diagnostic
./scripts/package.sh --diagnostic
```

The scripts fetch pinned inputs and generate the build tree. Unstripped libraries and compiler logs are generated locally under `build/`. See [BUILD.md](../BUILD.md) for toolchain details.

## Capture the phone result

ADB runs on a computer connected to the phone over USB. Install Alpha 05 in Peanuts Native, select it for the game, and confirm the driver info includes `Alpha 05`. Run the following on the USB-connected computer and launch the game. Stop the capture after the first complete swapchain attempt.

```bash
adb devices
adb logcat -v threadtime -s MESA Vulkan vulkan AndroidRuntime > alpha05-logcat.txt
```

If the filtered capture misses the Peanuts error, capture again with `adb logcat -v threadtime` and retain the nearby driver messages. Review the log before sharing and keep device logs out of Git. The important lines contain `PANVK-WSI05`, `PANVK-GRALLOC`, `PANVK-DMABUF`, `PANVK-IMPORT`, `PANVK-PRESENT`, or `vkCreateSwapchainKHR`. Report whether the game visibly renders. A new Codespace by itself has no USB access to the phone.
