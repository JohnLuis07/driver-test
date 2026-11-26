#!/usr/bin/env python3
"""Build Android previews from the exact Alpha 05 Android release."""

import argparse
import hashlib
from io import BytesIO
import json
import os
from pathlib import Path
import struct
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
BASE = "PanVK_G615_Alpha_05"
LIBRARY = "libvulkan_panfrost.so"

BASE_ZIP_SHA256 = "ca3238ea1e76307e2a24345e76de2fdaad53b8025ae49014db30cfb79a9bf359"
BASE_BUILD_ID = bytes.fromhex("0e13290832503280901470b99363acf283e55bbd")
BUILD_ID_OFFSET = 0x350

# Each per-architecture CreateDevice variant in the kbase-only library stores
# vk_drm_syncobj_copy_payloads in vk_device.copy_sync_payloads at offset 0x1830.
# Change STR X8, [X19, #0x1830] to STR XZR, [X19, #0x1830].
COPY_CALLBACK_STORES = (
    0xD53104, 0xD7D128, 0xDA6DE4, 0xDE25B4, 0xEBEF28, 0xF82AF4, 0x1046804,
    0x110A6AC,
)
DRM_CALLBACK_STORE = bytes.fromhex("68 1a 0c f9")
NULL_CALLBACK_STORE = bytes.fromhex("7f 1a 0c f9")

# The primary AHB query loads preferred usage with MOVZ W8, #0x800 and
# MOVK W8, #0x2000, LSL #16. Add the two CPU-access hints to the low half.
PREFERRED_USAGE_OFFSET = 0xD404E8
ORIGINAL_USAGE_LOAD = bytes.fromhex("08 00 81 52 08 00 a4 72")
LINEAR_USAGE_LOAD = bytes.fromhex("48 04 81 52 08 00 a4 72")

