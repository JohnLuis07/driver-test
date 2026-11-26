# PanVK G615

Independent Mesa PanVK baseline for the Infinix GT 30 Pro (X6873), Mali-G615 MC6, Android 16 and Peanuts Native 0.1.8. The first target is Pokémon Legends: Z-A (`0100F43008C44000`).

The [Alpha 04 prerelease](https://github.com/JohnLuis07/driver-test/releases/tag/panvk-g615-alpha04) targets the platform Android native-buffer import route. See the [call-path audit and test plan](docs/alpha04-wsi.md).

The [Alpha 03 prerelease](https://github.com/JohnLuis07/driver-test/releases/tag/panvk-g615-alpha03) includes the driver, diagnostic build, and smoke tests. Alpha 03 changes Android swapchain presentation and adds synchronized pixel readback diagnostics. See the [rendering recovery notes and test plan](docs/alpha03-rendering.md).

Alpha 02 addresses an internal push-descriptor buffer overflow identified in the Alpha 01 first-frame crash investigation. It also reports which Android swapchain stage fails. See the [Alpha 02 investigation and device settings](docs/alpha02-investigation.md).

Alpha 01 compiled in Codespaces and passed static Android ABI and Peanuts ZIP import checks. Device execution is pending. Download the driver ZIP, matching source archive, notices, build manifest and checksums from the [Alpha 01 GitHub prerelease](https://github.com/JohnLuis07/driver-test/releases/tag/panvk-g615-alpha01). Local builds write these files to `dist/`.

- [Build and packaging](BUILD.md)
- [Device test procedure](TESTING.md)
- [Source selection and rendering investigation](docs/research.md)
- [Reference package analysis](reference/README.md)
- [Changelog](CHANGELOG.md)
