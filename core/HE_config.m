function c = HE_config(name)
% Dataset specification. All anchors are Task onset (t = 0).
%   Gwon2023 (A): trigger 1/2 = Task onset,        exec 3 s, ISI 8~9 s
%   Gwon2024 (B): trigger 3   = Task onset,        exec 4 s, ISI 10~11 s
%                 trigger 1/2 = direction, 2 s before the go trigger

switch name
    case 'Gwon2023'
        c.name     = 'Gwon2023';
        c.fpath    = '';
        c.pattern  = 'ME*.edf';
        c.parser   = 'trigchan';
        c.trig_ch  = 25;
        c.emg_ch   = [17 21];        % [R L]
        c.ref_ch   = [10 22];
        c.exec_len = 3;
        c.isi_min  = 8;
        c.thr_mult = 4.0;    % plateau 3.5-4.5 (HE_sweep_threshold)
        % cue is task onset, preceded directly by Pre-rest fixation
        c.base_win = [-2 -0.5];
        c.pre_win  = 1;      % Pre-rest is jittered 3-4 s, so cue timing is
                             % not predictable and anticipation is unlikely
        c.exclude   = {};    % filenames that will not load at all
        c.excl_subj = {};    % no usable EMG anywhere in Dataset 1
        c.swap_emg  = {};    % no inverted laterality in Dataset 1

    case 'Gwon2024'
        c.name     = 'Gwon2024';
        c.fpath    = '';
        c.pattern  = 'ME*.bdf';
        c.parser   = 'edftype';
        c.cue_code = 3;              % go trigger
        c.dir_code = [1 2];          % direction trigger
        c.dir_lead = 2;              % s between direction and go
        c.emg_ch   = [35 36];        % [R L]
        c.ref_ch   = [];     % no reference pair identified for ch 35/36
        c.exec_len = 4;
        c.isi_min  = 10;
        c.thr_mult = 2.0;    % plateau 2.0-2.25 (HE_sweep_threshold)

        % The cue here is the go trigger, and the 2 s before it is the
        % Stimuli period: the arrow is already on screen and the participant
        % knows which hand to use. Resting estimates taken there include
        % preparatory tone, which raises the threshold and turns real bursts
        % into MISS. Pre-rest runs from about -6 s to -2 s, so sample there.
        c.base_win = [-5.5 -2.5];
        c.pre_win  = 2;      % the arrow is up for 2 s before the go trigger,
                             % so the hand is known and cue timing is fixed;
                             % pre-cue activity here is preparation for this
                             % trial, not a late error in the previous one
        % Lower than Dataset 1 because these channels are not re-referenced,
        % so the resting MAV median carries common-mode noise and a larger
        % multiple of it clips real bursts. If a reference pair is found for
        % ch 35/36, re-run the sweep: both datasets should then take the
        % same multiplier, which is the outcome to prefer.
        %
        c.exclude   = {};    % filenames that will not load at all

        % Subjects with no usable EMG. This is a QC statement, not a
        % behavioural one, so these are reported as excluded rather than
        % counted as MISS. S17: 0 of 100 trials produced any detection across
        % both sessions. Check snrR/snrL in HE_qc.csv before adding a subject
        % here; if SNR sits above thr_mult the silence is real behaviour.
        % S11 (detection 44%) is borderline and is left in for now.
        c.excl_subj = {'S17'};

        % Subjects whose left and right EMG electrodes were swapped.
        % Candidates from HE_triage (accuracy if cue_side were inverted):
        %   S2  0% -> 86%,  S7  0-6% -> 76%,  S4  0-4% -> 63%
        % all consistent across both of their sessions.
        %
        % LEAVE THIS EMPTY UNTIL THE CAUSE IS SETTLED. Swapping asserts an
        % electrode fault. If instead the participant used the wrong hand,
        % swapping converts their errors into CORR and deletes the finding
        % the audit exists to produce. EMG alone cannot tell the two apart:
        % sessions 5 and 6 share a montage, so consistency across them is
        % equally expected under either explanation. Mu/beta ERD decides it
        % - contralateral to the hand that moved means behaviour, to the
        % hand that was cued means wiring.
        c.swap_emg  = {'S2','S7'};

    otherwise
        error('unknown dataset: %s', name);
end

% ---- shared across both datasets ----
c.srate_out    = 256;
c.notch        = [58 62];
c.band         = [30 100];
c.mav_win_sec  = 0.50;    % seconds, not samples
c.mav_step_sec = 0.09;
c.thr_win_trials = 11;    % trials pooled for one local threshold
c.min_dur      = 0.2;     % minimum supra-threshold duration for an onset
c.residual     = 1;       % tolerated EMG tail after exec_len
c.post_refrac  = 1;       % merge window inside the post interval
end