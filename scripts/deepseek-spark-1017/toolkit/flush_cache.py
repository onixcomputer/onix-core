#!/usr/bin/env python3
"""Drop page cache for already-synced files via posix_fadvise(DONTNEED).

On a DGX Spark the GB10 driver allocates from MemFree and does not reclaim the
page cache a checkpoint read leaves behind, so a large rsync/download before a
boot has to be evicted explicitly. drop_caches needs root; DONTNEED does not.
"""
import os
import subprocess
import sys
import time


def meminfo() -> dict[str, int]:
    out = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, _, v = line.partition(":")
            out[k] = int(v.split()[0]) // 1048576  # GiB
    return out


def main() -> int:
    roots = sys.argv[1:] or ["/var/tmp/models"]
    subprocess.run(["sync"], check=True)
    before = meminfo()
    files = 0
    total = 0
    skipped = 0
    t0 = time.time()
    for root in roots:
        if not os.path.exists(root):
            print(f"missing: {root}")
            continue
        for dirpath, _, filenames in os.walk(root):
            for fn in filenames:
                path = os.path.join(dirpath, fn)
                try:
                    st = os.stat(path)
                    if not os.path.isfile(path):
                        continue
                    fd = os.open(path, os.O_RDONLY)
                    try:
                        os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
                    finally:
                        os.close(fd)
                    files += 1
                    total += st.st_size
                except OSError as e:
                    skipped += 1
                    print(f"skip {path}: {e}")
    after = meminfo()
    print(f"fadvise DONTNEED: {files} files, {total/1e9:.1f} GB in {time.time()-t0:.1f}s "
          f"({skipped} skipped); MemFree {before['MemFree']} -> {after['MemFree']} GiB, "
          f"MemAvailable {before['MemAvailable']} -> {after['MemAvailable']} GiB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
