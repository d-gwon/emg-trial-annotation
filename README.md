# EMG-based trial annotation for motor-execution compliance

<!-- TODO: final repo title, badges (license, DOI/Zenodo) -->

MATLAB pipeline that labels every cued motor-execution trial as compliant or as one of
five deviation types, using two surface-EMG channels (left / right) and the cue triggers.
No manual annotation is required; each dataset has one tuned parameter (`thr_mult`),
chosen from the data by a threshold sweep.

Companion code for: <!-- TODO: citation -->

## What it does

```
HE_load      raw EDF/BDF  ->  cue times, cue side, L/R EMG          (dataset adapter)
HE_detect    filter -> MAV envelope -> rolling threshold -> onsets  (dataset-agnostic)
HE_classify  onsets + cues -> one label per trial                   (dataset-agnostic)
```

Each trial is split into three windows, all anchored on the cue:

```
      ant                 set                          post
 |-----------|-----------------------------|------------------------|
cue-pre_win  cue              cue+exec_len+residual        next cue-pre_win
```

- **set**: any number of threshold crossings counts as one response per side.
- **post**: responses are counted, merged within `post_refrac`.
- **ant**: pre-cue activity, recorded separately (`antC`, `antW`) and kept out of the labels.

`numC` / `numW` = responses on the cued / non-cued side (set + post).

| numC | numW | Label | Meaning |
|------|------|-------|---------|
| 1    | 0    | CORR  | compliant |
| 0    | 0    | MISS  | no response |
| ≥2   | 0    | TERM  | repetition on the cued side |
| 0    | ≥1   | WRONG | non-cued side only |
| 1    | 1    | BOTH  | one response on each side |
| otherwise |  | COMP  | both sides, three or more responses |

## Requirements

- MATLAB <!-- TODO: minimum version actually tested -->
- EEGLAB 2022.1 with the BIOSIG plugin (`pop_biosig`) and firfilt (`pop_eegfiltnew`)
- Signal Processing Toolbox (`pop_resample`)
- Statistics and Machine Learning Toolbox (`prctile`, `fitrm`, `fitlme`, `fitglme`)

## Data

<!-- TODO: download links / DOIs for both datasets -->

| Config name | Format | EMG ch [R L] | Cue trigger | Execution | ISI |
|-------------|--------|--------------|-------------|-----------|-----|
| `Gwon2023`  | EDF, trigger channel 25 | 17, 21 | 1/2 = task onset | 3 s | 8–9 s |
| `Gwon2024`  | BDF, event codes | 35, 36 | 3 = go; 1/2 = direction, 2 s earlier | 4 s | 10–11 s |

Files are expected as `<TASK>_<SUBJECT>_<SESSION>.edf|bdf`, e.g. `ME_S17_5.bdf`.

## Quick start

```matlab
% 1. set the EEGLAB folder and the data root in local_paths.m
% 2. run the pipeline
run_error_detection                       % -> results/HE_trials.csv, results/HE_qc.csv

% 3. inspect one session
HE_show('Gwon2024', 'S3', '5');           % whole session
HE_show('Gwon2024', 'S3', '5', [60 140]); % zoom, seconds

% 4. summary statistics and figure
HE_stats('results/HE_trials.csv');
HE_figure_results('results/HE_trials.csv');
```

## Repository layout

```
core/       HE_config, HE_load, HE_detect, HE_classify, HE_label, DE_repeat_trigger_remove
qc/         HE_show, HE_plot, HE_sweep_threshold, HE_check_laterality, HE_triage
analysis/   HE_stats, HE_figure_results, run_survey_statistics
results/    HE_trials.csv, HE_qc.csv, HE_thr_sweep.csv   (as used in the paper)
run_error_detection.m
local_paths.m
```

## Parameters

Shared by both datasets (`HE_config`):

| Parameter | Value | |
|-----------|-------|---|
| `notch` | 58–62 Hz | band-stop |
| `band` | 30–100 Hz | band-pass |
| `srate_out` | 256 Hz | resampled rate |
| `mav_win_sec` / `mav_step_sec` | 0.50 / 0.09 s | MAV envelope |
| `thr_win_trials` | 11 | trials pooled for one local threshold |
| `min_dur` | 0.2 s | minimum supra-threshold duration |
| `residual` | 1 s | tolerated EMG tail after `exec_len` |
| `post_refrac` | 1 s | merge window in the post interval |

Per dataset:

| Parameter | Gwon2023 | Gwon2024 | |
|-----------|----------|----------|---|
| `thr_mult` | 4.0 | 2.0 | threshold = `thr_mult` × median resting MAV |
| `base_win` | [-2 -0.5] s | [-5.5 -2.5] s | resting window relative to the cue |
| `pre_win` | 1 s | 2 s | anticipation window |
| `exec_len` | 3 s | 4 s | |
| `isi_min` | 8 s | 10 s | used for the last trial only |

`thr_mult` is chosen with `HE_sweep_threshold`: the multiplier is swept from 1.5 to 6 and the
plateau between "resting false positives reach zero" and "MISS starts rising" is taken.
<!-- TODO: sweep figure + one sentence on why the two datasets differ -->

## Output

`HE_trials.csv` — one row per trial

| Column | |
|--------|---|
| `dataset`, `task`, `subject`, `session`, `trial` | identifiers |
| `cue_t`, `cue_side` | cue time (s), 1 = left, 2 = right |
| `numC`, `numW` | responses on the cued / non-cued side |
| `setC`, `postC`, `antC`, `setW`, `postW`, `antW` | the same, by window |
| `class` | CORR / MISS / WRONG / TERM / BOTH / COMP |
| `swapped` | L/R EMG channels were exchanged for this subject |

`HE_qc.csv` — one row per file: trial count, thresholds, resting false-positive rate and SNR per side.

## Quality control

| Script | Question it answers |
|--------|---------------------|
| `HE_sweep_threshold` | Which `thr_mult` clears resting noise without clipping movement? |
| `HE_show` / `HE_plot` | What did the detector see in this session? |
| `HE_check_laterality` | Does the responding channel match the cue side (threshold-free)? |
| `HE_triage` | Is an anomalous session a signal problem or a behavioural one? |

Exclusions and corrections applied in the paper:

<!-- TODO: fill in once final -->
| Subject | Dataset | Action | Evidence |
|---------|---------|--------|----------|
| | | excluded (no usable EMG) | |
| | | L/R channels swapped | |

## Using it on another dataset

1. Add a `case` to `HE_config`: EMG channels, trigger codes, `exec_len`, `isi_min`, `base_win`, `pre_win`.
2. If the trigger format is new, add a parser branch to `HE_load` that returns `cue_t` and `cue_side`.
3. Run `HE_sweep_threshold` and set `thr_mult` from the plateau.
4. Run `HE_check_laterality` before trusting any outcome.

## Citation

<!-- TODO -->

## License

<!-- TODO -->
