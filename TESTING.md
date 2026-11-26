# Infinix GT 30 Pro validation

Use Peanuts Native 0.1.8 and the same game update, save, resolution, console mode and graphics settings for every run.

1. Verify the package SHA-256 against `dist/SHA256SUMS`. In Peanuts Native open GPU driver → From a file and select `PanVK-G615-Alpha01.adpkg.zip`. Select the driver for Pokémon Legends: Z-A.
2. Run Readiness check and copy the report. Confirm the report identifies the custom driver. Record `memory.placedUsable`, `memory.placedProbe`, the graphics self-test results and any failure to create a device or swapchain. The supplied self-test results were from stock Mali r44p1.
3. If readiness passes, run the same cutscene, dialogue and battle that reproduced the white scene. Record whether background, geometry and overlays render and the first timestamp of any corruption. Save the app's game log and a short video if reproducible.
4. Repeat the same route with faux123 v1.1.8 and then Alpha 01 with warmed pipeline caches. Record average FPS, 1% low FPS, GPU frame time, and thermal state for each run. Use the same sample duration. A stable 30 FPS requires frame times around 33.3 ms and consistent pacing.
5. If loading, remapping or rendering fails, record the Android build, package SHA-256, app log and logcat lines around the failure. Include `adrenotools`, `hook_impl`, `panvk` and `kbase` messages where present. Kernel or SELinux diagnostics are especially useful if they identify a denied device node or DMA heap.

An unprivileged app must be able to open the GPU and allocate/map a suitable DMA buffer. A shell probe cannot establish app-domain access. Keep the stock selection available to recover after an unsuccessful run.

## Codespaces results

Alpha 01 passed ELF64/AArch64, Android API 29 note, 16 KiB load segment alignment, HAL and ICD export, shared library dependency, metadata, ZIP CRC and SHA-256 checks. The Peanuts Native 0.1.8 `DriverZip` class accepted the finished package in a desktop JVM harness. The ELF build ID is `cf58a336284de4de1dfbc18e17c8beb18bc50efe`. The Infinix runtime loader, kbase ioctls, placed-memory probe, swapchain, rendering and performance still require device testing.
