# Projector calibration GUI

Manual editor for the projector calibration values. Start with `projectorCalibrationGUI`.
The maths is copied from `../projectorCalibration3000_v3.m`, which is unchanged unless you press
"Write values into v3 script" (that makes a timestamped backup first).

- Loads: 8 of 14 values from the rig's `pezNNNN_stimuliParams.mat`, all 14 from `pezNNNN_calibGUIparams.mat`
  (written on every GUI save). `topThreshFactor` and `hypTwistA-D` were never saved by v3, so they start blank.
- Send: writes `pezNNNN_im2show.tif` and sends command 54. Rig calibration files are untouched.
- Save: backs up the rig files to `calibGUI_backups/`, writes what v3 op 5 writes, then sends reload (command 0) and display.
- Check: `testCalibEquivalence('pez3001')` after v3 op 5 has run on that pez's control computer.

Status: not yet run in MATLAB (CARDLAB-ENG was unreachable). Command 0 (reload) is unverified.
