# Matlab_functions — archive

`PriorLabMemberCode/` — analysis and plotting written by previous lab members, kept for
reference and for reproducing published figures. Three folders, 68 files, moved as-is:

- `Ericas programs/` — courtship song analysis; depends on a `BatchSongAnalysis` toolbox
  on `Z:\Erica\` that is not in this repository.
- `Martin Programs/` — escape jump direction and leg tracking (`Escape_jump_dir_plot`
  v1–v3, `leg_tracking_gui_v4`, `leg_tracking_plots_*`).
- `pat_test_programs/` — 55 files of exploratory scripts, several named for what they are
  (`functions_not_using.m`, `testing_idea.m`, `random_functions.m`).

Nothing live calls any of it. The one connection that used to exist —
`graph_layout_gui_shell.m` calling `Ericas programs/plot_data.m` — is gone now that
`graph_layout_gui_shell` is itself archived.

Expect these to need path fixes before they run: most add
`fullfile(repositoryDir,'Support_Programs')` and `fullfile(repositoryDir,'pat_test_programs')`
against a `repositoryDir` derived from their own old location.
