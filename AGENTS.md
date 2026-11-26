# Repository Guidelines

## Project Structure & Module Organization

This repository builds a Mesa PanVK driver for the Infinix GT 30 Pro (Mali-G615) on Android. `scripts/` contains the Bash build and packaging tools, dependency pins, and Python layout test. `patches/` contains the tracked driver changes. Setup fetches Mesa into `build/mesa/` and kbase into `build/kbase/`, where the upstream smoke-test sources live. Put driver fixes in `patches/` so they survive a clean rebuild. See `docs/` for release investigations and `reference/README.md` for package compatibility notes. Packages, manifests, and checksums go in `dist/`.

## Build, Test, and Development Commands

Run these from the repository root on Ubuntu 24.04 x86-64 or in a matching Codespace.

- `./scripts/setup.sh --install-system` installs host dependencies and fetches pinned sources and the Android NDK. Omit the flag if host dependencies are installed.
- `./scripts/build.sh` applies the patch series and cross-compiles the Android ARM64 driver.
- `./scripts/package.sh` validates the ELF and package layout and writes release artifacts to `dist/`.
- Pass `--diagnostic` to both build and package commands to produce a driver package with a separate matching debug symbol file. See `BUILD.md`.

## Coding Style & Naming Conventions

Use four-space indentation in Bash and Python. Quote Bash path expansions and retain strict mode. Follow the surrounding Mesa style when touching C code. Name release patches `alphaNN-short-description.patch` with lowercase, hyphenated descriptions. Check Bash syntax with `bash -n scripts/build.sh` or the script you changed. THIS IS CRUCIAL: EDIT ONLY ON THIS DIRECTORY

## Testing Guidelines

After building, run `python3 scripts/check-mtk-layout.py` for the MediaTek buffer layout and mapper file-descriptor fixtures. Run `./scripts/smoke.sh` to build the Android smoke-test ZIP. Follow `TESTING.md` and `docs/HANDOFF.md` for on-device validation in Peanuts Native. Report which checks ran. For device runs, record the Android build, package SHA-256, and relevant logcat excerpts.

## Commits & Pull Requests

DO NOT COMMIT OR INSTALL SOMETHING THIS IS CRUCIAL 

Use short, imperative subjects such as `Validate mapper buffer size`. In pull requests, describe the affected subsystem, summarize host and device validation, and link any relevant issue. Include a screenshot or short recording for visible rendering changes when available. Keep local build intermediates and device logs out of Git.
