# Build

Use Ubuntu 24.04 x86-64. The Codespaces build uses Python 3.14.2 and GCC 13.3.0 for the native tools. The scripts keep the pinned sources, Python tooling, NDK and build products under `build/`. The first run requires network access for package and source downloads.

```bash
./scripts/setup.sh --install-system
./scripts/build.sh
./scripts/package.sh
```

Omit `--install-system` when the host already has the dependencies in `scripts/ubuntu-noble.lock`. The lock records direct Ubuntu dependencies on the build host. APT may require a package snapshot if a listed version has been superseded. `JOBS` overrides the Ninja job count. Source revisions, Android API and NDK archive digest are in `scripts/versions.sh`. The build verifies revision identities and applies the public patch series to a clean checkout. Patch output is written to `build/patch.log`. If patch application fails partway, start with a fresh Mesa checkout before retrying.

Mesa's Vulkan target uses the kbase kernel backend and Android WSI. Native LLVM 18 and its matching SPIR-V translator generate build-time shaders. The target build uses Mesa's checksum-pinned libdrm 2.4.133 wrap as a static library and the NDK's system zlib. The Android library targets aarch64-linux-android29 and uses the NDK's bionic sysroot. Gallium, EGL, OpenGL, GLX, GBM, X11 WSI and target LLVM are excluded. The public profile applies a universal set of Mali backends that includes v11. Alpha 01 retains that source selection.

Packaging strips the installed ICD and checks the Android ABI note, ELF machine and class, dynamic imports, loader exports, SONAME, segment alignment and archive contents. The resulting ZIP has the same two-file layout as the reference. The accompanying source archive preserves the patched Mesa sources and per-file copyright notices. Distribute it with the notices archive and checksums. Mesa uses primarily MIT/X11 and Khronos terms. Kbase userspace support is MIT and the imported kernel UAPI headers carry GPL-2.0 with the Linux syscall exception. The NDK notices cover the toolchain runtime linked into the binary.

`build/android/src/panfrost/vulkan/libvulkan_panfrost.so` is the unstripped build output. The package manifest records the library digest and ELF build ID for log correlation. The build uses pinned inputs and stable ZIP timestamps. Bit-for-bit reproducibility across different host toolchains and absolute paths remains unverified.
