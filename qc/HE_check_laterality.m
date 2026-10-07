function Q = HE_check_laterality(datasets)
% Does the responding channel match the cue side? Threshold-free.
%
% For each trial the peak MAV inside the execution window is taken on both
% channels, normalised by that channel's own resting median (the channels
% differ in baseline, so raw amplitudes are not comparable). The larger
% ratio names the responding side, which is compared against the cue.
%
%   agree ~ 1  mapping is correct
%   agree ~ 0  cue_side and the channels are inverted for that file
%   in between  neither; look at the file before trusting its outcomes
%
%   Q = HE_check_laterality();                  both datasets
%   Q = HE_check_laterality({'Gwon2024'});

if nargin < 1, datasets = {'Gwon2023','Gwon2024'}; end
Q = table();

for d = 1:numel(datasets)
    c     = HE_config(datasets{d});
    flist = dir(fullfile(c.fpath, c.pattern));

    for f = 1:numel(flist)
        fname = flist(f).name;
        try
            S = HE_load(fname, c);
            D = HE_detect([S.R; S.L], S.srate, S.cue_t, c);
        catch ME
            fprintf('SKIP %-28s %s\n', fname, ME.message); continue;
        end

        % resting median per channel, for normalisation
        rest = [];
        for k = 1:numel(S.cue_t)
            m = D.mav_t >= S.cue_t(k) + c.base_win(1) & ...
                D.mav_t <= S.cue_t(k) + c.base_win(2);
            rest = [rest, D.mav(:, m)]; %#ok<AGROW>
        end
        b = median(rest, 2);

        resp = zeros(1, numel(S.cue_t));
        for k = 1:numel(S.cue_t)
            m = D.mav_t >= S.cue_t(k) & ...
                D.mav_t <  S.cue_t(k) + c.exec_len + c.residual;
            if ~any(m), continue; end
            r = max(D.mav(:, m), [], 2) ./ b;      % R, L relative to own rest
            if r(2) > r(1), resp(k) = 1; else, resp(k) = 2; end   % 1 = left
        end

        ok    = resp > 0;
        agree = mean(resp(ok) == S.cue_side(ok));
        if     agree >= 0.80, verdict = "ok";
        elseif agree <= 0.20, verdict = "INVERTED";
        else,                 verdict = "CHECK";
        end

        Q = [Q; table(string(c.name), string(fname), sum(ok), agree, verdict, ...
             'VariableNames', {'dataset','file','n_trial','agree','verdict'})]; %#ok<AGROW>
        fprintf('%-10s %-28s agree %.2f  %s\n', c.name, fname, agree, verdict);
    end
end

fprintf('\nInverted: %d   Ambiguous: %d   OK: %d\n', ...
        sum(Q.verdict=="INVERTED"), sum(Q.verdict=="CHECK"), sum(Q.verdict=="ok"));
disp(Q(Q.verdict ~= "ok", :));
writetable(Q, 'HE_laterality.csv');

% Files coming back INVERTED can be recovered rather than dropped: add the
% filename to c.flip in HE_config and HE_load will swap cue_side for it.
end
