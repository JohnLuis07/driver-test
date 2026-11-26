# Source selection and rendering investigation

## Baseline

| Source | Selection and role |
| --- | --- |
| Mesa | `main` commit `5a07217f034b3e50d8c7c7794f97a2df1742613b`, Mesa 26.3.0-devel. The exact Git fetch succeeded. |
| zenithblue-oss | Public snapshot `5b87b74d3e2580d5816e7f2c629f6f016a462f28`. Its lock selects this Mesa commit and 179 patches applied cleanly in the G615 CSF profile. |
| faux123 | Reference release `v1.1.8`. Its metadata identifies Mesa, zenithblue, and private patch and tree identities. The private patch terms were unavailable for inspection. |
| Peanuts Native | MIT-licensed source at tag `v0.1.8-1`, commit `6eb10e52955e8094d7b47a8dd2baba91b656f46d`. Reviewed for ZIP import, startup and placed-memory readiness. |

The zenithblue RC4 tag points to public reference source. The upstream release notes state that their RC4 binary used an unsaved patch set. Alpha 01 uses the public snapshot and doesn't require the faux123 companion repository. [Mesa](https://gitlab.freedesktop.org/mesa/mesa) · [Zenithblue release notes](https://github.com/zenithblue-oss/panvk-kbase-android/releases/tag/panvk-kbase-v0.1.0-rc4) · [Faux123 provenance](https://github.com/faux123/panvk-faux123-driver-ace#where-the-driver-comes-from)

The G615 profile covers GPU ID `0xb8a31030`, architecture 11, CSF and kbase UAPI 1.21 on a different MT6897 handset. The Infinix kernel ABI, Android app SELinux permissions, gralloc layouts and external memory import behavior need verification. `panvk_vX_physical_device.c` reports map-memory2 and placed maps, BDA, descriptor indexing on v11, timeline semaphores, dynamic rendering and synchronization2. `panvk_device_memory.c` sends placed requests to the kmod map path with `MAP_FIXED`. This path depends on a suitable import and CPU mapping of the backing DMA buffer. Peanuts tests actual remap/readback and may reject a device even when the extension is advertised. [G615 profile](https://github.com/zenithblue-oss/panvk-kbase-android/blob/5b87b74d3e2580d5816e7f2c629f6f016a462f28/profiles/g615-v11-csf.json) · [Peanuts Mali tracking](https://github.com/igawa6/peanuts-native/issues/20)

## Rendering

- The pinned `csf/panvk_vX_exception_handler.c` copies a scratch framebuffer descriptor in the tiler OOM handler and queues fragment work immediately after the copy. Its final texture-cache invalidation serves later preloads. Mesa 26.2.7 lists fixes for flushing after copying the descriptor and restoring the flush ID. If device traces implicate incremental rendering, compare the per-copy synchronization and scratch-register lifetime against those fixes before backporting. Mesa 26.3.0 also documents CRC initialization changes for v11+. [Mesa 26.2.7](https://docs.mesa3d.org/relnotes/26.2.7.html) · [Mesa 26.3.0](https://docs.mesa3d.org/relnotes/26.3.0.html)
- The public patch series already changes v11 Z/S preload, dynamic rendering layer selection, cache invalidation, subqueue sync scope, GPU pre-raster ordering and MediaTek DMA-buffer import. Review attachment load/store operations, barriers and image transitions at the first divergent render pass. The stock self-test provides no PanVK results.
- Compare the last correct scene attachment against the first white one. A valid UI over the white scene narrows the capture to scene passes and composition inputs. Compare the same render target before and after sampling, blending, feedback, and tone mapping. Inspect descriptor/image view formats and filter state, exposure values and any nonfinite fragment inputs/outputs before considering a NIR or floating-point change. Peanuts source documents prior Z-A issues involving stencil views and descriptor formats on other backends. [Pinned Z-A implementation notes](https://github.com/igawa6/peanuts-native/blob/6eb10e52955e8094d7b47a8dd2baba91b656f46d/dm/games/0100F43008C44000/README.md)
- The baseline already has a configurable BC shadow compression path. Where the test harness can set the environment, compare `PANVK_BC_AFRC=0` against the default separately. A change there tests BC shadow compression, while `PANVK_DEBUG=wsi_no_afbc` tests the Android WSI modifier filter. Neither test alone establishes the cause of white frames.

## Performance

After a repeatable correct run, compare cold and warm pipeline creation, submission counts and waits, descriptor allocation/update time, memory allocation cost and GPU frame pacing with the same route and thermal conditions. The baseline already includes public register allocation, NIR loop-pass, Android disk cache and tiler heap improvements. Profile first to distinguish compiler stalls, GPU throughput and submission latency.