# The five CSF variants pass a true default to the option parser for
# PANVK_KBASE_GPU_SEMAPHORE_WAITS. Pass false for the comparison build.
GPU_WAITS_DEFAULT_OFFSETS = (0xEA4404, 0xF66C0C, 0x102A614, 0x10EE518, 0x11B1F68)
DEFAULT_GPU_WAIT = bytes.fromhex("21 00 80 52")
DEFAULT_CPU_WAIT = bytes.fromhex("01 00 80 52")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def write_artifact(name, data):
    fd, pending = tempfile.mkstemp(dir=DIST, prefix=f".{name}.")
    pending = Path(pending)
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(data)
        pending.replace(DIST / name)
    finally:
        pending.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    variants = parser.add_mutually_exclusive_group()
    variants.add_argument("--linear", action="store_true", help="build the Alpha 07 linear preview")
    variants.add_argument("--cpu-waits", action="store_true", help="build Alpha 07 with CPU waits by default")
    args = parser.parse_args()
    linear = args.linear or args.cpu_waits
    alpha = "07" if linear else "06"
    variant = " Linear" if linear else ""
    if args.cpu_waits:
        variant = " CPU Waits"
    label = f"PanVK G615 Alpha {alpha}{variant} Preview"
    preview = label.replace(" ", "_")
    patch_name = "linear-display-buffer" if linear else "kbase-present-sync"
    source_patch = ROOT / "patches" / f"alpha{alpha}-{patch_name}.patch"

    base_zip = DIST / f"{BASE}.adpkg.zip"
    if sha256(base_zip.read_bytes()) != BASE_ZIP_SHA256:
        raise SystemExit("Expected the original Alpha 05 release ZIP with the pinned SHA-256")
    with zipfile.ZipFile(base_zip) as archive:
        original = archive.read(LIBRARY)
        metadata = json.loads(archive.read("meta.json"))

    driver = bytearray(original)
    for offset in COPY_CALLBACK_STORES:
        end = offset + len(DRM_CALLBACK_STORE)
        if driver[offset:end] != DRM_CALLBACK_STORE:
            raise SystemExit(f"Unexpected callback store at file offset {offset:#x}")
        driver[offset:end] = NULL_CALLBACK_STORE

    if linear:
        usage = slice(PREFERRED_USAGE_OFFSET, PREFERRED_USAGE_OFFSET + len(ORIGINAL_USAGE_LOAD))
        if driver[usage] != ORIGINAL_USAGE_LOAD:
            raise SystemExit("Unexpected AHB preferred usage instructions")
        driver[usage] = LINEAR_USAGE_LOAD

    if args.cpu_waits:
        for offset in GPU_WAITS_DEFAULT_OFFSETS:
            option_default = slice(offset, offset + len(DEFAULT_GPU_WAIT))
            if driver[option_default] != DEFAULT_GPU_WAIT:
                raise SystemExit(f"Unexpected semaphore-wait default at file offset {offset:#x}")
            driver[option_default] = DEFAULT_CPU_WAIT

    for old, new in ((b"RC3-lowmem Alpha 05", f"RC3-lowmem Alpha {alpha}".encode()),
                     (b"driver=Alpha05", f"driver=Alpha{alpha}".encode())):
        if driver.count(old) != 1:
            raise SystemExit(f"Unexpected count for {old!r}")
        driver = driver.replace(old, new)

    note = slice(BUILD_ID_OFFSET, BUILD_ID_OFFSET + len(BASE_BUILD_ID))
    if driver[note] != BASE_BUILD_ID:
        raise SystemExit("Unexpected Alpha 05 build ID")
    driver[note] = bytes(len(BASE_BUILD_ID))
    build_id = hashlib.sha1(driver).digest()
    driver[note] = build_id

    description = ("Alpha 06 release synchronization with a linear display-buffer preference."
                   if linear else "Alpha 05 binary with kbase swapchain release synchronization fixed.")
    version = f"Alpha{alpha}-Preview"
    if args.cpu_waits:
        description = "Alpha 07 linear preview using the kbase CPU semaphore-wait fallback by default."
        version = "Alpha07-CPU-Waits-Preview"
    metadata.update(name=label, packageVersion=version, description=description)
    manifest = {
        "basePackageSha256": BASE_ZIP_SHA256,
        "baseLibrarySha256": sha256(original),
        "baseBuildId": BASE_BUILD_ID.hex(),
        "sha256": sha256(driver),
        "buildId": build_id.hex(),
        "sourcePatch": source_patch.name,
        "sourcePatchSha256": sha256(source_patch.read_bytes()),
        "callbackStoreFileOffsets": [hex(offset) for offset in COPY_CALLBACK_STORES],
    }
    if linear:
        manifest["preferredUsageFileOffset"] = hex(PREFERRED_USAGE_OFFSET)
    if args.cpu_waits:
        manifest["cpuWaitDefaultFileOffsets"] = [hex(offset) for offset in GPU_WAITS_DEFAULT_OFFSETS]

    package = BytesIO()
    with zipfile.ZipFile(package, "w") as archive:
        for name, contents in ((LIBRARY, driver), ("meta.json", json.dumps(metadata, indent=2) + "\n")):
            entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, contents, compress_type=zipfile.ZIP_DEFLATED)

    with zipfile.ZipFile(package) as archive:
        if archive.testzip() or archive.namelist() != [LIBRARY, "meta.json"]:
            raise SystemExit("Preview ZIP verification failed")
        header = struct.unpack_from("<16sHHIQQQIHHHHHH", archive.read(LIBRARY))
        if header[0][:6] != b"\x7fELF\x02\x01" or header[1:3] != (3, 183):
            raise SystemExit("Expected an AArch64 shared ELF")
        if json.loads(archive.read("meta.json")) != metadata:
            raise SystemExit("Preview metadata verification failed")

    artifacts = {
        f"{preview}.adpkg.zip": package.getvalue(),
        f"{preview}.build.json": (json.dumps(manifest, indent=2) + "\n").encode(),
    }
    checksums = "".join(f"{sha256(data)}  {name}\n" for name, data in artifacts.items())
    for name, data in artifacts.items():
        write_artifact(name, data)
    write_artifact(f"{preview}.SHA256SUMS", checksums.encode("ascii"))


if __name__ == "__main__":
    main()
