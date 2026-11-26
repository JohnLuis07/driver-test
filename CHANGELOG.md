# Changelog

## G615 Alpha 02

- Corrected push descriptor storage and graphics/compute meta snapshots to account for expansion from logical Vulkan descriptors to hardware records. Kept the advertised limit at 32.
- Added checks that stop recording on an oversized push descriptor footprint and log the offending count.
- Added failure-stage logging to Android AHB swapchain creation. Kept existing formats, import and ownership behavior.
- Added a diagnostic APK-independent driver ZIP with matching separate DWARF symbols and a distinct Peanuts package identity.

## G615 Alpha 01

- Pinned the public kbase series to its declared Mesa commit and used the G615 CSF profile.
- Added Android ARM64 build, package validation and source/notice packaging.
- Preserved the pinned implementation's feature reporting and synchronization behavior.

Alpha 03 is deferred pending stability evidence.
