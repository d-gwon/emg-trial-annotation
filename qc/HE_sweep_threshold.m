% Pick c.thr_mult from data. Rest frames contain no movement by design, so
% any crossing there is a false positive; no manual annotation is needed.
clear; clc
addpath(genpath('C:\Users\danig\OneDrive\function\eeglab2022.1')); eeglab nogui

mults = 1.5:0.25:6;
res   = table();

for ds = {'Gwon2023','Gwon2024'}
    c     = HE_config(ds{1});
    flist = dir(fullfile(c.fpath, c.pattern));
    sel   = round(linspace(1, numel(flist), min(8, numel(flist))));

    for f = sel
        try, S = HE_load(flist(f).name, c); catch, continue; end
        for m = mults
            cm = c;  cm.thr_mult = m;
            D  = HE_detect([S.R; S.L], S.srate, S.cue_t, cm);
            T  = HE_classify(D.onset{1}, D.onset{2}, S.cue_t, S.cue_side, cm);
            res = [res; table(string(c.name), string(flist(f).name), m, ...
                   mean(D.restFP), ...
                   mean(T.class=="CORR"),  mean(T.class=="MISS"), ...
                   mean(T.class=="TERM"),  mean(T.class=="WRONG"), ...
                   mean(T.class=="BOTH"),  mean(T.class=="COMP"), ...
                   'VariableNames', {'dataset','file','thr_mult','restFP', ...
                              'pCORR','pMISS','pTERM','pWRONG','pBOTH','pCOMP'})]; %#ok<AGROW>
        end
    end
end

G = groupsummary(res, {'dataset','thr_mult'}, 'mean', ...
      {'restFP','pCORR','pMISS','pTERM','pWRONG','pBOTH','pCOMP'});
disp(G)
writetable(res, 'HE_thr_sweep.csv');

% How to read it:
%   restFP must reach ~0 before a multiplier is usable.
%   pBOTH and pCOMP fall as spurious opposite-side detections stop firing;
%   that drop is the clearest signal that the threshold has cleared noise.
%   pMISS starts rising once the multiplier clips real movement.
%   Take the plateau between the two, and put this curve in the Supplementary.
