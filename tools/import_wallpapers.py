"""Copies the original game's full-screen puzzle wallpapers into the app.

KSS ships only the Amnesia desk (wallpaper0) as full-screen art. The rest
are downloaded on first display from Firebase Storage `wallpapers/<id>.png`
(native sub_aa702c) and cached in the app's private directory as
`app_flutter/assets_images_wallpaper_image_<id>.png`, with the shared
preference `flutter.wallpaper_version_<id>` recording the cached version.

references/recovery/wallpapers-1.29.3/ holds what was captured from the
user's own KSS 1.29.3 install on the rooted Nord N30 (2026-10-25), after the
user opened every wallpaper their account owns:

  full/<id>.png            the cached full-screen art, renamed
  thumbnails/<id>.png      every thumbnail in the 1.29.3 asset pack
  wallpapers.json          the 1.29.3 catalog (adds wallpaper1013-1015)
  wallpaper_versions.txt   the cached-version preferences

To capture again (PowerShell, root):

  adb shell "su -c 'cp /data/data/com.basakansoft.koreanstudentsimulator/
      app_flutter/assets_images_wallpaper_image_*.png /sdcard/Download/x/'"
  adb pull /sdcard/Download/x/ <dir>

Only wallpapers the account owns are ever downloaded, so the rest keep
their thumbnails. Like all KSS art this is local-only and gitignored.

  python tools/import_wallpapers.py && python tools/build_account_catalog.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

D30 = Path(__file__).resolve().parent.parent
SOURCE = D30 / "references/recovery/wallpapers-1.29.3"
IMAGES = D30 / "assets/images/kss/images"


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE}", file=sys.stderr)
        return 1
    full = thumbs = 0
    for src in sorted((SOURCE / "full").glob("wallpaper*.png")):
        shutil.copyfile(src, IMAGES / "wallpaper_image" / src.name)
        full += 1
    # Thumbnails already bundled stay as they are; only new ones are added.
    for src in sorted((SOURCE / "thumbnails").glob("wallpaper*.png")):
        dest = IMAGES / "wallpaper_thumbnail" / src.name
        if not dest.exists():
            shutil.copyfile(src, dest)
            thumbs += 1
    print(f"{full} full-screen wallpapers, {thumbs} new thumbnails")
    return 0


if __name__ == "__main__":
    sys.exit(main())
