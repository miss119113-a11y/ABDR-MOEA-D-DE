# UAV terrain maps

Three original elevation-model TIFF files used in the UAV experiments are provided in the archive parts under [`archive/`](archive/):

| Map | File after extraction | Application |
|---|---|---|
| Christmas Island | `ChrismasTerrain2.tif` | Main scenarios S1–S4 |
| Crater Lake | `Crater_Lake_DEM.tif` | External-terrain experiments |
| Mount St. Helens | `Mount_St_Helens_DEM.tif` | External-terrain experiments |

These are the original TIFF bytes from the supplied experimental archives. The ZIP is split into eight numbered pieces solely to support uploading through the connected GitHub interface; no image values or pixel resolution were changed.

To extract all three TIFFs, run from the repository root:

```bash
python maps/extract_maps.py
```

The script joins the numbered parts in order, verifies the archive SHA-256 digest, and extracts the files to `maps/terrain/`.

In MATLAB:

```matlab
addpath('maps/terrain');
H = imread('ChrismasTerrain2.tif');
```

The file name `ChrismasTerrain2.tif` retains the spelling expected by the MATLAB model source. External terrain runs may specify a TIFF directly using the experiment's terrain override option.
