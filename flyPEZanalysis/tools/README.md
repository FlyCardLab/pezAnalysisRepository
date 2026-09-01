# flyPEZanalysis — tools

Run by hand, not by `pez3000_dailyFun_v2`.

- **`template_making/`** (was `template_making_code/`) — regenerates the fly-detection
  templates in `pezProc_saved_variables/`: `templateMaker3000_getPoints` →
  `_optimizePoints` → `_generateTemplates`, plus `_gradePointsAndGenders`.
- **`montage_making/`** (was `tracking_analysis_montage_making/`) — assembles tracking
  montage videos for reviewing results: `montageFeederFunction`,
  `vidMontage_trackingAssessment_v3`, `flyRotate_and_center`.
- **`apt_tracking/`** — `APT_points`, hand-run analysis over APT-tracked data. Related to
  the live `pezProc_subfunctions/vids2track_APT.m`, which queues videos for APT.

Note: several files here build paths as `fullfile(repositoryDir,'pezProc_subfunctions')`,
missing the `flyPEZanalysis` segment. That predates the move and predates the current
folder layout — fix it when you next need one of these to run.
