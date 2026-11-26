# Alpha 07 linear display buffer comparison

## Alpha 06 device result

Alpha 06 successfully submitted frames and exported release fences on the Infinix GT 30 Pro. Android captured a clear screenshot of the game, with the character, room and on-screen controls visible. The physical panel showed a washed-out, blurry picture. SurfaceFlinger reported `DEVICE` composition for the game layer and compressed `1224×2720` buffers with usage `0x20000b00` and ARM AFBC modifier `0x0800000000000072`. The same launch reached 30 FPS in a lighter section and about 18 FPS in the room shown by the screen capture.

The buffer size also supports an AFBC layout mismatch as a hypothesis. The reported 4992-byte row pitch implies a padded width of 1248 pixels. With 32×8 superblocks and 16 bytes per header entry, the raw header is 212,160 bytes. Adding the 13,578,240-byte body to that header rounded to 128 bytes gives the driver's reported 13,790,464-byte image requirement. Rounding the header to 1024 bytes gives gralloc's reported 13,791,232-byte allocation. These matching sizes support testing different buffer layouts. They do not measure where the physical display engine read the body. [Arm gralloc allocation code](https://android.googlesource.com/platform/hardware/google/gchips/+/fd4c561/GrallocHAL/src/core/mali_gralloc_bufferallocation.cpp) · [MediaTek display driver discussion](https://lists.openwall.net/linux-kernel/2026/02/02/193)

## Candidate

Alpha 07 adds Android's rare CPU-read and CPU-write usage bits to the existing kbase preference for unprotected RGBA8/BGRA8 color targets queried through Android's primary hardware-buffer path. The driver probes the resulting usage combination before advertising it. The hints ask gralloc for a CPU-accessible allocation while keeping direct GPU rendering, DMA-BUF import and Alpha 06's release fences. The actual modifier remains the one reported by the mapper. [Android buffer usage definitions](https://android.googlesource.com/platform/hardware/interfaces/+/eccb702dab07591c65493e8b7c606c34aaaf2956/graphics/common/aidl/android/hardware/graphics/common/BufferUsage.aidl)

Run `python3 scripts/package-alpha06-preview.py --linear` to generate `dist/PanVK_G615_Alpha_07_Linear_Preview.adpkg.zip` from the verified Alpha 05 release. On Ubuntu, the normal build applies `patches/alpha07-linear-display-buffer.patch` after Alpha 06 and packages the source build as `PanVK_G615_Alpha_07.adpkg.zip`.

## Device validation

1. Select **PanVK G615 Alpha 07 Linear Preview** in Peanuts Native. Restart the game at the same settings and save point as the Alpha 06 run.
2. Confirm the primary query requested `preferred=0x20000822` and inspect the actual modifier in the gralloc logs. A linear buffer has modifier `0x0`. Confirm Android continues to accept release fences.
3. Compare the panel with an Android screenshot. Record washout or flicker and the presented FPS after the scene settles. If the physical image becomes clear, compare frame times at the same save point before changing resolution or other settings.

## Alpha 07 battle result

SurfaceFlinger confirmed modifier `0x0`, usage `0x20000b22`, and uncompressed `1224×2720` display buffers on the Infinix. The user reported that the game was now visible, with some white areas and flickering on the battlefield. The USB screenshot captured the crash dialog after the game stopped, so it did not capture the flicker. The battle logged roughly 13–15 FPS with median GPU busy times around 57–66 ms in the sampled heavy intervals. Lighter sequences reached approximately 30 FPS. These observations came from one run that changed scenes.

The Mali command-stream groups reported status `0x22c00488` and the app received `VK_ERROR_DEVICE_LOST` on frame 2196. Arm's exception table identifies `0x88` as a GPU shareability fault. The log locates the stop in the GPU, but it does not identify the command or explain the preceding white areas. Peanuts also logged a D24/S8 texture-copy fallback and ran with NDSR enabled. Those are separate leads for the visual and performance issues. [Arm Mali exception definitions](https://nest-open-source.googlesource.com/manifest_repos/mali-driver/+/0f8397eced2de6bc649a9cc32d0fae77a1dc34dc/bifrost/r44p0/kernel/drivers/gpu/arm/midgard/gpu/backend/mali_kbase_gpu_regmap_csf.h)

First, repeat the battle on Alpha 07 at native handheld resolution with NDSR and frame generation off. Keep the same settings for any driver comparison. Use Android's screenshot during the white or flickering frames to establish whether the distortion is present before hardware scanout. [Peanuts Native graphics controls](https://github.com/igawa6/peanuts-native/blob/main/peanuts/docs/FAQ.md)

## CPU-wait comparison

`python3 scripts/package-alpha06-preview.py --cpu-waits` generates `dist/PanVK_G615_Alpha_07_CPU_Waits_Preview.adpkg.zip`. It keeps the linear buffers and release fences. The sole driver behavior change is that same-queue kbase semaphore waits default to the existing CPU fallback, equivalent to setting `PANVK_KBASE_GPU_SEMAPHORE_WAITS=0` on Alpha 07. Run it with the same battle and settings if Alpha 07 still stops. Compare both time to failure and actual frame times. CPU waits can reduce FPS, so this build is a stability comparison. [Upstream semaphore wait behavior](https://github.com/zenithblue-oss/panvk-kbase-android/releases)

The first observed CPU-wait run kept modifier `0x0` and passed the frame number where Alpha 07 Linear had lost the device. The player reported that some previously missing graphics reappeared, while white flicker remained in battle. The supplied screenshot shows washout in the captured game image itself, with the touch controls still drawn. The app was rendering at `1920×1080` and still passed `DM_VK_NDSR=1`. Heavy battle samples were typically 13–16 FPS. One pass beyond the previous failure point does not establish stability or an FPS improvement.

## Reproduce the remaining artifacts

Use the CPU-wait preview and start with a single resolution change. In the game's **Performance → Picture** settings, select **Handheld** or the game's **720p** preset. The Android surface can stay at `1224×2720`. Confirm the game's `WindowInitialize` size and compare the same room and battle after the cache warms. Compare NDSR separately at the same resolution if the game exposes an upscaler control. [Peanuts Native graphics controls](https://github.com/igawa6/peanuts-native/blob/main/peanuts/docs/FAQ.md)

In the follow-up battle, Peanuts passed `DM_OPMODE=0`, while `WindowInitialize` still recorded `1920×1080` guest presentation textures. That allocation size does not reveal the size of every internal pass. Several heavier intervals ran at 15–16 FPS and a lighter interval logged 18.9 FPS. A screenshot captured the 3D scene flashing white while Taunie's dialogue was intact. The driver was still importing linear display buffers.

For the FPS comparison, use Peanuts' **Resolution scale** at **0.75×** if the title offers it, together with the same driver, save and camera angle. Leave the Handheld setting as it was in the previous run so this measures the effect of render scale. Compare the `pace up to frame` lines for presented FPS, GPU busy time and the GPU completion time. The latest Handheld samples reported roughly 44–54 ms of median GPU busy time, against a 33.3 ms frame budget at 30 FPS. If scaling increases artifacts, compare at 1× before changing a driver feature. [Peanuts Native resolution scale](https://github.com/igawa6/peanuts-native/blob/main/peanuts/docs/FAQ.md#can-i-make-a-game-sharper-or-lighter-than-its-own-resolution)

The temporary `DM_RES_SCALE=0.75` test followed the CPU-wait baseline and restored the ordinary feedback-loop setting. Peanuts scaled some targets from `1920×1080` to `1440×810`. Applying the same draw-count and GPU-busy filter used below gave 16.1 FPS and 47.6 ms median GPU busy time in four intervals, compared with 16.0 FPS and 52.2 ms in nine baseline intervals. The player still saw white flashes. Peanuts logged three D24/S8 content drops when targets changed scale because the driver exposes these formats as blit sources only. That identifies a correctness issue with scaling on this driver. The native-scale run still flashed without these scale-induced drops, so the original flicker needs a separate render-pass capture. The temporary render-scale override was removed.

For the white flicker, the affected run logged a `1×1` color attachment sampled by the pass that writes it. This gives a specific comparison at the same resolution and upscaler settings. Peanuts' log advertises `DM_VK_FB_LOOP=0` as the switch to disable its Vulkan attachment feedback-loop path. Add just that key to the launcher environment for one run, then remove it. If the captured image changes, compare the same camera angle before attributing the washout to the feedback loop. [Peanuts Android environment overrides](https://github.com/igawa6/peanuts-native/blob/main/android/TESTING.md)

The comparison launch verified `DM_VK_FB_LOOP=0` in the launcher log and `attachment feedback loops ... off` in the replay log. The white flicker persisted. In five-second intervals with 850–1200 draws per frame and GPU busy median above 30 ms, the runs measured 16.0 FPS with the feature enabled (nine intervals) and 16.8 FPS disabled (four intervals). Their corresponding median GPU busy times were 52.2 and 51.1 ms. The draws filter selects similarly heavy intervals, but the samples can differ by scene and temperature. This test provides no clear performance improvement. The temporary launch override was removed and the configuration verified afterward. Investigate the depth/stencil copy, deferred lighting and exposure passes when collecting the next rendering trace.

## GPU timing capture

Six samples from the active CPU-wait run at 0.75× covered frames 2184–2434. Each captured about 120 graphics passes. Use these timestamps to rank GPU work, since profiling adds barriers. Compare a warm run with profiling off for FPS. Peanuts confirmed that `DM_VK_GPUPROF=0` took effect at frame 2475. [Peanuts GPU profiling](https://github.com/igawa6/peanuts-native/blob/main/android/TESTING.md)

| Work in sampled frames | GPU time |
| --- | ---: |
| Entire profiled frame | 39.6–43.5 ms |
| Graphics passes | 30.9–35.1 ms |
| Transform-feedback begin/end sites, 45 each per sample | 6.4–7.3 ms combined |
| Single compute dispatch | 0.16–0.33 ms |

Four of the most expensive groups in frame 2434 used the same `1920×1080` attachments (`c1:43 c2:37 c3:37 c4:122 d:129`). They took 9.0 ms in total across 488 draws. The timings support profiling tile stores, reloads and pass transitions, including the depth/stencil attachment that stayed at native size. Transform feedback supports game geometry and needs to stay enabled while testing improved synchronization. The capture contains durations and render-target formats. Identifying the white flash still requires inspecting the first incorrect target in a frame where it occurs.

Newer public PanVK work includes render-pass merging and deferred fragment waits. Evaluate those changes against the same scene in a source build, with the tested linear-display and release-fence behavior in place. The upstream `795ca7ff` Android binary had previously crashed inside `memcpy` in Peanuts on this phone. A source rebuild and device comparison are needed before promoting a newer baseline. [Newer PanVK patch stack](https://github.com/MineGraph-bilibili/panvk-Android/releases)
