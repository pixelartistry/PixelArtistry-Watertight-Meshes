@echo off
setlocal EnableExtensions DisableDelayedExpansion
title MostAadTech 3D nodes installer by PixelArtistry
cd /d "%~dp0"

rem ===================================================================
rem  MostAadTech 3D nodes installer by PixelArtistry
rem
rem  Put this file into your ComfyUI-Easy-Install folder (next to
rem  "python_embeded") or its "Add-ons" folder, and double-click it.
rem  Works for ComfyUI portable too.
rem  Safe to run again: everything is set back to the tested versions.
rem ===================================================================

set "SELF=%~f0"
set "ROOT=%~dp0"
rem  Also works from a subfolder such as Easy-Install's "Add-ons" folder
if not exist "%ROOT%python_embeded\python.exe" if exist "%~dp0..\python_embeded\python.exe" for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
if not exist "%ROOT%python_embeded\python.exe" if exist "%~dp0..\..\python_embeded\python.exe" for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
set "PY=%ROOT%python_embeded\python.exe"
set "COMFY=%ROOT%ComfyUI"
set "NODES=%COMFY%\custom_nodes"
set "MODELS=%COMFY%\models"
set "GH=Mstafa-awad"

rem -------------------------------------------------------------------
rem  Pinned versions: the exact commits tested for the video.
rem  To update one, paste its new FULL commit hash from GitHub below.
rem  To try the newest versions instead: open cmd, run
rem      set MOSTAAD_LATEST=1
rem  and start this file from that same window.
rem  To test the RTX 20/30/40 build on an RTX 50 card, run
rem      set MOSTAAD_MULTIGPU=1
rem  the same way. Run again without it to go back to the default build.
rem -------------------------------------------------------------------
set "PIN_DATE=2026-09-26"
set "SHA_WTIVO=fb9e9ea6a7deec965d3a4bf43ba7a4a9ff3856f3"
set "SHA_QUAD=74048b3415537e26cc72b46b082a010cd0e357ce"
set "SHA_CUMESH=c4edeb96bf637239cecb731d2869469a3025d742"
set "SHA_MEMCLEAN=3357282290278c96ffa0da180d43bc5eac5f2286"
set "SHA_LODTAILOR=3d25b7d4aa382fa5dac210eb5d8d0eadc4a4f183"
set "SHA_BAKEFORGER=f13589c22558e3ca49dfa87dce709233eb3cc86b"
set "SHA_ENCODER=860313e67f0f69d402310dc325707bab8bec2fe9"
set "SHA_LODSMITH=5da6dd69c02d0f3d4ae743d090cfac79aefe7f96"
set "SHA_FASTMERGE=5392949165ceed1e74448b1949d6e0dc9b34dd92"
set "FAILS=0"
set "MISSING=0"
set "DL=0"

echo.
echo  MostAadTech 3D nodes installer by PixelArtistry
echo  ===============================================
echo  Folder: %ROOT%
echo.

if not exist "%PY%" goto :no_python
if not exist "%NODES%\" goto :no_python
curl --version >nul 2>&1
if errorlevel 1 goto :no_tools
tar --version >nul 2>&1
if errorlevel 1 goto :no_tools

rem  Stop if ComfyUI from this folder is still running - its files would be locked
powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq [IO.Path]::GetFullPath($env:PY) }) { exit 3 }" >nul 2>&1
if "%errorlevel%"=="3" goto :comfy_running

rem -------------------------------------------------------------------
echo.
echo [1/8] Checking your environment
"%PY%" -c "import sys, torch; print('    Python', sys.version.split()[0], '| torch', torch.__version__, '| CUDA', torch.version.cuda)"
if errorlevel 1 goto :no_torch
"%PY%" -c "import torch; print('    GPU', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'none found')"

rem WTiVo's prebuilt backend needs exactly Python 3.12 + torch 2.8.0 + CUDA 12.8
"%PY%" -c "import sys, torch; sys.exit(0 if sys.version_info[:2] == (3, 12) and torch.__version__.startswith('2.8.0') and torch.version.cuda == '12.8' else 1)" >nul 2>&1
if errorlevel 1 (set "WT_ENV=0") else (set "WT_ENV=1")

