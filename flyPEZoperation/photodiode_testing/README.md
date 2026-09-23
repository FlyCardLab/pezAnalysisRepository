# photodiode_testing

Diagnostic tools for evaluating a photodiode / light sensor on a pez rig. Written while
replacing the dead photodiode on **pez3002** (which runs `runPezControl_v13.m`) with a
cheap phototransistor module.

**Nothing here is called by `runPezControl` or by the nightly pipeline.** These are
hand-run tools. Deleting the folder breaks nothing.

| File | What it does |
| --- | --- |
| `pdLiveMonitor.m` | Live trace + live diagnostic numbers, straight off the rig's DAQ |
| `pdVerdict.m` | Offline: predicts the rig's own pass/fail decision for a trace |
| `pdSelfTest.m` | Synthetic checks of `pdVerdict`. No hardware. Run this first |

---

## What the sensor actually has to do

Less than you'd think.

The photodiode does **not** watch the looming disk. It watches a 35×35 px reference patch
in a fixed corner of the projected image (`stimRefROI_x`/`stimRefROI_y` in
`computer_info.xlsx`, squared off to 35 px at
`flyPEZoperation/visual_stimuli/projectorCalibration3000_v3.m:224`). The projector runs 1024×768 @ 120 Hz and the DLP shows R, G, B
sequentially, so sub-frames land on a 360 Hz grid — but the patch alternates on *every*
sub-frame (`initializeFramesFromFileUDP.m:228-257`), giving a seamless **180 Hz, 50%-duty
square wave, 2.78 ms per state**, swinging between levels 255 and 10. Never fully dark.
The projector's per-pixel `gainMatrix` is forced to 1.0 inside this ROI
(`flyPEZoperation/visual_stimuli/projectorCalibration3000_v3.m:619`), so the patch is always at full output regardless of
dome shading.

`pdSelfTest` measures what the rig's gate actually demands of a sensor:

| Requirement | Measured threshold |
| --- | --- |
| Bandwidth | **fc ≳ 120 Hz** (fails at 100 Hz) — a 10–90 rise time under ~2.9 ms |
| Equivalent AC/DC swing ratio | **> 0.75** |
| Amplitude | **swing > ~5× the noise std.** Absolute volts barely matter |

At 100 Hz the failure is `'frames were dropped'`, not a signal-to-noise failure: rounded
peaks jitter their positions past the `range(diff(peakPos)) > 2` frame tolerance while the
amplitude is still enormous. Amplitude is rarely the binding constraint; **edge shape is**.

---

## Run order

```matlab
pdSelfTest                      % offline sanity check, no hardware
```

Then on the rig, with `runPezControl` **open but not coupled to the camera**:

```matlab
pdLiveMonitor
```

1. **White**, then **Dark** — latches `dcSwing`. If `dcSwing` is already tiny, it's a
   light-level problem and bandwidth is moot.
2. **Flicker** — latches AC p-p, rise/fall time, both `fc` estimates, and the verdict.
3. Re-run as `pdLiveMonitor('Channels',{'ai0','ai15','ai10'})` — the mux test below.
4. Re-run with an explicit narrow `'Range'` and compare SNR.
5. Repeat on a rig with a working photodiode, same settings. **Snapshot** both.
6. Go/no-go on the verdict being `'good photodiode'` under **both** variants with margin.
7. **Reload the GUI's stimulus** before resuming experiments (see caveat 3).

### Reading the result

- both `fc` estimates agree and are low (≲120 Hz) → **bandwidth-limited**
- `fc` fine but `dcSwing` small vs the working rig → **light level / responsivity**
- single channel fine, mux test much worse → **acquisition chain, not the sensor**

---

## The mux test

Production acquires `ai0`, `ai15` and `ai10` at `nRate*10` scans/s
(`runPezControl_v13.m:3730`) — 60 000 scans/s at 6000 fps, so the ADC multiplexes at
**~180 kS/s, about 5.5 µs per channel**. A phototransistor needs a large load resistor
(100 kΩ–1 MΩ) for decent responsivity, which puts its source impedance far above NI's
~10 kΩ guidance for multiplexed sampling. The sample-and-hold never settles and you read a
small, ghosted signal from a sensor that is actually fine.

