# Patches

Alpha 01 applies the pinned zenithblue-oss patch series directly from its source repository. The ordered application log is `build/patch.log`. The Alpha 02 patches apply after the public series and cover push descriptor bounds plus Android swapchain failure logging. See the [crash investigation](../docs/alpha02-investigation.md).

Alpha 03 applies the Alpha 02 push descriptor patch plus the Alpha 03 WSI and native-buffer patches. The Alpha 02 swapchain logging patch is retained for rollback history.

Alpha 04 adds the MediaTek native-buffer import and diagnostics patch on top of Alpha 03.

Alpha 05 adds the Android 16 AHB usage query and mapper FD correction after the Alpha 04 patch.