rem GPU generation: 12 = RTX 50 (Blackwell), 7-9 = RTX 20/30/40, 0/1 = unknown
"%PY%" -c "import sys, torch; sys.exit(torch.cuda.get_device_capability(0)[0] if torch.cuda.is_available() else 0)" >nul 2>&1
set "CC=%errorlevel%"

set "HAVE_GIT="
git --version >nul 2>&1
if not errorlevel 1 set "HAVE_GIT=1"
set "OLD_COMFY="
if not exist "%COMFY%\comfy_extras\nodes_trellis2.py" set "OLD_COMFY=1"
if not exist "%COMFY%\comfy_extras\nodes_mesh_postprocess.py" set "OLD_COMFY=1"

rem -------------------------------------------------------------------
echo.
echo [2/8] Downloading / updating the node packs
call :fetch "WTiVo-WatertightVoxel-ComfyuiNode" "%NODES%" "%SHA_WTIVO%"
call :fetch "ComfyUI-Mesh-Quad-Reconstruct" "%NODES%" "%SHA_QUAD%"
call :fetch "ComfyUI-CuMesh-Decimate" "%NODES%" "%SHA_CUMESH%"
call :fetch "ComfyUI-Memory-Cleaner" "%NODES%" "%SHA_MEMCLEAN%"
call :fetch "LODTailor-The-Mesh-Trimmer-ComfyuiNode" "%NODES%" "%SHA_LODTAILOR%"
call :fetch "LODTailor-Bake-Forger" "%NODES%" "%SHA_BAKEFORGER%"
call :fetch "Trellis2-Mesh-Encoder" "%NODES%" "%SHA_ENCODER%"
call :fetch "ComfyUI_LODsmith_Merge_Watertight" "%NODES%" "%SHA_LODSMITH%"
call :fetch "WTiVo-FastMergeByDistance" "%NODES%" "%SHA_FASTMERGE%"
if not "%FAILS%"=="0" goto :summary

rem -------------------------------------------------------------------
echo.
echo [3/8] Picking the WTiVo build for your GPU
set "WT=%NODES%\WTiVo-WatertightVoxel-ComfyuiNode"
set "WT_RAR=%WT%\build\ForNonBlackwellgpu(rtx50 and below).rar"
if defined MOSTAAD_MULTIGPU goto :wt_force
if %CC% GEQ 12 goto :wt_blackwell
if %CC% LEQ 1 goto :wt_unknown
echo     RTX 20/30/40 class GPU - installing the multi-GPU build
goto :wt_multi
:wt_force
echo     MOSTAAD_MULTIGPU is set - installing the multi-GPU build for testing
:wt_multi
if not exist "%WT_RAR%" goto :wt_norar
tar -xf "%WT_RAR%" -C "%WT%" >nul 2>&1
call :size "%WT%\build\cppmodules.cp312-win_amd64.pyd"
if %SIZE% GTR 20000000 goto :wt_extracted
if exist "%ProgramFiles%\7-Zip\7z.exe" "%ProgramFiles%\7-Zip\7z.exe" x -y -o"%WT%" "%WT_RAR%" >nul 2>&1
call :size "%WT%\build\cppmodules.cp312-win_amd64.pyd"
if %SIZE% GTR 20000000 goto :wt_extracted
echo     [WARN] Could not unpack the .rar automatically. Unpack this file by hand
echo            into the WTiVo node folder and overwrite the files in "build":
echo            %WT_RAR%
set "WT_RAR_TODO=1"
goto :wt_test
:wt_extracted
echo     Multi-GPU build installed
goto :wt_test
:wt_blackwell
echo     RTX 50 series - keeping the default build
goto :wt_test
:wt_unknown
echo     Could not detect the GPU - keeping the default build
goto :wt_test
:wt_norar
echo     [WARN] Multi-GPU archive not found in the repo - keeping the default build
:wt_test
"%PY%" -c "import sys; sys.path.insert(0, r'%WT%'); import torch, wtivo" >nul 2>&1
if errorlevel 1 (set "WT_OK=0") else (set "WT_OK=1")

