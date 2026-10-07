function D = HE_detect(x2, srate, cue_t, c)
% Filter -> MAV -> threshold -> onsets. Identical for both datasets.
%   x2    2xN, row 1 = R, row 2 = L
%   D.onset  1x2 cell, onset times in seconds  {R, L}
%   D.thr    1x2 threshold per side

EEG = eeg_emptyset();
EEG.data   = x2;
EEG.srate  = srate;
EEG.nbchan = size(x2,1);
EEG.trials = 1;
EEG.pnts   = size(x2,2);
EEG.xmin   = 0;
EEG.xmax   = (EEG.pnts - 1) / srate;
EEG = eeg_checkset(EEG);

% pop_eegfiltnew picks the order from the transition band, so a 4 Hz notch
% works at 300 Hz. eegfilt's 3*fix(srate/locutoff) rule gives 17 taps here
% and leaves 60 Hz essentially untouched.
EEG = pop_eegfiltnew(EEG, 'locutoff', c.notch(1), 'hicutoff', c.notch(2), ...
                     'revfilt', 1, 'plotfreqz', 0);
EEG = pop_eegfiltnew(EEG, 'locutoff', c.band(1),  'hicutoff', c.band(2), ...
                     'plotfreqz', 0);
EEG = pop_resample(EEG, c.srate_out);

x  = double(EEG.data);
fs = c.srate_out;

win  = round(c.mav_win_sec  * fs);
step = round(c.mav_step_sec * fs);
nwin = floor((size(x,2) - win) / step) + 1;
assert(nwin > 0, 'recording shorter than one MAV window');

mav = zeros(2, nwin);
for i = 1:nwin
    a = (i-1)*step + 1;
    mav(:,i) = mean(abs(x(:, a:a+win-1)), 2);
end
fr    = fs / step;
mav_t = ((0:nwin-1)*step + win/2) / fs;

D.onset  = cell(1,2);
D.thr    = zeros(1,2);
D.thr_t  = zeros(2, nwin);
D.restFP = zeros(1,2);
D.snr    = zeros(1,2);

nCue = numel(cue_t);
half = floor(c.thr_win_trials / 2);

% frame -> owning trial, so the threshold can vary along the session
own = ones(1, nwin);
for k = 1:nCue, own(mav_t >= cue_t(k)) = k; end

for s = 1:2
    % pre-cue rest frames belonging to each trial
    rest = cell(1, nCue);
    for k = 1:nCue
        a = find(mav_t >= cue_t(k) + c.base_win(1), 1);
        b = find(mav_t <= cue_t(k) + c.base_win(2), 1, 'last');
        if ~isempty(a) && ~isempty(b) && b > a, rest{k} = mav(s, a:b); end
    end

    % One threshold per trial, pooled over neighbouring trials. A session-wide
    % threshold cannot follow a drifting baseline; a rolling one can.
    %
    % Multiplicative, not MAD-based: the MAV envelope is smooth, so its MAD is
    % tiny and the k needed to clear the baseline differs by channel (~34 left
    % vs ~20 right on a test file). A multiple of the rest median is scale-free
    % and one constant works across channels, subjects and datasets. Bursts run
    % 10x baseline, so placement is not delicate.
    thr_trial = zeros(1, nCue);
    for k = 1:nCue
        pool = [rest{max(1,k-half):min(nCue,k+half)}];
        if isempty(pool), pool = mav(s,:); end
        thr_trial(k) = c.thr_mult * median(pool);
    end
    thr_frame = thr_trial(own);

    % onsets, with a minimum supra-threshold duration so a single-frame
    % artefact cannot anchor a set
    ab  = mav(s,:) > thr_frame;
    on  = find(diff([0 ab]) ==  1);
    off = find(diff([ab 0]) == -1);
    on  = on((off - on + 1) >= round(c.min_dur * fr));

    D.onset{s}   = mav_t(on);
    D.thr(s)     = median(thr_trial);
    D.thr_t(s,:) = thr_frame;

    fp = 0; nb = 0;
    for k = 1:nCue
        if ~isempty(rest{k}), fp = fp + sum(rest{k} > thr_trial(k)); nb = nb + numel(rest{k}); end
    end
    D.restFP(s) = fp / max(nb,1);   % rest crossings are false by definition

    % Threshold-independent SNR: peak inside the execution window over the
    % resting median, per trial. If this sits below thr_mult the threshold
    % can never fire and the session returns all-MISS - a detection failure,
    % not a behavioural one. The two must not be reported together.
    snr = nan(1, nCue);
    for k = 1:nCue
        m = mav_t >= cue_t(k) & mav_t < cue_t(k) + c.exec_len + c.residual;
        if any(m) && thr_trial(k) > 0
            snr(k) = max(mav(s,m)) / (thr_trial(k) / c.thr_mult);
        end
    end
    D.snr(s) = median(snr, 'omitnan');
end

D.mav = mav;  D.mav_t = mav_t;  D.fr = fr;
end