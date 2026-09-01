# graphing_and_visualization — archive

The `graphing_pez3000` family and everything it pulls in: `graphingFeederFun`,
`makeGraphingTable`, `prepDataTable`, `loadDataTable`, `addPlotData`,
`exportVisualizationFigure`, the 3-D fly plot (`make3Dflyplot`, `loadFly`, and the
`cad2matR2/` CAD reader), and helpers like `mArrow3` and `colorMapMaker`.

Self-contained: these call each other and nothing else calls them. The one live file in
the parent folder is `makeExcelTable_v2.m`, which `pez3000_dailyFun_v2` runs nightly.

Several hardcode a personal MATLAB path (`C:\Users\williamsonw\...`) for `export_fig`,
`mArrow3`, and `cad2matR2` — expect to fix those before any of this runs again.
