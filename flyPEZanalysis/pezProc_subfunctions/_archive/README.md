# pezProc_subfunctions — archive

Subfunctions no longer reached by the nightly pipeline: alternative trackers
(`flyTracker3000_v17_jaaba`), visualization feeders (`analyzerVisualizationFun`,
`locatorVisualFun`, `visualizationFeeder`), the false-positive SVM builder, XML and diode
parsers, and small helpers (`parSave`, `hotFilter`, `golayDifferentiate`,
`points2colorMask`, `textImageMaker`).

`hotFilter.m` and `golayDifferentiate.m` are still called by code under
`flyPEZanalysis/tools/template_making/` and by `_archive/pezAnalyzer3000_v12.m`, both of
which are also off the live path — `pezSetPath` keeps all of it loadable.

The live subfunctions stay in the parent folder, along with the `textImages/` and
`textImages_labelmaker/` asset folders that `textN2im.m` and `textN2im_v2.m` locate as
siblings via `mfilename('fullpath')`.
