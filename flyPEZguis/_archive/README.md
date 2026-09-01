# flyPEZguis — archive

`guiDispatcher_pez3000.m` — the launcher menu for the pez3000 GUIs. **Already broken
before it was archived**, which is worth knowing because it still looks like a main entry
point:

- All five GUIs it launches are functions that do not exist in this repository:
  `Experiment_setup_gui_v2`, `print_daily_labels_v2`, `pez3000_curator_v4`,
  `Video_viewer_with_analysis_v3`, `graph_layout_gui_v6`. The repository has
  `Experiment_setup_gui`, `print_daily_labels`, `pez3000_curator_v4a` and
  `Video_viewer_with_analysis_v4a` instead.
- It builds its path from `'MATLAB_functions'`, while the folder is `Matlab_functions`.
- It gates startup on a `version_reference.txt` in the repository root that is not here.

Launch the GUIs directly from `Matlab_functions/Current_Versions/` instead. If a dispatcher
is wanted again, write a new one against the current filenames rather than repairing this.