rem -------------------------------------------------------------------
echo.
echo [4/8] Installing Python dependencies into python_embeded
"%PY%" -m pip install --disable-pip-version-check -q -r "%NODES%\Trellis2-Mesh-Encoder\requirements.txt"
"%PY%" -m pip install --disable-pip-version-check -q -r "%NODES%\WTiVo-FastMergeByDistance\requirements.txt"
"%PY%" "%NODES%\ComfyUI-Mesh-Quad-Reconstruct\install.py"
"%PY%" -c "import cumesh" >nul 2>&1
if errorlevel 1 (set "CUMESH_OK=0") else (set "CUMESH_OK=1")
"%PY%" -c "import o_voxel" >nul 2>&1
if errorlevel 1 (set "OVOX_OK=0") else (set "OVOX_OK=1")
rem FastMerge: native C++ DLL (fast) or Python fallback (slow)
set "FM=%NODES%\WTiVo-FastMergeByDistance"
"%PY%" -c "import sys; sys.path.insert(0, r'%FM%'); import native; sys.exit(0 if native.native_available() else 1)" >nul 2>&1
if errorlevel 1 (set "FM_OK=0") else (set "FM_OK=1")
set "VB_OK=1"
if not exist "%NODES%\ComfyUI-Trellis2\" set "VB_OK=0"

rem -------------------------------------------------------------------
echo.
echo [5/8] Test run - WTiVo has to close a mesh with holes on your GPU
set "WT_RUN=0"
if not "%WT_OK%"=="1" goto :wt_run_skip
echo     This takes a moment...
"%PY%" -c "import sys; src = open(sys.argv[1], encoding='utf-8').read(); exec(src.split('#' + 'WTIVO_SELFTEST' + '#', 1)[1].split('#' + 'END' + '#', 1)[0])" "%SELF%" "%WT%"
if not errorlevel 1 set "WT_RUN=1"
goto :wt_run_done
:wt_run_skip
echo     Skipped - the WTiVo backend did not load
:wt_run_done

rem -------------------------------------------------------------------
echo.
echo [6/8] Installing the PixelArtistry workflows
set "WF=%COMFY%\user\default\workflows\PixelArtistry"
"%PY%" -c "import sys; src = open(sys.argv[1], encoding='utf-8').read(); exec(src.split('#' + 'WORKFLOWS' + '#', 1)[1].split('#' + 'END' + '#', 1)[0])" "%SELF%" "%WF%"
if errorlevel 1 (echo     [WARN] Could not write the workflows) else (echo     Workflows are in the sidebar under Workflows - PixelArtistry)
if not exist "%COMFY%\input\viking_wolf_rune_axe.png" curl -sL --fail -o "%COMFY%\input\viking_wolf_rune_axe.png" "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/input/viking_wolf_rune_axe.png"

rem -------------------------------------------------------------------
echo.
echo [7/8] Checking models in ComfyUI\models
call :link_encoder
call :models
if "%MISSING%"=="0" goto :blender
echo.
if defined AUTO_DL goto :dl_auto
choice /c YN /n /m "    Download the %MISSING% missing model files now? [Y/N] "
if errorlevel 2 goto :blender
goto :dl_go
:dl_auto
if /i not "%AUTO_DL%"=="Y" goto :blender
:dl_go
set "DL=1"
set "MISSING=0"
call :models

rem -------------------------------------------------------------------
:blender
echo.
echo [8/8] Looking for Blender - LODTailor and Bake Forger need it
set "BLENDER="
for /f "delims=" %%B in ('where blender 2^>nul') do if not defined BLENDER set "BLENDER=%%B"
if not defined BLENDER for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender*") do if exist "%%D\blender.exe" set "BLENDER=%%D\blender.exe"
if not defined BLENDER goto :no_blender
echo     Found: %BLENDER%
goto :summary
:no_blender
echo     Not found - install Blender from blender.org

