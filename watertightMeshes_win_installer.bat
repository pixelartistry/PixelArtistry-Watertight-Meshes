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
        "CW5CU/npz/8PeQMeXxPuAAA="
    ),
    "PixelArtistry_01b_Image_to_Watertight_Mesh_2K.json": (
        "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"
        "hKbyw1//HzssVrYU8AAA"
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
