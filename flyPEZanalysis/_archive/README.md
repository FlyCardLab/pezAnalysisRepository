# flyPEZanalysis — archive

Not reachable from `pez3000_dailyFun_v2` or `dailyExptTableUpdater`.

- `pezAnalyzer3000_v12.m` — the older standalone analyzer, superseded by
  `pezProcessor3000_v8auto.m`.
- `makeDataVars.m`, `vidMontage_by_experimentID.m`, `vidMontage_by_experimentID_PA.m` —
  one-off data preparation and montage scripts.

Sibling `_archive/` folders inside `pezProc_subfunctions/`,
`file_assessment_and_manipulation/`, and `graphing_and_visualization/` hold the archived
contents of those folders. They are nested rather than hoisted here because
`pez3000_dailyFun_v2.m` `addpath`s those three parent folders by literal name, so the
folder names themselves cannot move.
