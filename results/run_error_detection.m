% Unified EMG error detection for Gwon2023 (A) and Gwon2024 (B).
clear; clc
gpath = 'C:\Users\danig\OneDrive\';
addpath(genpath([gpath 'function\eeglab2022.1']));
addpath(([gpath 'function']));

eeglab nogui

datasets = {'Gwon2023','Gwon2024'};
ALL = table();
QC  = table();
plot_on = 0;
for d = 1:numel(datasets)
    c     = HE_config(datasets{d});
    flist = dir(fullfile(c.fpath, c.pattern));

    for f = 1:numel(flist)
        fname = flist(f).name;
        p = split(erase(fname, {'.edf','.bdf'}), '_');
        if any(strcmp(fname, c.exclude)) || any(strcmp(p{2}, c.excl_subj))
            fprintf('EXCL %-28s (see HE_config)\n', fname); continue;
        end
        try
            S = HE_load(fname, c);
            D = HE_detect([S.R; S.L], S.srate, S.cue_t, c);
            T = HE_classify(D.onset{1}, D.onset{2}, S.cue_t, S.cue_side, c);

            T.dataset = repmat(string(c.name),  height(T), 1);
            T.task    = repmat(string(S.task),    height(T), 1);
            T.subject = repmat(string(S.subject), height(T), 1);
            T.session = repmat(string(S.session), height(T), 1);
            T.swapped = repmat(S.swapped,         height(T), 1);
            if plot_on == 1, HE_plot(S, D, T, c); end
            ALL = [ALL; T]; %#ok<AGROW>
            QC  = [QC; table(string(c.name), string(fname), height(T), ...
                             D.thr(1), D.thr(2), D.restFP(1), D.restFP(2), ...
                             D.snr(1), D.snr(2), c.thr_mult, ...
                   'VariableNames', {'dataset','file','n_trial','thrR','thrL', ...
                                     'restFP_R','restFP_L','snrR','snrL','thr_mult'})]; %#ok<AGROW>
            flag = '';
            if min(D.snr) < c.thr_mult, flag = '  <-- SNR below thr_mult'; end
            fprintf('OK   %-28s %3d trials  SNR %.1f/%.1f  CORR %.2f%s\n', ...
                    fname, height(T), D.snr(1), D.snr(2), ...
                    mean(T.class == "CORR"), flag);
        catch ME
            fprintf('SKIP %-28s %s\n', fname, ME.message);
        end
    end
end

writetable(ALL, 'HE_trials.csv');
writetable(QC,  'HE_qc.csv');

% distribution by dataset
summary_tbl = groupsummary(ALL, {'dataset','class'});
disp(summary_tbl)

% checks worth running before trusting any of the above
%   1. QC.n_trial should be 50 everywhere; anything else is a trigger problem
%   2. tabulate(ALL.class(ALL.trial==max(ALL.trial))) vs the rest:
%      the last trial should no longer be short of TERM/COMP
%   3. histogram(diff(cue_t)) per file: 8~9 s (A), 10~11 s (B)