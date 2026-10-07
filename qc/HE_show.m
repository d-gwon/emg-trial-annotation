function [S, D, T] = HE_show(dataset, who, session, trange)
% Run and plot one session. No try/catch, so errors surface instead of
% turning into a SKIP line.
%
%   HE_show('Gwon2024', 'S17')            first session of that subject
%   HE_show('Gwon2024', 'S17', '5')       that session
%   HE_show('Gwon2024', 'S17', '5', [60 140])   zoom, seconds
%   HE_show('Gwon2024', 'ME_S17_5.bdf')   by filename
%   HE_show('Gwon2024', 43)               by index into dir()
%
% Indexing by subject beats indexing by number: dir() order changes when
% files are added or renamed, so f = 43 is not the same session tomorrow.

if nargin < 3, session = ''; end
if nargin < 4, trange  = []; end

c     = HE_config(dataset);
need  = {'thr_mult','thr_win_trials','swap_emg','excl_subj','mav_win_sec'};
miss  = need(~isfield(c, need));
assert(isempty(miss), 'HE_config is out of date, missing: %s', strjoin(miss, ', '));

flist = dir(fullfile(c.fpath, c.pattern));
names = string({flist.name});

if isnumeric(who)
    fname = flist(who).name;
elseif contains(who, '.')
    fname = char(who);
else
    subj = strings(size(names));
    sess = strings(size(names));
    for i = 1:numel(names)
        q = strsplit(char(names(i)), {'_','.'});
        if numel(q) >= 2, subj(i) = q{2}; end
        if numel(q) >= 3, sess(i) = q{3}; end
    end

    hit = find(subj == string(who));
    assert(~isempty(hit), 'no file for subject %s. Available: %s', ...
           who, strjoin(cellstr(unique(subj)), ' '));
    if ~isempty(session)
        keep = hit(sess(hit) == string(session));
        assert(~isempty(keep), 'subject %s has no session %s. Available: %s', ...
               who, session, strjoin(cellstr(sess(hit)), ' '));
        hit = keep;
    end
    if numel(hit) > 1
        fprintf('%d sessions found, using the first:\n', numel(hit));
        disp(names(hit).');
    end
    fname = char(names(hit(1)));
end

S = HE_load(fname, c);
D = HE_detect([S.R; S.L], S.srate, S.cue_t, c);
T = HE_classify(D.onset{1}, D.onset{2}, S.cue_t, S.cue_side, c);

fprintf('%s  %d trials  CORR %.2f  restFP %.4f/%.4f%s\n', ...
        fname, height(T), mean(T.class=="CORR"), ...
        D.restFP(1), D.restFP(2), ...
        repmat('  [L/R swapped]', 1, S.swapped));

if isfield(D, 'snr')
    fprintf('   SNR %.1f/%.1f (R/L)\n', D.snr(1), D.snr(2));
    if min(D.snr) < c.thr_mult
        fprintf(['   SNR is below thr_mult (%.1f): no threshold can fire ' ...
                 'here, so MISS is a detection failure not a behaviour.\n'], c.thr_mult);
    end
else
    fprintf('   (HE_detect has no snr field - update it to diagnose all-MISS sessions)\n');
end

HE_plot(S, D, T, c, trange);
end