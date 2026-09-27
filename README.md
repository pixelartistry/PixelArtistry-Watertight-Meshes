# PixelArtistry · Watertight & Game-Ready 3D in ComfyUI

Free & local ComfyUI workflows that turn a single image into a **watertight 3D model** – and into a **game-ready low-poly asset with baked textures** – using Pixal3D / TRELLIS.2. Plus a one-click installer for Windows.

▶ Tutorial and more: [PixelArtistry on YouTube](https://www.youtube.com/@PixelArtistry_)

> [!IMPORTANT]
> **Before you start:** set up ComfyUI + TRELLIS.2 first with the **[TRELLIS.2 Installation Guide](https://go.pixel-artistry.com/Trellis2InstallationGuide)**. This installer builds on that setup.

## What's inside

| File | What it does |
|---|---|
| `watertightMeshes_win_installer.bat` | Installs all node packs, the workflows and checks your models, GPU and Blender |
| `workflows/PixelArtistry_01_Image_to_Watertight_Mesh.json` | Image → watertight 3D model (1536) – also print-ready |
| `workflows/PixelArtistry_01b_Image_to_Watertight_Mesh_2K.json` | Same at 2048 for maximum detail (16 GB+ VRAM, 32 GB+ RAM) |
| `workflows/PixelArtistry_02_Image_to_GameReady_Asset.json` | Image → textured high-poly + baked game-ready low-poly |
| `workflows/PixelArtistry_03_Your_Mesh_to_GameReady_Asset.json` | Your own mesh → textured + baked low-poly |

The installer already contains the workflows – you only need the `.bat`. The JSON files are here if you want to load them by hand.

## Requirements

- **A working ComfyUI + TRELLIS.2 setup – follow the [TRELLIS.2 Installation Guide](https://go.pixel-artistry.com/Trellis2InstallationGuide)**
- Windows 10 or 11, NVIDIA RTX 20 series or newer
- [ComfyUI Easy-Install](https://github.com/Tavris1/ComfyUI-Easy-Install) (or ComfyUI portable) with Python 3.12 and PyTorch 2.8.0 + CUDA 12.8
- [VisualBruno's ComfyUI-Trellis2](https://github.com/visualbruno/ComfyUI-Trellis2) installed – it provides CuMesh and O-Voxel
- [Blender](https://www.blender.org/download/) – ideally a separate, clean install without add-ons (see Troubleshooting)
- 32 GB system RAM recommended

## Install

0. If you haven't yet, set up ComfyUI + TRELLIS.2 with the [TRELLIS.2 Installation Guide](https://go.pixel-artistry.com/Trellis2InstallationGuide).
1. Download `watertightMeshes_win_installer.bat`.
2. Put it into your `ComfyUI-Easy-Install\Add-ons` folder (the Easy-Install or portable root folder works too).
3. Close ComfyUI and double-click the file.
4. When the summary shows only `[OK]` lines, start ComfyUI and open **Workflows → PixelArtistry**.
5. In each workflow, paste your Blender path once into the purple **Blender path** node and load your image in **Load Image**.

What the installer does:

1. Checks Python, PyTorch, CUDA and your GPU
2. Downloads the node packs – pinned to the exact versions tested for the video, straight from the original repositories
3. Picks the right WTiVo build for your GPU (RTX 50 or RTX 20/30/40)
4. Installs the Python dependencies into `python_embeded`
5. Runs a quick watertight test on your GPU
6. Installs the four PixelArtistry workflows
7. Checks all models – including shared model folders – and offers to download missing ones from Hugging Face
8. Looks for Blender

It's safe to run again: everything is set back to the tested versions.

## Settings by GPU

| VRAM | WTiVo resolution | Proxy points | Measured on an RTX 5080 |
|---|---|---|---|
| 6 GB | 1024 | lower if you run out of memory | – |
| 8 GB+ | 1536 (workflow 01/02) | 12,000,000 | WTiVo ~2 min, ~6 GB RAM |
| 16 GB+ | 2048 (workflow 01b) | 12,000,000 | WTiVo ~3 min, ~10 GB RAM |

More proxy points capture more detail: at 2K, 25M gives a clean, watertight WTiVo mesh (~85M faces, ~17 GB RAM), but LODTailor breaks it afterwards – even with its standard settings – because it has to decimate a mesh that big. 12M keeps the whole chain watertight. For maximum detail in renders, use 25M and save WTiVo's mesh directly, before LODTailor.

## Troubleshooting

- **Blender errors in the console (Auto-Rig Pro, PolyQuilt, …):** add-ons break headless Blender runs. Download the Blender zip, extract it, create an empty folder named `portable` next to `blender.exe`, and use that path in the Blender path node.
- **Holes after generation:** run again – the structure seed is set to *randomize*.
- **Checking watertightness in Blender:** use the 3D Print Toolbox → Check All. Import textured low-poly files with **Merge Vertices** ticked – a GLB can't give one vertex two UV coordinates, so UV seams otherwise show up as open edges.
- **2K runs out of memory:** restart ComfyUI and close other programs before the run.
- **Installer says ComfyUI is still running:** close it and run the installer again.

## Credits

The watertight, low-poly and baking steps run on free, open-source nodes by **MostAadTech** – please support him:
[YouTube](https://www.youtube.com/@MostAadTech) · [Patreon](https://www.patreon.com/cw/MostafaAwad/membership) · [GitHub](https://github.com/Mstafa-awad) · [X](https://x.com/MostAadTech)

| Node pack | Used for |
|---|---|
| [WTiVo](https://github.com/Mstafa-awad/WTiVo-WatertightVoxel-ComfyuiNode) | making the mesh watertight |
| [Mesh Quad Reconstruct](https://github.com/Mstafa-awad/ComfyUI-Mesh-Quad-Reconstruct) | cleaning the raw mesh |
| [LODTailor Mesh Trimmer](https://github.com/Mstafa-awad/LODTailor-The-Mesh-Trimmer-ComfyuiNode) | lighter and low-poly meshes |
| [LODTailor Bake Forger](https://github.com/Mstafa-awad/LODTailor-Bake-Forger) | baking high-poly maps onto the low-poly |
| [WTiVo Fast Merge by Distance](https://github.com/Mstafa-awad/WTiVo-FastMergeByDistance) | welding duplicate vertices |
| [Trellis2 Mesh Encoder](https://github.com/Mstafa-awad/Trellis2-Mesh-Encoder) | reading your own mesh |
| [CuMesh Decimate](https://github.com/Mstafa-awad/ComfyUI-CuMesh-Decimate) | GPU decimation |
| [Memory Cleaner](https://github.com/Mstafa-awad/ComfyUI-Memory-Cleaner) | freeing VRAM between steps |
| [LODsmith Merge & Watertight](https://github.com/Mstafa-awad/ComfyUI_LODsmith_Merge_Watertight) | installed for completeness |

Also built on:
- [ComfyUI's official Pixal3D / TRELLIS.2 template](https://github.com/Comfy-Org/workflow_templates) (MIT, © Comfy Org)
- [VisualBruno's ComfyUI-Trellis2](https://github.com/visualbruno/ComfyUI-Trellis2) (CuMesh, O-Voxel)
- Models from [Comfy-Org/Pixal3D](https://huggingface.co/Comfy-Org/Pixal3D) and [Comfy-Org/TRELLIS.2](https://huggingface.co/Comfy-Org/TRELLIS.2) – originals by [Tencent ARC](https://huggingface.co/TencentARC/Pixal3D) and [Microsoft](https://huggingface.co/microsoft/TRELLIS.2-4B)

## License

The installer and the workflows are MIT-licensed (see `LICENSE`). The workflows are based on ComfyUI's official template (MIT, © Comfy Org).

The installer doesn't redistribute any node pack or model – it downloads them from their original sources, and each keeps its own license (the node packs are GPL-3.0 or MIT). If you plan to use your results commercially, check the license of every node pack and model you use.

## PixelArtistry

- Website: https://pixel-artistry.com
- YouTube: https://www.youtube.com/@PixelArtistry_
- X: https://x.com/philippsieben
- Newsletter FutureFrames: https://go.pixel-artistry.com/newsletter
