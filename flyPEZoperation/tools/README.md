# flyPEZoperation — tools

Not part of the nightly pipeline and not called by the rig GUI, but these are real
utilities you run by hand when setting up or servicing hardware.

- **`projector_calibration/`** (was `visual_stimuli/`) — projector and photodiode
  calibration for the stimulus display: `projectorCalibration3000*`, the two-servo
  positioning rigs (`azimuthDataAcquisition2servos_v3`,
  `elevationDataAcquisition2servos_v3`, `RyansAdvServoCalibrated*`, which need the
  Phidget21 library via `loadphidget21`), `photodiodeScanning3axis`, and `stimDemo`.

Renaming this folder is safe: the `visual_stimuli` path the rig reads at runtime is
`<fileDir>/pez3000_variables/visual_stimuli` on the shared drive, not this folder.
