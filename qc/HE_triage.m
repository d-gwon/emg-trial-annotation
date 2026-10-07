function [SUB, SES] = HE_triage(csv)
% Sort anomalous sessions by failure mode, so behaviour and signal problems
% are not reported in the same column.
%
%   acc       % CORR as scored
%   acc_flip  % CORR if cue_side were inverted (numC and numW swapped).
%             High acc_flip means the laterality mapping is reversed.
%   det       % of trials with any detection. Low det means the threshold
%             never fired; that is a signal problem, not a behavioural one.
%   both      % BOTH. High with det ~100 means both channels fire together,
%             which is either bilateral movement or channel crosstalk;
%             HE_check_laterality's r_LR separates those.

if nargin < 1, csv = 'HE_trials.csv'; end
T = readtable(csv, 'TextType', 'string');

% class the trial would receive with the cue side inverted
fl = strings(height(T),1);
for i = 1:height(T), fl(i) = one(T.numW(i), T.numC(i)); end
T.flip = fl;

key = T.dataset + "|" + T.subject + "|" + T.session;
[u, ia] = unique(key, 'stable');
SES = table(T.dataset(ia), T.subject(ia), T.session(ia), ...
            'VariableNames', {'dataset','subject','session'});
for i = 1:numel(u)
    m = (key == u(i));
    SES.n(i)        = sum(m);
    SES.acc(i)      = 100 * mean(T.class(m) == "CORR");
    SES.acc_flip(i) = 100 * mean(T.flip(m)  == "CORR");
    SES.det(i)      = 100 * mean(T.numC(m) + T.numW(m) > 0);
    SES.both(i)     = 100 * mean(T.class(m) == "BOTH");
end

SUB = groupsummary(SES, {'dataset','subject'}, {'min','max','mean'}, ...
                   {'acc','acc_flip','det','both'});
SUB = SUB(SUB.min_acc < 75, :);

fprintf('\n--- inverted laterality (flip recovers) ---\n');
disp(SUB(SUB.mean_acc_flip > 50, :));
fprintf('\n--- detection failure (low det) ---\n');
disp(SUB(SUB.mean_det < 80 & SUB.mean_acc_flip <= 50, :));
fprintf('\n--- bilateral / crosstalk (high both, det ~100) ---\n');
disp(SUB(SUB.mean_both > 40 & SUB.mean_det >= 80, :));
fprintf('\n--- remaining, mixed ---\n');
disp(SUB(SUB.mean_acc_flip <= 50 & SUB.mean_det >= 80 & SUB.mean_both <= 40, :));

% A subject flagged in every session points at the participant; one session
% out of several points at that recording. Sessions run back to back on one
% montage share any electrode fault, so consistency across them is
% suggestive, not conclusive.
end

function k = one(nc, nw)
if     nc == 0 && nw == 0, k = "MISS";
elseif nc == 1 && nw == 0, k = "CORR";
elseif nc >= 2 && nw == 0, k = "TERM";
elseif nc == 0 && nw >= 1, k = "WRONG";
elseif nc == 1 && nw == 1, k = "BOTH";
else,                      k = "COMP";
end
end