rem -------------------------------------------------------------------
:summary
echo.
echo ============================ SUMMARY ============================
if defined MOSTAAD_LATEST goto :sum_latest
if defined NOT_PINNED goto :sum_notpinned
echo  [OK]   Versions pinned to the ones tested on %PIN_DATE%
goto :sum_versions_done
:sum_latest
echo  [INFO] Newest versions from GitHub - NOT the tested versions
goto :sum_versions_done
:sum_notpinned
echo  [WARN] Some packs could not be updated - they may not be the tested versions
:sum_versions_done
if "%WT_OK%"=="1" (echo  [OK]   WTiVo watertight backend loads) else (echo  [FAIL] WTiVo backend - needs Python 3.12 + torch 2.8.0+cu128 in python_embeded)
if defined WT_RAR_TODO echo  [TODO] Unpack the WTiVo multi-GPU .rar by hand, see step 3
if defined MOSTAAD_MULTIGPU echo  [INFO] Test mode: multi-GPU WTiVo build forced by MOSTAAD_MULTIGPU
if not "%WT_OK%"=="1" goto :sum_cumesh
if "%WT_RUN%"=="1" (echo  [OK]   WTiVo test run on your GPU - holes closed, mesh watertight) else (echo  [FAIL] WTiVo test run failed - see the output of step 5)
:sum_cumesh
if "%CUMESH_OK%"=="1" (echo  [OK]   CuMesh for Quad Reconstruct + Decimate) else (echo  [FAIL] CuMesh missing - install VisualBruno ComfyUI-Trellis2 first)
if "%VB_OK%%OVOX_OK%"=="11" (echo  [OK]   Trellis2 + O-Voxel for the Mesh Encoder) else (echo  [WARN] Mesh Encoder needs VisualBruno ComfyUI-Trellis2 + o_voxel - texturing workflows only)
if "%FM_OK%"=="1" (echo  [OK]   FastMerge runs in fast native mode) else (echo  [WARN] FastMerge uses its slow Python mode - install the Microsoft Visual C++ Redistributable)
if defined OLD_COMFY echo  [FAIL] ComfyUI is too old for the core Trellis2 nodes - run the update .bat first
if not "%MISSING%"=="0" echo  [WARN] %MISSING% model files missing - links are listed in step 7
if defined BLENDER (echo  [OK]   Blender found: %BLENDER%) else (echo  [WARN] Blender not found - LODTailor and Bake Forger will not run)
if not "%FAILS%"=="0" echo  [FAIL] %FAILS% downloads failed - check your connection and run this again
echo.
echo  Next: start ComfyUI and open Workflows - PixelArtistry.
echo  In each workflow, paste your Blender path once into the purple
echo  "Blender path" node - a clean Blender without add-ons works best.
echo  Then load your own image in the "Load Image" node.
echo.
pause
exit /b 0

rem ===================================================================
rem  Error exits
rem ===================================================================
:no_python
echo  [ERROR] python_embeded or ComfyUI\custom_nodes not found next to this file.
echo          Move this .bat into your ComfyUI-Easy-Install folder or its Add-ons folder.
pause
exit /b 1

:comfy_running
echo  [ERROR] ComfyUI is still running from this folder. Close it and run this again.
pause
exit /b 1

:no_tools
echo  [ERROR] curl.exe or tar.exe not found. You need Windows 10 1803 or newer.
pause
exit /b 1

:no_torch
echo  [ERROR] python_embeded has no working PyTorch. Install ComfyUI first.
pause
exit /b 1

