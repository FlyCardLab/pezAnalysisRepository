# Current_Versions — archive

GUIs and helpers in `Current_Versions/` that nothing calls and nobody runs.

- `graph_layout_gui_shell.m` — the graphing GUI, with its helpers `rotate_amt.m` and
  `vidMontage_testing.m`, and `Montage_Functions/` (`montage_interface`,
  `vidMontage_testing_part_1`/`_2`, `test_input`).
- `Video_viewer_for_proboscis.m`, `Video_viewer_with_analysis_v4a_vWind.m` — forks of the
  live video viewer for specific experiments. The `_vWind` fork hardcodes an `addpath` to
  a 2024 wind-experiment data folder.
- `Escape_tracking_gui_v1.m`, `FlyPez3000_BasicAnalysis.m`, `Make_video_outline.m`,
  `annotate_checker.m`, `make_dl_group.m`, `video_per_day.m` — standalone one-offs.

The six live files stay in the parent folder: `Experiment_setup_gui`, `Experiment_ID`,
`pez3000_curator_v4a`, `Video_viewer_with_analysis_v4a`, `print_daily_labels`, and
`makePezIcon_curationGUI`.

Anything moved back out must go back to `Current_Versions/` exactly, not deeper: these
files locate the repository root by walking three levels up from themselves with
`fileparts(fileparts(fileparts(mfilename('fullpath'))))`.
