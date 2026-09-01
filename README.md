# pezAnalysisRepository

MATLAB + Teensy firmware for the flyPEZ fly-behavior rig: hardware control, the offline
video-analysis pipeline, and the curation/experiment-design GUIs.

## Setting up MATLAB

Run this once per MATLAB session, before launching anything:

```matlab
run('C:\Users\<you>\Documents\pezAnalysisRepository\pezSetPath.m')
```

`pezSetPath` puts live code at the front of the path and archived code at the back, so an
archived file can never shadow a live function of the same name. Prefer it over
`addpath(genpath(...))`, which gives no such guarantee.

Several files this code depends on live **outside** the repository on the shared drive,
resolved through `flyPEZanalysis/pezFilePath.TXT` — `computer_info.xlsx` (which holds the
per-machine COM port, camera IP, and gate positions), `Saved_Collection.mat`,
`Saved_Genotypes.mat`, and the stimulus `.mat` files.

## What actually runs

| Machine / job | Entry point |
| --- | --- |
| Rig control PC | `flyPEZoperation/runPezControl_v16_2.m` |
| Rig, live view only | `flyPEZoperation/runPezMasterGUI.m`, `runMonitor_v1.m` |
| Stimulus PC | `flyPEZoperation/udpVisStim_v1.m`, `udpInitializationListener_v2.m`, `udpStopListener.m` |
| Teensy 4.0 firmware | `flyPEZoperation/TeensyPEZ_v1.1.ino` |
| Nightly analysis | `flyPEZanalysis/pez3000_dailyFun_v2.m`, `dailyExptTableUpdater.m` |
| Experiment design | `flyPEZguis/.../Current_Versions/Experiment_setup_gui.m`, `Experiment_ID.m` |
| Curation & review | `flyPEZguis/.../Current_Versions/pez3000_curator_v4a.m`, `Video_viewer_with_analysis_v4a.m` |
| Daily labels | `flyPEZguis/.../Current_Versions/print_daily_labels.m` |

Everything reachable from that list is "live" — 75 of the repository's 341 `.m` files.

## Layout

Three top-level subtrees:

- **`flyPEZoperation/`** — real-time hardware control. Photron camera SDK, serial link to
  the Teensy (gates, temp/humidity, cooling, IR and photoactivation lights), UDP link to
  the separate stimulus-presentation PC.
- **`flyPEZanalysis/`** — the offline pipeline over the video and `.mat` files the rig
  produces: locate → track → analyze → visualize.
- **`flyPEZguis/`** — curation, experiment setup, and stimulus generation, consuming the
  same run-folder outputs downstream.

Within each, two kinds of subfolder carry a fixed meaning:

- **`tools/`** — nothing in the pipeline calls these, but they are real utilities you run
  by hand: stimulus generators, template makers, projector calibration.
- **`_archive/`** — superseded versions, prior lab members' work, and vendor SDK samples.
  Kept for reference and reproducing old results. Nothing live depends on any of it.

## Conventions

- **Versioning a fix:** rename the file in place with `git mv` to the next dot-version
  (`runPezControl_v16_1.m` → `runPezControl_v16_2.m`), rename the `function` line on line
  1 to match, then commit the fix on top. The PR diff then reads against the true
  original instead of appearing as an unrelated new file.
- **Always work on a branch and open a PR.** This code drives physical hardware; a bad
  merge to `main` has real operational cost.

## Gotchas worth knowing

- **The MCU COM port is hardcoded**, not auto-discovered — it is read from
  `computer_info.xlsx` (`controller_COM_port`, keyed by hostname) on the shared drive.
  Changing the Teensy's USB descriptor (Arduino IDE `Tools > USB Type`) can shift the port
  Windows assigns and silently break the MCU link until that spreadsheet is updated.
- **Some files locate their own data via `mfilename('fullpath')`** and break if moved away
  from their sibling folder: `textN2im.m` needs `textImages/`, `textN2im_v2.m` needs
  `textImages_labelmaker/`, and the `Current_Versions` GUIs derive the repository root by
  walking three levels up from themselves.
- **`flyPEZoperation/pezProc_subfunctions/` duplicates `flyPEZanalysis/pezProc_subfunctions/`**,
  and five of the pairs have drifted apart. `flyPEZanalysis` currently wins on the path.
- **`logo.bmp` and the Photron `PDC_*` binaries are loaded by bare name**, relying on
  `runPezControl` doing `cd` into `flyPEZoperation/`.
