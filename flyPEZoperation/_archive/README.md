# flyPEZoperation — archive

Superseded code. Nothing here is reachable from `runPezControl_v16_2`, the stimulus-PC
listeners, or any other live entry point. `pezSetPath` keeps these folders at the back of
the MATLAB path, so nothing here can shadow a live function.

| Folder | What it is |
| --- | --- |
| `runPezControl_versions/` | The rig GUI's version history — `runPezControl_v2` … `_v15`, the per-rig forks (`_v6_pez3001/2/3`), and the experiment-specific branches (`_v8_SAMtesting`, `_v8_takeoff_only`, `_v13_retain`, `_GUIonly`, `_MCUonly`). The live version is `flyPEZoperation/runPezControl_v16_2.m`. |
| `photron_sdk_examples/` | Photron's own SDK sample application (`SDK_Sample_EN_run`, `photron_SDK_WRW`) and the `run_*` / `sub_*` wrappers it is built from. Useful as reference for how to drive the camera; the live code calls the `PDC_*` MEX functions directly. |
| `stimulus_legacy/` | Pre-UDP stimulus presentation, from when the control PC drove the display itself. Superseded by the `*UDP*` functions, which talk to the separate stimulus PC. |
| `misc/` | One-off utilities and experiments — fly counting, release control, disk-space and photodiode measurement, video compression. |

Two files here read assets by bare filename and so only work if you `cd` into
`flyPEZoperation/` first: `run_uicontrol_interface.m` and `run_uicontrol_WRW.m` need
`logo.bmp`, which stays in `flyPEZoperation/` because the live `pezControlLogoFun.m`
reads it the same way.
