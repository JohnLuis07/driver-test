# Alpha 02 crash investigation

The analysis uses the excerpt extracted from the actual device logs. The installed device library build ID, full event ordering and exact failing descriptor layout were unavailable.

## Alpha 01 ARM64 crash

The original local ELF has GNU build ID `cf58a336284de4de1dfbc18e17c8beb18bc50efe`, matching the Alpha 01 release manifest. Its regular symbol table survived the release build. It lacks the Mesa DWARF line information needed for direct line symbolization. The device crash needs a module build ID and executable map entry for independent confirmation of the installed image and reported offset convention.

Both `llvm-addr2line` and `llvm-symbolizer` identify `0xebb840` as `meta_gfx_end` and `0xebc480` as `panvk_v11_CmdClearColorImage`. Disassembly at `0xebb83c` calls `memcpy@plt`, with `x1 = save_ctx + 0x10` and `w2 = *(uint32_t *)(save_ctx + 0x418) << 5`. The reported LR is the next instruction. At `0xebc47c`, the color-clear wrapper calls `meta_gfx_end`, and the next instruction is the reported backtrace offset. This matches `panvk_vX_cmd_meta.c:239–241` and `panvk_vX_cmd_meta.c:404–407`.

Those translations use ELF virtual addresses relative to load bias. The executable PT_LOAD has `p_vaddr - p_offset = 0x4000`. If a log reports file offsets or offsets relative to the executable segment, translate from the corresponding mapping before using the tools. The two matching return sites strongly support the ELF virtual address interpretation here. The register dump is inside libc, where the implementation may have advanced pointers or decremented the length. The excerpt does not contain device libc instructions or the original call-entry registers.

### Reproducible source defect

Alpha 01 uses the same constant, 32, for the advertised Vulkan logical push-descriptor limit and for the backing arrays in command-buffer push sets and graphics/compute meta snapshots. A normal combined image sampler consumes two internal records. Seventeen legal combined descriptors therefore need 34 records, exceeding both arrays. Immutable multi-plane samplers can expand further. A graphics save can overwrite its own stack-local count field, and the restore uses that field as a copy length. This is a direct source-level corruption path consistent with the stack guard read. The exact failing layout and write sequence on the phone remain unconfirmed.

Peanuts counts logical descriptor elements and chooses push descriptors when that count fits the advertised limit in `vka_pso.c:layout_slow`. Its choice explains why a valid app layout can reach the PanVK defect. Faux123 v1.1.8, build ID `22e2bb613cb865343916c9e15589db17040d19f6`, uses the same restore-copy instruction pattern but places the saved count at offset `0x1818` instead of `0x418`. That is consistent with 192 internal slots in its save object. Its private sources are unavailable.

Alpha 02 keeps 32 advertised logical descriptors. It reserves 160 internal records per push set and per meta snapshot, covering up to three texture and two sampler records per logical descriptor. A compile-time assertion ties the multiplier to those limits. Regular and template push updates and the graphics and compute meta copy paths check record counts before copying or writing. An out-of-range count is logged and marks the command buffer failed.

An AddressSanitizer host model of the snapshot layout and copy sequence reproduced a stack-buffer-overflow with 34 records and the old 32-record capacity. The same model passed with the new capacity at 2, 32, 34, 64 and 160 records. This validates the size arithmetic and failure mechanism. It does not execute Vulkan or reproduce the game's exact layout.

## Other symptoms

- **Android swapchain.** Peanuts logs a failed `vkCreateSwapchainKHR` and returns from `swap_create` without creating a valid swapchain. Its rendering path can still reach a separate clear. The swapchain allocates its own RGBA AHBs, queries DMA-BUF-compatible memory, then creates, allocates and binds Android-backed images. The AHB stays referenced through the image/memory lifetime. Failure destroys all partially initialized images and releases their AHBs. Import code can return this status for failed gralloc layout discovery, a rejected CPU-linear check, or failed DMA-BUF import. Alpha 02 logs which per-image stage failed and the returned result. The mapper backend and import errno lines will distinguish vendor-layout and kbase failures. The evidence supports a separate presentation problem, but the exact stage and relation to frame scheduling are unverified. There is a comparable stock G615 mapper failure on another ROM. [Public G615 records](https://github.com/zenithblue-oss/panvk-kbase-android/blob/main/docs/universal/v11/README.md)
- **D24/S8 scaling.** PanVK gains blit destination support from a color target capability. D24/S8 uses depth/stencil attachment capabilities instead. Peanuts' rescaler checks both blit features and explicitly clears affected images when it cannot transfer the original contents. A scaled depth/stencil copy needs an implemented aspect-aware path in the driver or an app fallback that preserves/rebuilds depth and stencil. Ordinary copies between equal-sized subresources are a different operation. No format feature changes are justified by the excerpt.
- **Pipeline threads.** Four-thread prewarm success and incomplete shader-part preparation do not identify the fault. The backtrace is in CPU command encoding, after the app called a driver clear. Encoder waits are consistent with losing the consumer thread. Logs with timestamps and thread IDs are required to establish their ordering. Keep GPL, update-after-bind, pipeline cache synchronization, NIR and subgroup behavior unchanged until separate evidence points there.

## Next comparison

All options below have consumers in Peanuts commit `6eb10e52955e`. The resolution setting is read by `vka_resscale.inc`, GPL at device creation, compilation settings in `vka_pso.c`, NDSR in `vka_draw.c`, FSR in `vka_present.c`, LSFG in `vka_framegen.c` and the limiter in `hle_fpslock.c`.

```ini
DM_RES_SCALE=1.0
DM_VK_PSO_ASYNC=0
DM_VK_GPL=0
DM_VK_PREWARM=0
DM_VK_PSO_SLOTS=1
DM_LSFG=0
DM_VK_NDSR=0
DM_VK_FSR=0
DM_FPS_LIMIT=30
```

Restart for each comparison. Compare the same save and settings with faux123 v1.1.8, Alpha 01 and Alpha 02. Record whether each reaches first present and gameplay, then run 30 minutes while monitoring crashes, encoder stalls and corruption. Re-enable one option per run. Use the per-game GPU driver picker to roll back to Alpha 01 or faux123, then restart the game.
