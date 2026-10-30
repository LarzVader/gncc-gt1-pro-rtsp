#!/usr/bin/env python3
# The Tuya toolchain looks for its libraries under a fixed path in /opt. So that it
# runs from any folder without sudo, its programs get a relative search path.
# usage: toolchain-rpath-fix.py <toolchain-dir> <patchelf>
import os, struct, subprocess, sys

wk, patchelf = sys.argv[1], sys.argv[2]
ziel = os.path.join(wk, "lib")
geaendert = 0
for wurzel, _, dateien in os.walk(wk):
    # only the programs for the PC, not the ARM files in the sysroot
    if "/sysroot" in wurzel:
        continue
    for name in dateien:
        pfad = os.path.join(wurzel, name)
        if os.path.islink(pfad) or not os.path.isfile(pfad):
            continue
        with open(pfad, "rb") as f:
            kopf = f.read(20)
        if kopf[:4] != b"\x7fELF" or struct.unpack("<H", kopf[18:20])[0] != 62:   # 62 = x86-64
            continue
        alt = subprocess.run([patchelf, "--print-rpath", pfad], capture_output=True, text=True).stdout.strip()
        if "/opt/" not in alt:
            continue
        rel = os.path.relpath(ziel, os.path.dirname(pfad))
        modus = os.stat(pfad).st_mode
        os.chmod(pfad, modus | 0o200)
        subprocess.run([patchelf, "--set-rpath", "$ORIGIN/" + rel, pfad], check=True)
        os.chmod(pfad, modus)
        geaendert += 1
print(f"{geaendert} programs changed")
