#!/usr/bin/env python3
"""Reassemble and extract the original, unmodified DEM GeoTIFF archive.

Run from the repository root: python maps/extract_maps.py
No third-party Python packages are required.
"""
from pathlib import Path
import hashlib
import shutil
import zipfile

MAPS = Path(__file__).resolve().parent
PARTS = [MAPS / 'archive' / f'UAV_Terrain_DEMs.zip.part{i:02d}' for i in range(1, 9)]
DEST = MAPS / 'terrain'
EXPECTED_SHA256 = '82ae39c04087fa3c46ac8e89e479a4199aedaf4104cada1a29321905f809a49b'
EXPECTED_FILES = {'ChrismasTerrain2.tif', 'Crater_Lake_DEM.tif', 'Mount_St_Helens_DEM.tif'}


def main():
    missing = [str(p) for p in PARTS if not p.is_file()]
    if missing:
        raise FileNotFoundError('Missing archive part(s): ' + ', '.join(missing))
    DEST.mkdir(exist_ok=True)
    archive = DEST / 'UAV_Terrain_DEMs.zip'
    digest = hashlib.sha256()
    with archive.open('wb') as output:
        for part in PARTS:
            with part.open('rb') as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b''):
                    output.write(chunk)
                    digest.update(chunk)
    if digest.hexdigest() != EXPECTED_SHA256:
        archive.unlink(missing_ok=True)
        raise ValueError('DEM archive SHA-256 mismatch; check all parts')
    with zipfile.ZipFile(archive) as z:
        if set(z.namelist()) != EXPECTED_FILES:
            raise ValueError('Unexpected DEM filenames inside archive')
        for name in sorted(EXPECTED_FILES):
            with z.open(name) as src, (DEST / name).open('wb') as dst:
                shutil.copyfileobj(src, dst)
    archive.unlink()
    print('Three original TIFF maps extracted to:', DEST)
    for name in sorted(EXPECTED_FILES):
        print(' -', name)


if __name__ == '__main__':
    main()