If the flicker amplitude drops sharply when you add the other two channels: **lower the
load resistor, or buffer the sensor with a unity-gain op-amp, before concluding anything
about the sensor.**

---

## Three things about sharing the rig

1. **The DAQ.** The GUI creates its session at startup (`v13:1181`) but only reserves the
   hardware when you couple to the camera (`v13:3745-3753`). So the monitor runs alongside
   the GUI only while it is uncoupled; stop the monitor before coupling. If
   `pdLiveMonitor` reports the device is reserved, that's what happened.
2. **UDP port 21566.** `judp` opens and closes a socket per call (`judp.m:118-161`) — sends
   use an ephemeral port and never collide, but `judp('receive')` binds 21566 for the
   duration. Don't press the stimulus buttons while the GUI is mid-trial.
3. **The stimulus computer holds one loaded stimulus.** The Flicker button sends command 3,
   which overwrites whatever `stimTrigStruct` the GUI loaded. Reload the GUI's stimulus
   before running real experiments. `pdLiveMonitor` prints a reminder on exit.

---

## Gotchas that cost real time

**The capture must start before the stimulus.** `pdVerdict`'s v13 baseline is
`median(first 300 camera frames)`. With no dark lead-in, that lands halfway up the square
wave and every score becomes meaningless — a *perfect* 1 V trace scores 0.5 and "fails".
`pdLiveMonitor` records a 200 ms dark lead-in before triggering; `pdVerdict` warns if you
hand it a trace that lacks one.

**`photoSignalTest` is dimensionally incoherent.** `v13:2971-2975` computes
`|median(chunk IQRs) − median(first 300 samples)| / min(IQR)` — a *spread* minus a *level*.
It is therefore sensitive to the sensor's DC offset, not just to signal quality. This is
faithful to the rig, not a bug in `pdVerdict`. The readout shows `avgBase`, `avgPeak` and
`minRange` separately so you can see which term is driving the number.

**The two copies of the gate disagree**, so a trace can pass live and fail reanalysis:

| | acquisition (`v13:2964-3024`) | reanalysis (`pez3000_rawDataPrep.m:686-780`) |
| --- | --- | --- |
| chunks | `frmCount/100` | 30 |
| `avgBase`/`avgPeak` | median of first 300 / median of IQRs | chunk *means* of the min- and max-IQR chunks |
| SNR threshold | **5** | **10** |
| incomplete if | `nPeaks < whiteCt-2` | `nPeaks < whiteCt-1` |

`pdVerdict` reproduces both; always check both.

**No input range is ever set anywhere else in the repo.** `grep '\.Range'` over
`flyPEZoperation/` returns nothing, so production runs on the board default — likely ±10 V.
A 50 mV signal there uses ~1/200th of the available resolution. `pdLiveMonitor` sets the
range explicitly and reports what the board actually granted.

**Auto-ranging probes with the projector at full white**, not dark — ranging on a dark
trace picks a range that the white condition then clips.

**UDP replies are polled, not blocked on, and can occasionally be dropped.** A long
blocking `judp('receive')` sits inside Java, and no `DataAvailable` event can be dispatched
while it does — at 60 kS/s across three channels, a few seconds of that overruns the
session buffer and aborts the acquisition. So `pdLiveMonitor` polls in 250 ms windows, and
a reply that lands in the gap between sockets is lost. Every caller treats that as
non-fatal: you get the trace either way, and `whiteCt` is estimated from the duration
instead of being reported (the readout says so when this happens).

**Use a `constSize` stimulus for the flicker test.** It holds the dome static and flickers
only the reference patch, so stray dome light can't confound the reading. Generate one with
`flyPEZguis/stimulusFunctions/loomingStimulusMaker_withReference.m`
(`pez5 = 0`, `stimChoice = 4`, `duration = 3000`) into
`pez3000_variables/visual_stimuli/`. A looming stimulus works but sweeps dome luminance
throughout and holds its final frame for 2 s afterwards.
