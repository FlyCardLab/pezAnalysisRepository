# flyPEZguis — tools

- **`stimulus_generation/`** (was `stimulusFunctions/`) — authors the visual-stimulus
  `.mat` files the rig plays back. Run one of these to create a new stimulus, then pick it
  up in the Stimulus panel of the rig GUI. Covers looming discs
  (`loomingStimulusMaker_withReference` and its variants), gratings, stripes, spirals, and
  photoactivation (`photoactivationGenerator_v2`).

Each writes into `pez3000_variables/visual_stimuli` on the shared drive via a hardcoded
absolute path — check the path near the `save` call at the bottom of the file before
running, as several still point at old dm11 or engram locations.
