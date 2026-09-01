# Photron SDK — vendor documentation

Reference material for the Photron FASTCAM cameras and the PDC SDK the rig drives them
with. Not used by any code.

- `PDCLIBMEX_EN.chm` — the PDC MATLAB MEX API reference. This is the one to open when
  you need to know what a `PDC_*` call expects.
- `PFVHLPEN.chm`, `PFVVersionInfo.txt` — Photron FASTCAM Viewer help and version info.
- `FASTCAM_SA-X2_*.pdf`, `FASTCAM_SA4*.pdf` — camera hardware manuals.
- `GigabitEther_Connections_Manual_*.pdf` — camera network setup. Relevant when a camera
  stops being reachable at the `camera_IP` listed in `computer_info.xlsx`.

## The SDK binaries stay in flyPEZoperation/

The 252 `PDC_*.mexw64` and 77 `.dll` files were deliberately **not** moved here. The MEX
files call into the DLLs through the Windows loader, which resolves them relative to the
process working directory — and `runPezControl_v16_2.m` sets that with
`cd(fullfile(repositoryDir,'flyPEZoperation'))` before it ever touches the camera. Moving
the binaries into a subfolder could break that in a way no amount of `addpath` fixes, and
it is not testable off the rig.

If you want them consolidated later: move the `.mexw64` **and** `.dll` files together
into one folder, then verify on the rig that `PDC_DetectDevice` and `PDC_OpenDevice`
still succeed before merging.
