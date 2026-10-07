function S = HE_load(fname, c)
% Format adapter. Returns a standard struct regardless of dataset.
%   S.cue_t    1xN  Task onset, seconds from recording start
%   S.cue_side 1xN  1 = left, 2 = right
%   S.L S.R    1xM  raw EMG
%   S.srate         native sampling rate

EEG   = pop_biosig(fullfile(c.fpath, fname));
srate = EEG.srate;

switch c.parser
    case 'trigchan'
        ev = DE_repeat_trigger_remove(EEG.data(c.trig_ch,:));
        i8 = find(ev == 8, 1);
        assert(~isempty(i8), 'no start marker (8): %s', fname);
        i9 = find(ev == 9, 1, 'last');
        if isempty(i9), i9 = numel(ev); end
        EEG.data = EEG.data(:, i8:i9);
        ev       = ev(i8:i9);

        m          = (ev == 1 | ev == 2);
        S.cue_t    = (find(m) - 1) / srate;
        S.cue_side = ev(m);

    case 'edftype'
        lab   = [EEG.event.edftype];
        lat   = [EEG.event.latency];
        i_dir = find(ismember(lab, c.dir_code));
        i_go  = find(lab == c.cue_code);

        % k-th direction trigger pairs with k-th go trigger
        assert(numel(i_dir) == numel(i_go), ...
               'trigger count mismatch (%d dir / %d go): %s', ...
               numel(i_dir), numel(i_go), fname);
        S.cue_t    = (lat(i_go) - 1) / srate;
        S.cue_side = lab(i_dir);

        % sanity: the gap should be dir_lead
        lead = (lat(i_go) - lat(i_dir)) / srate;
        assert(all(abs(lead - c.dir_lead) < 0.5), ...
               'dir->go gap out of range (%.2f~%.2f s): %s', ...
               min(lead), max(lead), fname);
end

S.cue_t    = S.cue_t(:).';
S.cue_side = S.cue_side(:).';
assert(numel(S.cue_t) == numel(S.cue_side), 'cue/side length mismatch: %s', fname);

x = double(EEG.data(c.emg_ch,:));          % cast before arithmetic

S.R = x(1,:);
S.L = x(2,:);

p = split(erase(fname, {'.edf','.bdf'}), '_');
S.task = p{1};  S.subject = p{2};  S.session = p{3};

% Subjects listed in c.swap_emg had their electrodes reversed, so the
% channels are exchanged here rather than relabelling the cue. Doing it at
% the signal keeps HE_plot honest: the panel titled Left then shows the
% left muscle.
S.swapped = any(strcmp(S.subject, c.swap_emg));
if S.swapped
    t = S.R;  S.R = S.L;  S.L = t;
end

S.srate = srate;
S.name  = fname;
end