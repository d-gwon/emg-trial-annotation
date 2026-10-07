function [SUB, SES, OUT] = HE_stats(csv, nboot)
% Deviation rates and composition (RQ1).
%
% Trial-level outcomes are aggregated within participant and session before
% analysis, so the participant is the unit of inference and no participant
% contributes disproportionately. Between-dataset comparison is descriptive:
% the datasets differ in sample, protocol and instrumentation at once, so no
% single factor can be isolated and no test is reported for the contrast.
%
%   [SUB, SES, OUT] = HE_stats('HE_trials.csv');
%
%   SES  per session: category counts per 50 trials and rates
%   SUB  per participant: deviation rate, category counts, composition
%   OUT  printed summary, also written to HE_stats.csv

if nargin < 1, csv   = 'HE_trials.csv'; end
if nargin < 2, nboot = 10000; end
rng(0);

T   = readtable(csv, 'TextType', 'string');
CAT = ["MISS" "WRONG" "TERM" "BOTH" "COMP"];
DS  = unique(T.dataset, 'stable');

SES = collapse(T, CAT, ["dataset" "subject" "session"]);
SUB = collapse(T, CAT, ["dataset" "subject"]);

OUT = table();
for d = 1:numel(DS)
    s = SES(SES.dataset == DS(d), :);
    u = SUB(SUB.dataset == DS(d), :);
    v = u.dev;                                  % participant deviation rate

    % ---- session-level rate per category, mean (SD) ----
    fprintf('\n===== %s =====  %d participants, %d sessions\n', ...
            DS(d), height(u), height(s));
    fprintf('per-session rate %%, mean (SD):\n');
    for k = 1:numel(CAT)
        fprintf('  %-6s %5.2f (%5.2f)   CV %.2f\n', CAT(k), ...
                mean(s.rate(:,k)), std(s.rate(:,k)), ...
                std(s.rate(:,k))/mean(s.rate(:,k)));
    end

    % ---- composition: share of each category within all deviations ----
    tot = sum(u.cnt(:));
    fprintf('deviation rate %.2f%%   composition %% of all deviations:\n', mean(v));
    for k = 1:numel(CAT)
        fprintf('  %-6s %5.1f\n', CAT(k), 100*sum(u.cnt(:,k))/tot);
    end

    % ---- dispersion and prevalence ----
    bs = zeros(nboot,1);
    for b = 1:nboot, bs(b) = mean(v(randi(numel(v), numel(v), 1))); end
    ci = prctile(bs, [2.5 97.5]);
    fprintf('participant rate: mean %.2f  95%%CI [%.2f %.2f]  median %.2f  IQR [%.2f %.2f]\n', ...
            mean(v), ci(1), ci(2), median(v), prctile(v,25), prctile(v,75));

    fprintf('prevalence (>=1 deviation): any %.1f%%', 100*mean(sum(u.cnt,2) > 0));
    for k = 1:numel(CAT)
        fprintf('  %s %.1f%%', CAT(k), 100*mean(u.cnt(:,k) > 0));
    end
    fprintf('\n');

    % ---- concentration ----
    w = sort(sum(u.cnt,2), 'descend');
    n10 = max(1, round(0.10*numel(w)));
    n25 = max(1, round(0.25*numel(w)));
    fprintf('concentration: top 10%% contribute %.1f%%, top 25%% contribute %.1f%%\n', ...
            100*sum(w(1:n10))/sum(w), 100*sum(w(1:n25))/sum(w));

    % ---- most-affected participants, and the summary without them ----
    hi = u(v > 50, :);
    if ~isempty(hi)
        fprintf('participants deviating on >50%% of trials: %s\n', ...
                strjoin(cellstr(hi.subject), ' '));
        fprintf('  they contribute %.1f%% of all deviations in this dataset\n', ...
                100*sum(hi.cnt(:))/tot);
        lo = u(v <= 50, :);
        fprintf('  excluding them: mean %.2f%%  median %.2f%%  (n=%d)\n', ...
                mean(lo.dev), median(lo.dev), height(lo));
        fprintf('  composition without them:');
        for k = 1:numel(CAT)
            fprintf('  %s %.1f%%', CAT(k), 100*sum(lo.cnt(:,k))/sum(lo.cnt(:)));
        end
        fprintf('\n');
    end

    row = table(DS(d), height(u), mean(v), std(v), ci(1), ci(2), median(v), ...
                prctile(v,25), prctile(v,75), 100*sum(w(1:n10))/sum(w), ...
                'VariableNames', {'dataset','n','mean','sd','ci_lo','ci_hi', ...
                                  'median','q25','q75','top10_share'});
    OUT = [OUT; row]; %#ok<AGROW>
end

writetable(OUT, 'HE_stats.csv');

% Anticipation is outside the five deviation categories and is reported
% separately; it is not part of the deviation rate.
fprintf('\nanticipation (%% of trials with any pre-cue onset):\n');
for d = 1:numel(DS)
    m = T.dataset == DS(d);
    fprintf('  %-10s %.2f\n', DS(d), 100*mean(T.antC(m) + T.antW(m) > 0));
end
end


function G = collapse(T, CAT, keys)
key = T.(keys(1));
for i = 2:numel(keys), key = key + "|" + T.(keys(i)); end
[u, ia] = unique(key, 'stable');

G = table();
for i = 1:numel(keys), G.(keys(i)) = T.(keys(i))(ia); end
G.n    = zeros(numel(u),1);
G.cnt  = zeros(numel(u), numel(CAT));
G.rate = zeros(numel(u), numel(CAT));
G.dev  = zeros(numel(u),1);

for i = 1:numel(u)
    m = (key == u(i));
    G.n(i) = sum(m);
    for k = 1:numel(CAT)
        G.cnt(i,k)  = sum(T.class(m) == CAT(k));
        G.rate(i,k) = 100 * G.cnt(i,k) / G.n(i);   % rate, not count, since
    end                                            % two sessions hold 51 trials
    G.dev(i) = 100 * sum(G.cnt(i,:)) / G.n(i);
end
end
