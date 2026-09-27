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
        "H4sIAAAAAAACA+19/XPiSJLo7/NXVLARe7YXY30j9cXGe9jGbm5s4wO6e+amN2gBhdG1kHiSsNsz"
        "O//7yyp9lVBJljDY3Mbt3W4bSZWVlZVfVZWZ9cdPCDWsWeMDamDRmE9UyTzV8Vw/Vcy2eWqo8/mp"
        "aYptZTrX2romNJrkew8/Wr7lOtBKoA9s0w/GjjvDYwpKlpX0sW0538PHoiyEz8mXPjz4DX4g9Af9"
        "3xgNQ2zGv4PnFSaIjTxs25YvDRfmCg8D8wE3km9WbgqI/OdUU4Vm8ksUNCH68Y+kiW/9jjNtpDbT"
        "RM83mNvmA+nljz+TR643w148fPpkCWPKPLCc1TrIIvdH8hchgrmko4MRWIH1mI4pM/aL/t1lb9Tr"
        "3/XurrNfELoSokptLXn8Z7O8Lwc/mK/ry6jc16P7A9v8jj73f+necHvQZGYwuYlw18H+aZoFT/6j"
        "ykYz+0BTmN//eBPyc9BShE201K3QuumMuncjPlK8d0XoiPzec9O48twV9gKL6oAUo8bU8UJF0Zi6"
        "y/nz6dT1WFI1HqnINYSWLLcE9sUdyB4io0Fz10PDvw4KtMZPLEYRVbLaR1Rz2ufipnf/maq7G9ck"
        "Ul+seyTQcClaRruC7pGlrXWPWEX3bCE8ZMDjz70hcGIBoxZ9wGcMUZLE5uYT/a14RRJb4ou8UjjH"
        "EXHtzVH9kRlPQrqZ5bjjR3l8M3bM+Xi+kqWWb85xgB3f9fxGlgqNtWeTRosgWPkfzs4W64cHy3mY"
        "m1PcmrpnF3Rcfe/h7N76Ydry5ZmHfdd+xGdL03LOpra1Godm+KxetzPLw9PA9Z4p9VIwDeazP3/a"
        "nJyU/56s2QMO/PGjaa9xljAvESA3vVlYY0LH2cZEEwQr0jeH6tS1XcoHf5ElKRXcyUP6QpXlRok+"
        "0HP64OehuVzZpXpAFlk1IFVRA2wLyailB6TX+yCUx/nCftu/LLDVhlbd8XilkwMW+K18HLCqlbuy"
        "TeC8YGwtWZe0kvmkHYm7cHV2ZLyZudyzQhbbFYx3LGToSBWl40YdHaRIDPC59QMUCiNajJi1Wyrz"
        "JV7bWb3vuN7SZIVC3EJ7+Zg+yeA0dZ3Ac+2xOQ+wN37ADvaAj8ioN7Ft+AFekdGxaDem8wd4lMXe"
        "D8mVKMrcaPzpAs/oww+coTVm2HEtnzQVX3aSYBWQ95KurvswxZ41K1ucGWpdxZhZm4lqLcUov5Ni"
        "FCVd34Voc3p4oXOO8yUWrVXeyS1nGaWOWDMupNBqa8br5DKUITEjaqYXjIEAU1DphFeynTSwM2Pe"
        "VpASUdJyUjLA/tS0MdCg6g5GfSFp15IR5b1khOXLd5YRcGQ21ieioB+U0DB8U0dmhJa6hWws13Zg"
        "rWwr3OBKQJSxuiFxWH3pPuJzc/r9wXPXzqyE4RXRYPlXrcLxcsVlM2t2bdtc+XS0c9P2cY6SsUyo"
        "r5eJycPYIwQw7XGJeJx3Ln6+HvQ/3V2OB93b/ucOX1Z0vV3ZJS3xRXu3netuQQc7sVdL0/9eIIqd"
        "4c/VrJUgHpjgbXBxBe9Iya8Z6Vp++GQF0wXppmzpqLO7eqpe20USa6l/7fWs7jpjKk51Zp4aAEGq"
        "zNXQR+Ctt+hiJ0us8MNXcrbErCvLOTuwApvCDhnmAwqZEE14uvRtfLYN9q1jg8i8bbNwor3BM6Z9"
        "idDJgpwTultQR/fkqAo/lQmcqtYWONb4SPX8rfYO/K2aapb6ouyuxrtqeElrH5SGZ7mkCp/lPZ2o"
        "dW9ZfjApZRa/qrRnRtNfz2jUl/DrOhOipBq74LUteueq3dzZA7sZEz4xDsvpyDBUFYdDK+JJ+bIz"
        "ezSdKS5xvzP6T6rifCsCy8j19mSMHa03x/KMzxpXvZvuWL4cX9+cN9O/R1fJj6vzX5K/++f/kfw9"
        "HN0kf38aXv5X/IPP5IJR3SePER5bztzNgvPJ4SRrFrL7t/3OJWBDF7Lj3t1Vn4uLs7btyrhM4V/P"
        "3BaTi85td9CpgMUrTEyV2eWLfi1ClExKDfL7O6N/RUrX7hBcrWBRoEWLzgZqdbDA1sMieFUP76tn"
        "OUoSWlzQiUIXrjO3HjJYoHgWR9EoAVV/haf5Q6e5+0h8BjUraEG4279xhByekNGYquwbePcDHp4q"
        "LcOQVUWRZVFRJVXVm5ufPYfblqKqaKqgqG21bcDnuc9+JzajpWiC1pYF0dBEWZTEzEd/bpwYB6YH"
        "7nohZkJL1FXZkETN0HTD0AVD4+JGPpQMRQB7K7RFRTDEtsLFTmgJmiC0VYAKDldbk41MZEsewd9d"
        "d5ndz60xTfDh/1vDnHhOGfkJTpqkyG1B12RNVwVDKhqkSj4zFEPSBVHP7CIzYyQAgQQwB20RFqpt"
        "QxT1PDWeKDV0BV4r0KeoaBqQsJQWPKaDxyYdO4dIDjbDjT5h882cvhAFQRA233hrP1gvecSy8Zz0"
        "cqrmxuJRPcFsr6X85a64zyduENCJPd2Yfm6kAkOIxo3pB2hkgbzfEj2PrqxwSb2KRH42NiOZH6uG"
        "auiS2paVialoiqJPtIlqzuWJqc0meK63HuwJqxiGU+zgAr3gL9yna49qKLJuzch9uny/SIIPJJ38"
        "X6Pgu9ABhO+KPhhgB7yq29CRagQwxg2zyY1dQflJK1E+Ef8Lzfzz54LnVIQ3Hv+Zm9xSmdu2V87z"
        "J+a4phgbur9ejIhYgIhYgEiuw0L+/Qeff4msFDCZ5ZB4Fyt4Zo846ZvFzLPylgU75sROt703RJm0"
        "uTeDRY7PInbu+MzuJx8Ei5D4omiGAskf2np1SYOTQqaARYP1YDnmxu75kvCNZdox3/O/IrgPv2Mb"
        "BxRWDu/Gg/X70q1LrWUsa57p+CT8Y5NkL5lxgW+1+WawVM97LjgSb9JTkWzwJYMvFxypKNDiteLN"
        "2PAMQVKyv7bYdiTGYeV6wTj20tgeIl/6w0ZXsQf8ge207LRMzIdPfDbxJZ4Ccw3BbkyDtYfj8NWy"
        "g+K6C3eJbVEvyEzcQaR7GKTi146U0mS5etS5WXBK8LlTuF0l72LdWj/cPW+XtU2vjQ2HP4SwrBI2"
        "rSW2srRNKCiNf13HxiGFUSJrSl7SyDyN3FvsL4pFS1L2JlrbHEiL4uuFb8t0DHUnQRrd4ceCY4Pc"
        "m4J9XFgpHZYkMGxUi/Unpm9NG2wwk7aFKJj2A7g9wWJJgw02QDaCBYjKwrVndF2nVdlCbuePzwDE"
        "yCULJ2a/rVxSFKHuoYaya0nZRTA0qxoqcGu4Hay92eYn2dquKDMHdtTGclSFs7atQu91hrvkSqe5"
        "6vaHbKL8brH30lvF3otSW33DBEP9jaLvBeNwou9ZB/eQou9rWTaV2fRtwPJ45i6JqDFLMmkHsfdl"
        "8bbqlvG27drOnrp1vK34XgG3hnA48bZt7V8jurb9+ujadpXo2p2kW9RfxohSPdZW3y/fon0wvC38"
        "C6ZbaFp7/+kWmU62SLcQ8mG3dKuZ2jLLeRheylX9xvpGoGbmtvZeRqCtHU7ShXRYi5NNXqnl+2wT"
        "4bqw6ElphfwKhtUSQt+5Qanqz6zLpbr8LMr1GLq9dS0CTtwzGdoHlHXaMjxQbacFACA30n0I/FHk"
        "JXYemR5GgYuWZjBdoGCBUXyIhGZ4boKJRitrhYEVMJrghflouWtvmy3LAP8IIjW8F1x4qe5SUaq7"
        "IAglqe6GUlh459Mq3Lp/qfZOJotdlKrU3pGFV3Cd/u7Vd9hKMPtOTNeqL8NpMN84XCDXXxrXyOvf"
        "4rhFUw+wwk9RUPrbFvTR9Pes36MZB1m/J6t8au21i6qsbaW1abzbOHvexAIrPd3Nb6WDMLxYO0hU"
        "WA+0XWXnUla234Yw9lQ8KCf3pQqBF7Cvypvh+Zqae3JYGwj5+a1ZNygIeX0sjUPNDWp1PJmL2t6q"
        "B0EHZ9t0mqkdRJT/DmoGVcJjm1gOgFOLwLsvH6TmtyQJo9y61/g2s37j+FKSkSlkWKmK0PZ1ACRh"
        "Twrhtn/dHZcuGPnv+eqBraxxCJLPn82a0r90HzBw5iOsf8bhzvd4vtqN8BPcspL/gN0lDrznMfYD"
        "a0kjyM62QCCjCDgwd6EYqqC1zQ4sPWStQ/w91BUzZK5mOGdie2n5gJfUhCKxtYHUSiUH5a03rqR9"
        "1RycPLy2TkJeV7BlEw5FV7wwvzUVxwSEcO7gYBea4twa4PkdDrLaIo01j+tZnFXpNKMd8jB2oRy4"
        "aGyhDZhKHaVk3YNzoHE2rK9xz5ljDzvT0lxivV3bOciWiagp9zupMQiKtnTXutgRICjo+n6LoJBU"
        "4d3E8MA4Y4tYMtTrbv+2Oxr8Wi2Up60c2G45y6h1BJfJhmJ3qJuZghHN15aPSJfuYxs/YpvNPA5z"
        "pMY/xjP84GGKHlteb0L2YceR+CiZRt4Uj4G+/51kKGRxbZirlf08pkUSqhauYLLRM1rgOmKgkXvV"
        "/1ymCVSt/jJB2L5gjCTvSBO8SkLoeV97JwENJF2OH2130++MKtY3lrfat5u7U7A6K+sHMfi1cTgM"
        "JZDl01oWfOF61u+uE2xWogyFcpug2B+WT30dLuC1Y9GjmI0OymSTE3gR70peuM6MJvqAM1W2q9fO"
        "iqdRN0BWqyedO4guYipCl5nr0iLg1JxKezfYhnh4RwmipIsHcJYAaEgHFVPIFZwqMpgP64h2NCuL"
        "YP16mvLWeVKSekgSKO7dZZbqVr4wnQcbj39Utneh2s/naRaAZVeWBUSRD1FptNuHoTSEw6qExJH0"
        "WrXAjZYobxOvlmWqDxlAJdqKUwc1TZkjBw+RFixWV2ImCkcy9nt9kaS9X1anqop7DTPYTUJOzVwg"
        "nkwZ24l2eFDlrycz69GaFRF4+LFz3x0PP51f9j73LrvD9ym3UzN5lJWECjmc+eC3T3fd0csn6jor"
        "S5pWd2u8puFv7+0AbQdV4FNFchiKnTOBWx+ZW06gj6eu8+i5O9kJHw26Nze9YUvKboXPrPl8nfpk"
        "/ll9DDLb4pvwdnuUXgGlRhReuM1Se+3gYLzVVDSeaLWE8Sxm4g0sdrjBrucjcbrLVfAcL0VuaHxc"
        "kspeliKk1c4qVLY3yvqeNMmO4sSEN4sTq3R3V+mU1kp52Ob0iN0srnJ1yjZJraJSewFrvOI6KePd"
        "roQQ9LdKamUDPvcet/tWKa3aAaW0st79YV0oRYr07PBGqRpZrb5FUDiMG6VEaac3SuWGVu9GKVGS"
        "uOEwL9XUVgU2aFYVK6jGdsYw1wuSk/cVJMfZYqtd6lrX9VyYrLDVyjNfy32Lezykg4u9ydbTruRP"
        "P1rfYYkwfnLt+dgDn3ds/sCtFbPdjOKd0y0k2YrLO1bpZb2yYQjpTm2F8hliXqYoCS6A4iP3li3l"
        "zws/1WtXq884HfWOlWXx/crVa9UvfCRH+37tuxe0nWQn76gevnpYWR6bHFnLYc9V/GN+tURuoAnN"
        "gksS4eoJbJXyf8zzlTkbz02y3ifvWHwaD577FMeJZGNPmFKbm6iWyjrv+hPv+8x9cl5IFFV1dm2r"
        "VAkgzayGjZp3Mkq7zBSl0ZM++roWhEkbfQx3dNCVOcWIDJ2oTP91SaR/+QtKOpEEUUbufG5NLdMu"
        "6O2r89UhFY585OEVzCZw94zyO91f+tRDk2eUbDW10GiB0T0JAOkAXn7gPSPL8QPTJp4q+FfT7z7J"
        "CF3SlNGkD7S0fJ907TrQDwH+7K5b6NZ01iRpNPrsAwLCIWxOF2gOCAHgwKXppXPXhrlApECq0yL4"
        "npxEyJ1FO1ubW1MnJ1+dU/Tbip7GzAp3ef5xtF0ySm5n7aWOjuPJiMCho2gT6Zji+fJ+VAVMd7cL"
        "mGAbbVK0JC7RH00c0blKssq2tK6a+HPMxZE5mY5wLb+Re1ssq19uzseTk5AQ4Vsh3L8C0jtLq+Cj"
        "n4+YjrDnRSZXQPdVsd0UxVgNohVxQggusT4jusUHlZmb0epzfxwr8N844ldHVHmAyFRVnFFe85h0"
        "NahMlVA/zuEPpxQIFOsqMAAjEjXrBKgzuCiEG30Dn+TJlAyYALu1pp7ru/NiFJfxFymlTpXzeF67"
        "P+hKH1Hr+9X5rWg1koL3zKfWgxUs1pO1jz2y+QCIQkdLhhhPrvd9boOXE2CAbgbYB+ab+2cLDAYs"
        "5D/a4VlRd1RrioaEvsXCQb//ho6IDUutZGoVreA479W9uiyCLCqvuM5RVKTMieKer3OU5X3f51il"
        "hF/1rdXSex0rdKVXDyGILhTk5xf1+zfdzl29wKMI4MsBR/pOAo7KLqHcItwol1J9YDXZXnPlJFsi"
        "dqs7JzM1ZstUg7oz1SAK7X3rBuUAdIMuvJ1ukP4n6AblAHVDbh+5bfyvbqitG3iXMlpLemh57ro2"
        "Np2ytB5Re+GOxXLdUPNcQ93TuQZXeEolqzAwNVcVZPO2LHii1r1hOZoIdBRyEynDFUcSHDfe/Da6"
        "De54C7ambwqrqr86AkfmFMOpuC+ZlQCt9kXo9YIeZG0H25Lb7C8OcUC47hudgG/kT1hTxftaZIUW"
        "f0BsYfI+2Ul6TU26HXX95y7XWvrOHCrV2Lc/1d63P1Va8VbbjSNV1och/E/woNR9e1A1omz1ds4m"
        "6f/rOtV2nYxdBHxXigZ5RcC3rB90wLeu/YsFfL90KLTT+mi1j6TePNS7BkI7C/Su0+fbhXnLklK8"
        "1BoGXml6KHiZbGh3FadhY0u3ls7YV9nF4WiQW98nKUKcdwVaQxb2HbVZvvSJZqteISCb3oLbKFnl"
        "hV+glRks4rNYH3xb15lidDSlK8D4G5Bad7kkf8+OS3lO5V6YNYDmjk/Dz79YweI/1+asKu+dipVq"
        "d2Q2DetxnyK8z+VYbAbce+fivdYdK7zYqmzmSW2K9Y9ILm79wJybp+aTOTuLjrZOCYBT0uSUAVMv"
        "FqrF8oUqa7UK6iSiIsZnjAQZxCATy4lnPiEyEeXCwalshZdgDC8IjNJUB+2leuC7lYhdhB2S78Yi"
        "nzNPiiRC37is2KTfVz85C3uV6vRKkkBf6vW1K6gadOCKp7FVwHLUt1Sr7y1zYgsUAI+7K4g9aXYa"
        "t6sj73mh3k7gpVjgrzyM0edB55aO68vI+uyWinh+Y4+2uaOpMuFNf+V3rIqGVt/6scH7cr3bAhTp"
        "vayfcSDWTxaEfVi/8nkvFALa7PQLucw9IEsFeqPqKRWNtVV7cyJr8jZ+SWEgbbPAWrJ5L5KQeaWx"
        "1yCxkbo2KRHvByVepxxLFh0oOlqa3zF6SoZbbkDz+6A3/cuRacGKaLQIyQw+87LMlEoZYdlCvtR6"
        "138p8vvIF8vVLxmKaK0wJiuB6oull/YqM1Bf3LFk11jvrQ+kfeiDlzi1UCMkDU+hZegTR223VgvJ"
        "6pCtqLapDDY0g8rKfOaHlP1VZHHpPmfRS1AjApMKIOJTIatksq9Z3LKARJ0TTZZoHyXWPglR45Wv"
        "TbQPrHT/hoD0zz6jktBRtAou103GtldFt6XaCqnyZdEcfaS8lz6SDu8qaFmQD2o7mHsVdJ6L1ZiL"
        "yfdxQCgZcwl/ygLfM70y/eAWg9U+f760gPVLKyxv8KpSxXay7qxU0zfd79WZpdwS8qy8M57dFcMq"
        "e/NVyzjhBXeV17SWmwrqXq1oKagvcjEan9907y67g0ahIZCKzYCWLO8AcUQxR0dP2J6h2XplW1PQ"
        "/eiRUG+K/VKtzyRoJq6S+QjS25k9EirMqspSpVvhMkWN20I9WdrV5ZpVlG8z/Xt0lfy4Ov8l+bt/"
        "/h/J38PRTfL3p+Hlf8U/ioSy+t1yMcJjy5m7Df4uD7+iQ79zCdjQg8Vx7+6qX7h1VLfQ45aYXHRu"
        "u4NOBSz2bFqrbBptPyk1yO/vjP4VKV27wzAvlp+YXFQtpFYHUYbta3rYk59Tay0iz84yuZ7j1PVm"
        "e2g0SzKci1V9upMS5hyhIx8U9IzEbYWScSaXH2nJ0paxetlN+0q1AtqZFmVFrtkqJ7Ztrnx6Qs2P"
        "V0xMwE6vo83m50b2dIiDwHIeXp1d/JcEEsnlovuvR9TVoOlZ/wyf/DPaQwo3/T3so7+jOckuo3//"
        "E0HXP57HK9dyAvgJzU5PT5P/Eigauj6H7wgDwT+2+wTrPytA1pxkDiNv7RAWQe4cLemONIWBdGj0"
        "N9JKlTXyj9Qky2b4b5JuixbYw8fh16IWfS4Jih6vNUnAIEnXkn4GHDE5cz0SxMlxFlr0bYD9ANgV"
        "FqCEZck//wyTI+/J6FA4ug8nJ8DdHo5+IhtAhrSZA3e4T+FLGAjplZxV+WuPhHzEndDXMxzAiriJ"
        "JjBm4CM3fEo+85uI0JtkWwfWErcAzVtk0RxsROcP/jID9B3jVfjwaeHaGE0XpuWwC2mLENSjQ/L/"
        "PSGzaQE5rKAZZnaHKGKf0PHJChbxEfS/+Ui+RPcejA+NXNeeuD+iLO3NMzlCDIIK+pZed/ENAX5k"
        "xlqoFyCQooDEZsBonOeEFuH4Y5JMnlemT7Ln0NFF4Nl/Oz+OEXYwUR9kwGGLCI2Q3t9sczmZmeO5"
        "ZdvfCCaSgEjSX5iQvnT9SA35QEQh7Aq+IO/8pWnbiBAOyC1H75Tw3cQKs9pbZOhoAcREU9v1gctB"
        "uBwqJgSzJ9Ohoal09EcL150BKN/G+BHc2AjNdOPjiBQ9QsoxwdLDk7Vlz/yQa4DWUoSAKtyeUuqQ"
        "NX84ISYRMph4sjENDekLKw0VOAKy23Tbe0w/oWXgvoUbPMeUh6agrghhgYLabchgG7swTfqdHwAR"
        "w4HOskQGG7QCejgBjRz6BnIfbTzHcw+EcexnykskcAmtLDwNb5iegT4CAXEBKJp75sMSoABd00j3"
        "b+Y6cL9Fk+1FRmNh+sjHK5MUkELwT5AneIThRzKBhB4pH/8fQGoAysR8IKjEcg2v/bggHyLlq4hE"
        "+WFs8YkHqLpLINxJE8Hsge4h2gg+MIH9nlBUywoYO+oVRGNFRANYgZBg5jr/FsQsnNvqColo2kDB"
        "yAZm5juakSMxYs+WStQkEAD89OMmoOdSfiR8aQJ3wRrJayUb/mWGdOtiHFrGklYqxpGxpKKk7tqU"
        "6vs3pQGwGTUlrzSmiAueVpiJ944YJwk4iaa004od5PDzryAsU9NOMtvjFGZimMEKsbBPTlpR9vRH"
        "eB9Gxn91xBYiIY6hONFyPUQ8QBORhxQN4NgjcvuIg0ji/YqoKqlFPICwTSZQiUYn0fbsYwJhtfZI"
        "wnYCQm6hiwWVc6oGqBxTBQZNSxJcTk4+JMH/f4/j/ptxuP/f2XIVSgsMEgYROzkB+YbR08IlT5se"
        "J5Hr2OdM0rYT5/PsW0y0L8SmwGIQVLr/1YkT48/SHuPpyts8GD8NRPETC79ktgYjvUmcBPM7prqX"
        "QTL5KFEU7IfxvniyCU61aKhj4XWonVMY6YYKACE7Kj5nSwWMkhtpDqLyQDGH2FOkW1GORej9RWVc"
        "PHR9/+kD/ZYM0AF9EetYdtpjSma4ktQd+IInvhXgDyiOe6XXC52a0SckS5989qu7Hq0nzGdPT08t"
        "6D6AhzST//9mVyqkzS/p1z/oN6uFZVurlW/hCXbIF3f4CYxwQKh4tSbq/sqDFZyftntwW3l8zpyk"
        "WTSqczDRkVN0C45Ex5yN8HQBxtoBNgOOyTJfkzi0pysXzCCZsYlJCgogWugwJB2wZSLL1Nd1wCBi"
        "3KQ+xakPRAdJi6WedhGKPNM3YfmPYL1WpGyDC9MLM7l0HUCQuhOkw6ROz5NJrNdiDeK/wPYKfERS"
        "fgdeg4DGeABGoO+A+WaJawpza8IXpCwPOD5L4JwlhpE94g9fKXG5shC15YkEQYXW9SA1gmzXJGyW"
        "OgIhxDAABUUBKCk8Qh4/XHtMcPBEFBaBvcDm43NI2bB9LG2xd01liSoh6kQlUxR+zYpd7HyGzhhp"
        "EssfyEEynxsuVwgmI3kRnCIBjIx3KHR0yUQLloS+xFW4ZPgrOMarlQs2KDPh1cSEaUIa3JuBh10n"
        "22AVPqQNpk9npIk5NztkVxnWWxPQDQtrRVpfW8HH9YQRF1pkg7ZjtqK5spjBA744PSX/fElMGJUo"
        "YPyIzUGWkkJWPP0bV+1AR7e9UZOaUtMIG6O+93BczQ9SduMHcU86yx0hRajtB7H39eXdIGOXbtAN"
        "sKYDsn4UK52Y3Mev84DO41km8pTM72Yn6ESejeNQ/qgWlBTWHB4HbpiikAgWhxXLirwQpvv27dtX"
        "B9gGRcMkzy7c1bMXnjFPj8EHl+RTuiEA2jRhKvLdPfZocTOXrgGITwia+AEWCQGeNalaIot7WG+D"
        "9BMPHbTcMwI6+dDAncAilawRicBDf+E2APFJ3HnwZHrhsggWCi6QhWw1zNzpmihDur4ICxmF1WW+"
        "NoZRk68NuhCABTAQMrLD8TtqoMi+CQwk8Cx6J2QTPpraa2oQ4tc2CW4P+6AKmpDBj5zGJsW0Sfwn"
        "a07+xXRgq/UEJmXRRDNiJa3JOoCHPnlIKUpXjWdkKY3JutGFRZ8fb3rE2IUrS+hlRUgaRESi/T4t"
        "3GV2JECk+dpzoMvQeZuB1+LSHsldlygtHAeTTYY2jS/k8alxIvbYnICloaMJ5xk8FytaidJJWKUz"
        "G73yF2QfYIIjkpF1ISwdmQF5BAFyyBYQNiYamvS4OVDqCo0+dtGwfzX60hl0UW+I7gd9ch3KJUxl"
        "ZwgPvjaa6Etv9LH/aYTgm0HnbvQr6l+hzt2v6OfeHbi93V/uB93hEPUHqHd7f9PrwrPe3cXNp8ve"
        "3TU6h3Z3fWDpHjA2gB31EekyAtXrDgmw2+7g4iP87Jz3bnqjX5voqje6IzCvAGgH3XcGo97Fp5vO"
        "AN1/Gtz3h13o/hLA3vXurkjUUfe2ezdqQa/wDHU/ww80/Ni5uaFddT4B9gOK30X//tdB7/rjCH3s"
        "31x24eF5FzDrnN90w65gUBc3nd5tE112SGVQ2qoPUAb0swi7Lx+79BH014H/vyBFIsgwLvp3owH8"
        "bMIoB6Ok6ZfesNtEnUFvSAhyNegDeEJOaNGnQKDdXTeEQkiNMnMCn5Dfn4bdFJfLbucGYA1JY/bj"
        "FtUhGxbmp0iVbxwYx9pPSqsfq8kBa6Kj06uWU7XN3Df8E2MoYoCqkKj8NKszaS3n/ohro3NhpXk/"
        "hpiDlSY9p2esmaodXJBppF4KUsyDlOqAFPMgpTzIakNWUxBybsjpPVlCJWCaUkI/Q8kDe3mwmlpC"
        "vxRknSnRtDyxOFhK1YbcLhlfStJa+Okl40tB1mEZzSgZn1RPSjQ5/30qJGlSsFANmFrWlMMyn/u/"
        "FKgCLQ0m5sHiCEsJMD3VJqLBGSdPNM47Fz9fD/qf7i7Hg+5t/3OnCHSqSSSpDHTKNWHlaB40Q0iZ"
        "xMiPWpRUnk4tUqeGlnYu6MX6tBqsdD4krUSfVgLW1sqGxEO2BBq5lbrE6DC3fW8YouSuaz5UQyvm"
        "XElpc4CS+MQCWO2ylpLCsZVs9BYXqJgGrfI4WFI4No5WTC+AJnEYWeRAEypB08vYRarFe6KY2iKp"
        "zRMLrRY4SUoJl+c+Jk+MsW3Mva8FMOUyhmOApgorvHm1AJxeiqKxDYqKUDabsiDXmWEp9VxkQSrx"
        "/qroPZGhGQ8aQ75q4NTUWIvtMsOWgiPXWhYAS75m7ncQyvAtxU0TyiwGr4tycGrZUFMXQa4wUkbJ"
        "82BJdaiWOlM8zmKGWUU7McUzmeKweVNWwzUj5TfLYHK83kpA22WKhNdRJajpSoCjD7ZxI0VGk/Jg"
        "cjz0KkD1UpnldVQJqlim+hii1sNV4kDl4VoPaupRi1oZrulkxdWaCgAq5QDV2gDVcoB6bYCMIBll"
        "AKuZ59Rb5zXlOcbl4PQycDyHohRceuNOak95YxWrQRPL7Z5Rz+6lfibHI5S5y4dCp5URYF5Lmet1"
        "lUAzyloyyc0ptBM+KFkobcZkclZBTE7daKaqDQ9aOgVRxmIBPKkMEyaXqxp2cllLJvOmxspBTpeZ"
        "PABM4kEZ0GR3kJ6Op9uDG9fM5Y9ihivT8zFKbgxF10nEEVOLiFySQArTZA6pMvnrop7J/snUruRk"
        "D6W1jTq63uCkNZRcIcoZBAms3xZznc35FRX1hcDcV2DOXlIUox5G59x7+PTec6eY3mvzEvqKlLmy"
        "iMVfEtiEwbZRhr88b+sGrjcEIz+CaxygCxpyj67czy/hLstC9vIkNrxbfSFPJsVd79SlvZDHfECj"
        "A9B5eunUi4RnqatmKme1sz92ijtHbj/R+/BQj5y9RiFeHzMRZPwRqIJRxDrtTPXY9q45h60HHQ/i"
        "Ij5Gq8D0kiQUYS5msoR3z/RsEd9E5YTxZOGlMFUoL4ksfRU9e0ExwztCGfom2AtjUhN9vWIgIhMc"
        "eO/6QXWNJGby1WCoG8ELrH4VykVDvbjSmOG5ThDfLs1UudscdWL9pq4ztx6SgIEG/hF4ZhLy0Jix"
        "4Q8Nf2pSYgjp1XQNdz73aamD39h8eakF/Ka3FUERNZ1Je4cFBLxSRZW8NVRD4wWFNOYevSFm9hl7"
        "5PiXlplqKUYrHmfj88fhOLz5eOXhRws/xVGpRe+j220F5v0tDsyZGZi96FLNNEWSvv4Z41UPsPCW"
        "eGaFraN4j5BQjwluQkv56c//D5m1E3sW7wAA"
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
