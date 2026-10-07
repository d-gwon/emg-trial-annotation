function HE_figure_results(csv)
% Results figure from HE_trials.csv.
%   left   per-session accuracy (% CORR), violin with median and quartiles
%   right  per-session count of each error category, mean +- SD with points
%
% Unit of analysis is the session (one file), not the trial.

if nargin < 1, csv = 'HE_trials.csv'; end
T = readtable(csv, 'TextType', 'string');

CAT = ["MISS" "WRONG" "TERM" "BOTH" "COMP"];
LBL = {'Miss','Wrong','Term','Both','Comp'};
DS  = unique(T.dataset, 'stable');
COL = [0.55 0.45 0.78; 0.25 0.65 0.95];

% ---- collapse to one row per session ----
key = T.dataset + "|" + T.subject + "|" + T.session;
[u, ia] = unique(key, 'stable');
S = table(T.dataset(ia), 'VariableNames', {'dataset'});
S.acc = zeros(numel(u),1);
S.cnt = zeros(numel(u), numel(CAT));
for i = 1:numel(u)
    m = (key == u(i));
    S.acc(i) = 100 * mean(T.class(m) == "CORR");
    for k = 1:numel(CAT), S.cnt(i,k) = sum(T.class(m) == CAT(k)); end
end
fprintf('%d sessions\n', height(S));

figure('Color','w','Position',[80 80 980 400]);

% ---- left: accuracy violins ----
subplot(1,3,1); hold on
for d = 1:numel(DS)
    v = S.acc(S.dataset == DS(d));
    [xs, f] = kde1(v);
    f = 0.38 * f / max(f);
    patch([d+f, fliplr(d-f)], [xs, fliplr(xs)], COL(d,:), ...
          'FaceAlpha', 0.5, 'EdgeColor', COL(d,:)*0.6, 'LineWidth', 1);
    q = prctile(v, [25 50 75]);
    plot(d + 0.38*[-1 1], [q(2) q(2)], '--', 'Color', COL(d,:)*0.5, 'LineWidth', 1.2);
    plot(d + 0.28*[-1 1], [q(1) q(1)], ':',  'Color', COL(d,:)*0.5);
    plot(d + 0.28*[-1 1], [q(3) q(3)], ':',  'Color', COL(d,:)*0.5);
end
xlim([0.4 numel(DS)+0.6]); xticks(1:numel(DS)); xticklabels(cellstr(DS));
ylabel('Accuracy (%)'); ylim([0 102]);
set(gca,'Box','off','TickDir','out','FontSize',11);

% ---- right: error counts ----
subplot(1,3,[2 3]); hold on
w = 0.34;  h = gobjects(1, numel(DS));
for d = 1:numel(DS)
    off = (d - (numel(DS)+1)/2) * w;
    for k = 1:numel(CAT)
        v = S.cnt(S.dataset == DS(d), k);
        x = k + off;
        h(d) = bar(x, mean(v), w*0.85, 'FaceColor', COL(d,:), ...
                   'FaceAlpha', 0.45, 'EdgeColor', COL(d,:)*0.7);
        errorbar(x, mean(v), 0, std(v), 'Color', COL(d,:)*0.5, ...
                 'LineWidth', 1, 'CapSize', 6);
        jit = (rand(numel(v),1) - 0.5) * w * 0.6;
        scatter(x + jit, v, 14, COL(d,:), 'filled', 'MarkerFaceAlpha', 0.65);
    end
end
xticks(1:numel(CAT)); xticklabels(LBL); xlim([0.4 numel(CAT)+0.6]);
ylabel('Num of Error');
legend(h, cellstr(DS), 'Location', 'northeastoutside', 'Box', 'off');
set(gca,'Box','off','TickDir','out','FontSize',11);

% A session sitting at the trial count (e.g. 50 WRONG or 50 BOTH) is a
% pipeline failure, not participant behaviour. Check HE_check_laterality
% and the re-referencing before reaching for a broken axis.
bad = any(S.cnt >= 0.9 * max(sum(S.cnt,2)), 2);
if any(bad)
    fprintf('\n%d session(s) saturate one category:\n', sum(bad));
    disp(S(bad,:));
end
end


function [xs, f] = kde1(v)
v = v(:);  n = numel(v);
h = 1.06 * std(v) * n^(-1/5);
if ~isfinite(h) || h <= 0, h = 1; end
xs = linspace(max(0, min(v)-3*h), min(100, max(v)+3*h), 200);
f  = zeros(size(xs));
for i = 1:n, f = f + exp(-0.5*((xs - v(i))/h).^2); end
f = f / (n*h*sqrt(2*pi));
end