rem ===================================================================
rem  :fetch REPO PARENT  - clone or update github.com/Mstafa-awad/REPO
rem  into PARENT\REPO. Uses git when available, otherwise the main zip.
rem ===================================================================
:fetch
set "R=%~1"
set "P=%~2"
set "D=%~2\%~1"
set "REF=%~3"
if defined MOSTAAD_LATEST set "REF=main"
echo     %R%
if exist "%D%.new\" rmdir /s /q "%D%.new"
if exist "%P%\%R%-main\" rmdir /s /q "%P%\%R%-main"
if exist "%P%\%R%-%REF%\" rmdir /s /q "%P%\%R%-%REF%"
if exist "%P%\%R%-main\" goto :fetch_locked
if not defined HAVE_GIT goto :fetch_zip
if not exist "%D%\.git\" goto :fetch_new
git -C "%D%" remote get-url origin >nul 2>&1
if errorlevel 1 goto :fetch_new
git -C "%D%" fetch -q --depth 1 origin %REF%
if errorlevel 1 goto :fetch_keep
git -C "%D%" reset -q --hard FETCH_HEAD
goto :fetch_verify
:fetch_keep
echo            [WARN] Could not download - keeping the version already installed
set "NOT_PINNED=1"
exit /b 0
:fetch_new
rem  Download into a temporary folder first, replace the old one only on success
git init -q "%D%.new"
git -C "%D%.new" remote add origin "https://github.com/%GH%/%R%.git"
git -C "%D%.new" fetch -q --depth 1 origin %REF%
if errorlevel 1 goto :fetch_new_failed
git -C "%D%.new" checkout -q FETCH_HEAD
if exist "%D%\" rmdir /s /q "%D%"
if exist "%D%\" goto :fetch_new_locked
ren "%D%.new" "%R%"
goto :fetch_verify
:fetch_new_failed
rmdir /s /q "%D%.new" 2>nul
goto :fetch_failed
:fetch_new_locked
rmdir /s /q "%D%.new" 2>nul
goto :fetch_locked
:fetch_zip
curl -sL --fail -o "%TEMP%\%R%.zip" "https://github.com/%GH%/%R%/archive/%REF%.zip"
if errorlevel 1 goto :fetch_failed
tar -xf "%TEMP%\%R%.zip" -C "%P%"
del /q "%TEMP%\%R%.zip" 2>nul
if not exist "%P%\%R%-%REF%\" goto :fetch_failed
if exist "%D%\" rmdir /s /q "%D%"
if exist "%D%\" goto :fetch_zip_locked
ren "%P%\%R%-%REF%" "%R%"
exit /b 0
:fetch_zip_locked
rmdir /s /q "%P%\%R%-%REF%" 2>nul
goto :fetch_locked
:fetch_verify
if defined MOSTAAD_LATEST exit /b 0
set "GOT="
for /f %%H in ('git -C "%D%" rev-parse HEAD 2^>nul') do set "GOT=%%H"
if /i "%GOT%"=="%REF%" exit /b 0
echo            [ERROR] Wrong version after download: %GOT%
set /a FAILS+=1
exit /b 1
:fetch_failed
if exist "%D%\" (echo            [ERROR] Download failed - the version already installed was kept) else (echo            [ERROR] Download failed)
set /a FAILS+=1
exit /b 1
:fetch_locked
echo            [ERROR] Folder is in use - close ComfyUI and run this again
set /a FAILS+=1
exit /b 1
:fetch_failed
echo            [ERROR] Download failed
if exist "%D%\" rmdir /s /q "%D%"
set /a FAILS+=1
exit /b 1
:fetch_locked
if not defined HAVE_GIT goto :fetch_fresh
if not exist "%D%\.git\" goto :fetch_fresh
git -C "%D%" reset -q --hard
git -C "%D%" pull -q --ff-only
if errorlevel 1 echo            [WARN] Update failed - keeping the current version
exit /b 0
:fetch_fresh
if exist "%D%\" rmdir /s /q "%D%"
if exist "%D%\" goto :fetch_locked
if defined HAVE_GIT (
    git clone -q --depth 1 "https://github.com/%GH%/%R%.git" "%D%"
) else (
    curl -sL --fail -o "%TEMP%\%R%.zip" "https://github.com/%GH%/%R%/archive/refs/heads/main.zip"
    tar -xf "%TEMP%\%R%.zip" -C "%P%"
    ren "%P%\%R%-main" "%R%"
    del /q "%TEMP%\%R%.zip" 2>nul
)
if exist "%D%\" exit /b 0
echo            [ERROR] Download failed
set /a FAILS+=1
exit /b 1
:fetch_locked
echo            [ERROR] Folder is in use - close ComfyUI and run this again
set /a FAILS+=1
exit /b 1

rem ===================================================================
rem  :size FILE  - sets SIZE to the file size in bytes, 0 if missing
rem ===================================================================
:size
set "SIZE=0"
if exist "%~1" set "SIZE=%~z1"
exit /b 0

rem ===================================================================
rem  :link_encoder - if the TRELLIS.2 shape encoder already exists
rem  somewhere under models (e.g. from VisualBruno), hard-link it to
rem  models\Trellis2\encoders where the Mesh Encoder node looks for it.
rem ===================================================================
:link_encoder
set "ENC=shape_enc_next_dc_f16c32_fp16"
set "ENC_DIR=%MODELS%\Trellis2\encoders"
if exist "%ENC_DIR%\%ENC%.safetensors" exit /b 0
set "ENC_SRC="
for /f "delims=" %%F in ('dir /s /b "%MODELS%\%ENC%.safetensors" 2^>nul') do if not defined ENC_SRC if exist "%%~dpF%ENC%.json" set "ENC_SRC=%%~dpF"
if not defined ENC_SRC exit /b 0
if not exist "%ENC_DIR%\" mkdir "%ENC_DIR%"
mklink /H "%ENC_DIR%\%ENC%.safetensors" "%ENC_SRC%%ENC%.safetensors" >nul 2>&1
if not exist "%ENC_DIR%\%ENC%.safetensors" copy /y "%ENC_SRC%%ENC%.safetensors" "%ENC_DIR%\" >nul
copy /y "%ENC_SRC%%ENC%.json" "%ENC_DIR%\" >nul
echo     Reusing your existing shape encoder from %ENC_SRC%
exit /b 0

