# Changelog

## G615 Alpha 05

- Added the kbase swapchain allocation preference to Android 16's primary AHB usage query.
- Resolved single-plane mapper backing FDs by validated allocation size and recorded mapper layer and allocation metadata.
- Added HAL route, swapchain request, and kbase import diagnostics. Device validation is pending.

## G615 Alpha 04

- Added kbase swapchain usage negotiation for uncompressed 32-bit Android buffers.
- Added validation of documented MediaTek single-plane linear handles when gralloc mapper metadata is unavailable.
- Added import backing-size checks and labeled runtime diagnostics from allocation through presentation.

## G615 Alpha 03

- Reused Mesa CPU WSI staging for Android ICD swapchain presentation and report window lock, layout, fence and post errors.
- Selected native-buffer DMA-BUF FDs from gralloc plane metadata and confined temporary Android image creation chains to their calls.
- Logged early swapchain activity and synchronized nonblack pixel counts. Added a color-order conversion and opaque composition handling.

## G615 Alpha 02

- Corrected push descriptor storage and graphics/compute meta snapshots to account for expansion from logical Vulkan descriptors to hardware records. Kept the advertised limit at 32.
- Added checks that stop recording on an oversized push descriptor footprint and log the offending count.
- Added failure-stage logging to Android AHB swapchain creation. Kept existing formats, import and ownership behavior.
- Added a diagnostic APK-independent driver ZIP with matching separate DWARF symbols and a distinct Peanuts package identity.

## G615 Alpha 01

- Pinned the public kbase series to its declared Mesa commit and used the G615 CSF profile.
- Added Android ARM64 build, package validation and source/notice packaging.
- Preserved the pinned implementation's feature reporting and synchronization behavior.
