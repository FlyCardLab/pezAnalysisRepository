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

## You cannot do both halves in one session

The listener keeps two pieces of state, and each command needs a different one:

| init | sets | needed by |
| --- | --- | --- |
| command 0, `'transforming'` | `stimStruct` (warpmap, warpoperator, stimRefROI) | 3/4 → **Flicker** |
| command 5, `'standard'` | `stimTrigStruct` (gainMatrix, window) | 9/10 → **White / Dark** |

They are mutually destructive. Each opens its own Psychtoolbox window, and opening a
window invalidates every texture and proxy handle from the previous one. Send a 5 after a
0 and `stimStruct.warpoperator` is left dangling, so Flicker dies with
`'transformProxyPtr' argument must be a handle to a proxy object`, returns a partial
struct, and everything afterwards fails with `Invalid Window (or Texture) Index`.

So `pdLiveMonitor` greys out whatever the current mode cannot drive, and the buttons that
remain are safe to press. To do the other half: **Reset stim** (command 86), close the
window, and restart with the other `'InitMode'`.

**For the bandwidth question you only need the default `'transforming'` mode.** Rise time
and fc-from-rise come from the flicker's own cycle average and never touch White/Dark.
`'standard'` is only needed for the DC swing, which feeds `acPkPk/dcSwing` and
fc-from-attenuation.

If the stimulus computer's console is already full of `Invalid Window (or Texture) Index`,
it is in this mangled state — reset it before trusting anything.

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

#### Repeats

One **Flicker** press presents the stimulus once by default. Raise it with
`'Repeats',N` only once the stimulus computer is presenting reliably — repeated
back-to-back presentations are a good way to expose intermittent faults, but a bad way to
work when presentation itself is the thing failing. Each repeat is captured separately with its own dark lead-in, because
`pdVerdict`'s baseline is the median of the first 300 frames and needs real dark there.

With more than one repeat, reported metrics are **medians** across them, with the spread shown beside them, and
the verdict line reads `good photodiode 2 of 3` rather than collapsing to one answer. A
large spread means the measurement isn't trustworthy however good the median looks — and
a mixed verdict usually points at something intermittent (dropped projector flips, stray
light) rather than the sensor.

## Reading the result

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

## When the stimulus computer misbehaves

Its console is the only place the real error appears — the listener catches every
exception and replies a bare `"error"` over UDP. Read it there first.

**`Unrecognized function or variable 'screenid'`** in
`initializeVisualStimulusGeneralUDP_brighter` means the projector is not being seen as a
second display. That function loops over `Screen('Screens')` looking for one 1024 or 1280
px wide, and only assigns `screenid` if it finds one. If the console also printed
`screenidList = 0`, PTB can see a single screen — the control monitor — and never assigns
it. **This is a display problem, not a software one:** check the projector is powered and
awake, and that Windows is *extending* the desktop rather than duplicating or showing on
one display only. Nothing in this folder can work around it.

**`Dot indexing is not supported`** at `fullOffIm = uint8(stimTrigStruct.gainMatrix.*0)`
means a full-field command (9/10) was sent under a transforming init, where
`stimTrigStruct` has no `gainMatrix`. `pdLiveMonitor` no longer does this.

**`'transformProxyPtr' argument must be a handle to a proxy object`**, or a stream of
`Invalid Window (or Texture) Index`, means the two init modes have been mixed and the
window/texture handles are stale. Press **Reset stim** (command 86) and start again in
one mode.

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

**The input range is fixed at ±10 V by default, not auto-ranged.** A phototransistor run
off 5 V saturates at its supply, and a full-screen white frame is far brighter than the
35×35 px patch, so White pegs it at a dead-flat 5.000 V while the patch flicker is only a
few hundred mV. With a narrow range the DAQ would clip at its own ceiling, which looks
identical in the trace to the sensor railing — and those have completely different fixes.
With headroom, flat-topping at 5.000 V can only be the sensor. Resolution isn't the
constraint: a 0.5 V flicker on ±10 V is still ~1600 codes on a 16-bit board.

This matters because `dcSwing` comes from White. **If White clipped, `dcSwing` is only a
lower bound, so `acPkPk/dcSwing` and fc-from-attenuation would both be wrong** — the
readout detects the clipping, says whether it was the sensor rail or the DAQ ceiling, and
withholds those two numbers rather than printing a confident wrong answer. Rise time and
fc-from-rise are unaffected and still valid.

Pass `'Range','auto'` to probe and pick the narrowest fitting range instead, or
`'SensorRail',N` if the sensor saturates somewhere other than 5 V.

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