rem ===================================================================
rem  :models - model list taken from the workflows' "Model Links" note
rem ===================================================================
:models
set "HF=https://huggingface.co"
call :model "diffusion_models" "trellis_2_int8_convrot.safetensors" "%HF%/Comfy-Org/TRELLIS.2/resolve/main/diffusion_models/trellis_2_int8_convrot.safetensors"
call :model "diffusion_models" "pixal3d_int8_convrot.safetensors" "%HF%/Comfy-Org/Pixal3D/resolve/main/diffusion_models/pixal3d_int8_convrot.safetensors"
call :model "vae" "trellis_2_shape_vae_bf16.safetensors" "%HF%/Comfy-Org/Pixal3D/resolve/main/vae/trellis_2_shape_vae_bf16.safetensors"
call :model "vae" "trellis_2_texture_vae_bf16.safetensors" "%HF%/Comfy-Org/Pixal3D/resolve/main/vae/trellis_2_texture_vae_bf16.safetensors"
call :model "clip_vision" "dino_v3_L_naf_fp32.safetensors" "%HF%/Comfy-Org/Pixal3D/resolve/main/clip_vision/dino_v3_L_naf_fp32.safetensors"
call :model "geometry_estimation" "moge_2_vitl_normal_fp16.safetensors" "%HF%/Comfy-Org/MoGe/resolve/main/geometry_estimation/moge_2_vitl_normal_fp16.safetensors"
call :model "background_removal" "birefnet.safetensors" "%HF%/Comfy-Org/BiRefNet/resolve/main/background_removal/birefnet.safetensors"
call :model "Trellis2\encoders" "shape_enc_next_dc_f16c32_fp16.safetensors" "%HF%/microsoft/TRELLIS.2-4B/resolve/main/ckpts/shape_enc_next_dc_f16c32_fp16.safetensors"
call :model "Trellis2\encoders" "shape_enc_next_dc_f16c32_fp16.json" "%HF%/microsoft/TRELLIS.2-4B/resolve/main/ckpts/shape_enc_next_dc_f16c32_fp16.json"
exit /b 0

rem  :model FOLDER FILE URL
:model
set "MF=%MODELS%\%~1"
if /i "%~1"=="Trellis2\encoders" goto :model_dircheck
rem  Ask ComfyUI itself - covers models\unet, subfolders and extra_model_paths.yaml
"%PY%" -c "import sys; src = open(sys.argv[1], encoding='utf-8').read(); exec(src.split('#' + 'MODELCHECK' + '#', 1)[1].split('#' + 'END' + '#', 1)[0])" "%SELF%" "%ROOT%." "%~1" "%~2" "%DL%"
if errorlevel 1 goto :model_missing
exit /b 0
:model_dircheck
dir /s /b "%MF%\%~2" >nul 2>&1
if errorlevel 1 goto :model_missing
if "%DL%"=="0" echo     OK        %~1\%~2
exit /b 0
:model_missing
if "%DL%"=="1" goto :model_download
echo     MISSING   %~1\%~2
echo               %~3
set /a MISSING+=1
exit /b 0
:model_download
if not exist "%MF%\" mkdir "%MF%"
echo     Downloading %~1\%~2
curl -L --fail --retry 3 -# -o "%MF%\%~2.part" "%~3"
if errorlevel 1 goto :model_dl_fail
move /y "%MF%\%~2.part" "%MF%\%~2" >nul
exit /b 0
:model_dl_fail
echo     [ERROR] Download failed: %~3
del /q "%MF%\%~2.part" 2>nul
set /a FAILS+=1
set /a MISSING+=1
exit /b 0

