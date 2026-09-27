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
        "wlvimRW2juI9QkI9JrgJLeWnP/8/bwfJcCbvAAA="
    ),
    "PixelArtistry_01b_Image_to_Watertight_Mesh_2K.json": (
        "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"
    ),
    "PixelArtistry_02_Image_to_GameReady_Asset.json": (
        "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"
    ),
    "PixelArtistry_03_Your_Mesh_to_GameReady_Asset.json": (
        "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"
    ),
}
for name, blob in FILES.items():
    with open(os.path.join(dest, name), 'wb') as fh:
        fh.write(gzip.decompress(base64.b64decode(blob)))
    print('    ' + name)
#END#