rem ===================================================================
rem  Python self-test for step 5. cmd never runs the lines below; step 5
rem  reads them from this file and runs them with python_embeded.
rem ===================================================================
#WTIVO_SELFTEST#
import contextlib, io, sys, time
import numpy as np
sys.path.insert(0, sys.argv[2])
try:
    import trimesh
    from inprocess import process_arrays
except Exception as exc:
    print("    [FAIL] Could not load WTiVo:", exc)
    sys.exit(2)
sphere = trimesh.creation.icosphere(subdivisions=4, radius=0.5)
verts = np.asarray(sphere.vertices, dtype=np.float64)
faces = np.asarray(sphere.faces[60:], dtype=np.int32)  # 60 faces removed = holes
log = io.StringIO()
start = time.time()
try:
    with contextlib.redirect_stdout(log):
        _, out_faces, watertight, _, _ = process_arrays(
            verts, faces, input_res=256, final_res=256, proxy_points=200_000, threads=4)
except Exception as exc:
    print("    [FAIL]", exc)
    print("\n".join(log.getvalue().splitlines()[-15:]))
    sys.exit(1)
print(f"    Sphere with holes: {len(faces):,} faces in, {len(out_faces):,} out, "
      f"watertight={watertight}, {time.time() - start:.0f}s")
if not watertight:
    print("\n".join(log.getvalue().splitlines()[-15:]))
sys.exit(0 if watertight and len(out_faces) else 1)
#END#

rem ===================================================================
rem  Python model check for step 7: resolves model folders exactly like
rem  ComfyUI does. Exit 0 = found, 1 = missing.
rem ===================================================================
#MODELCHECK#
import os, re, sys
root, kind, name, quiet = os.path.abspath(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5] == "1"
comfy = os.path.join(root, "ComfyUI")
sys.path.insert(0, comfy)
bases = []
try:
    import folder_paths
    try:
        from utils.extra_config import load_extra_path_config
        configs = [os.path.join(comfy, "extra_model_paths.yaml")]
        for bat in os.listdir(root):  # launchers may pass --extra-model-paths-config
            if bat.lower().endswith(".bat"):
                text = open(os.path.join(root, bat), encoding="utf-8", errors="ignore").read()
                for m in re.finditer(r'--extra-model-paths-config\s+(?:"([^"]+)"|(\S+))', text):
                    p = m.group(1) or m.group(2)
                    configs += [p, os.path.join(root, p), os.path.join(comfy, p)]
        seen = set()
        for cfg in configs:
            cfg = os.path.normcase(os.path.abspath(cfg))
            if cfg not in seen and os.path.isfile(cfg):
                seen.add(cfg)
                load_extra_path_config(cfg)
    except Exception:
        pass
    bases = list(folder_paths.get_folder_paths(kind))
except Exception:
    pass
default = os.path.join(comfy, "models", kind)
if default not in bases:
    bases.append(default)
found = None
for base in bases:
    for folder, _, files in os.walk(base):
        if name in files:
            found = os.path.join(folder, name)
            break
    if found:
        break
if found and not quiet:
    inside = os.path.normcase(os.path.realpath(found)).startswith(os.path.normcase(os.path.realpath(default)) + os.sep)
    where = "" if inside else "  (" + os.path.dirname(found) + ")"
    print(f"    OK        {kind}\\{name}{where}")
sys.exit(0 if found else 1)
#END#

rem ===================================================================
rem  The four PixelArtistry workflows (gzip + base64) for step 6.
rem  cmd never runs the lines below; step 6 unpacks them with Python.
rem ===================================================================
#WORKFLOWS#
import base64, gzip, os, sys
dest = sys.argv[2]
os.makedirs(dest, exist_ok=True)
FILES = {
    "PixelArtistry_01_Image_to_Watertight_Mesh.json": (
        "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"
        "vCWeWWHrKN4jJNRjgpvQUn768/8DhccGyybvAAA="
    ),
    "PixelArtistry_01b_Image_to_Watertight_Mesh_2K.json": (
        "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"
    ),
    "PixelArtistry_02_Image_to_GameReady_Asset.json": (
        "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"
    ),
    "PixelArtistry_03_Your_Mesh_to_GameReady_Asset.json": (
        "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"
        "AA=="
    ),
}
for name, blob in FILES.items():
    with open(os.path.join(dest, name), 'wb') as fh:
        fh.write(gzip.decompress(base64.b64decode(blob)))
    print('    ' + name)
#END#
