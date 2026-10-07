function HE_plot(S, D, T, c, trange)
% Visual check of one recording.
%   HE_plot(S, D, T, c)              whole session
%   HE_plot(S, D, T, c, [200 320])   zoom, seconds
%
% Top    per-trial outcome raster, plus the raw detections on each side
% Middle left  MAV with threshold and detected onsets
% Bottom right MAV with threshold and detected onsets
%
% Cue lines are red for a left cue and blue for a right cue. The shaded
% band after each cue is the set window; anything detected past it is a
% post-window response and drives TERM / COMP.

if nargin < 5 || isempty(trange), trange = [0 max(D.mav_t)]; end

CLS = {'TERM','MISS','WRONG','BOTH','COMP'};
COL = [0.90 0.60 0.00      % TERM
       0.00 0.75 0.75      % MISS
       0.00 0.60 0.00      % WRONG
       0.85 0.00 0.85      % BOTH
       0.93 0.85 0.00];    % COMP

onR  = D.onset{1};
onL  = D.onset{2};
cue  = T.cue_t(:).';
side = T.cue_side(:).';
cls  = string(T.class);
sw   = c.exec_len + c.residual;

figure('Color','w','Position',[60 60 1350 640]);
ax = gobjects(1,3);

% ---------- panel 1: outcome raster ----------
ax(1) = subplot(3,1,1); hold on
band(cue, sw, [-0.5 3.5]);
cuelines(cue, side, [-0.5 3.5]);

plot(onR, zeros(size(onR)), '*', 'Color', [0 0 0.85], 'MarkerSize', 4);
plot(onL, ones(size(onL)),  '*', 'Color', [0.85 0 0], 'MarkerSize', 4);
plot(cue(cls=="CORR"), 2*ones(1,sum(cls=="CORR")), 'k*', 'MarkerSize', 4);

h = gobjects(1, numel(CLS));
for k = 1:numel(CLS)
    m  = (cls == CLS{k});
    xk = cue(m);
    yk = 3*ones(1, sum(m));
    if isempty(xk), xk = NaN; yk = NaN; end   % plot([],[]) returns no handle
    h(k) = plot(xk, yk, 'o', 'MarkerSize', 6, ...
                'MarkerFaceColor', COL(k,:), 'MarkerEdgeColor', 'none');
end
ylim([-0.5 3.5]); yticks(0:3);
yticklabels({'Detected Right','Detected Left','Correct','Error'});
legend(h, CLS, 'Location', 'eastoutside', 'Box', 'off');
title(sprintf('%s   %d trials   CORR %d / TERM %d / MISS %d / WRONG %d / BOTH %d / COMP %d', ...
      strrep(S.name,'_','\_'), height(T), ...
      sum(cls=="CORR"), sum(cls=="TERM"), sum(cls=="MISS"), ...
      sum(cls=="WRONG"), sum(cls=="BOTH"), sum(cls=="COMP")), ...
      'FontWeight', 'normal');

% ---------- panels 2-3: MAV ----------
lbl = {'Left EMG Power', 'Right EMG Power'};
for p = 1:2
    s  = 3 - p;                     % row 2 = L, row 1 = R
    on = D.onset{s};
    ax(p+1) = subplot(3,1,p+1); hold on

    yt = max(D.mav(s, D.mav_t >= trange(1) & D.mav_t <= trange(2)));
    if isempty(yt) || ~isfinite(yt), yt = 1; end
    yl = [0 yt*1.15];

    band(cue, sw, yl);
    cuelines(cue, side, yl);
    plot(D.mav_t, D.mav(s,:), 'k', 'LineWidth', 0.5);
    hl = yline(D.thr(s), '--'); hl.Color = [0.3 0.3 0.3];
    plot(on, yt*1.05*ones(size(on)), 'o', 'MarkerSize', 5, ...
         'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'none');
    ylim(yl); ylabel(lbl{p});
end
xlabel('Time (s)');

linkaxes(ax, 'x'); xlim(ax(1), trange);
set(ax, 'Box', 'off', 'TickDir', 'out');
end


function cuelines(cue, side, yl)
for i = 1:numel(cue)
    if side(i) == 1, col = [1 0.4 0.4]; else, col = [0.4 0.4 1]; end
    plot([cue(i) cue(i)], yl, '-', 'Color', col, 'LineWidth', 0.5);
end
end


function band(cue, sw, yl)
for i = 1:numel(cue)
    patch([cue(i) cue(i)+sw cue(i)+sw cue(i)], [yl(1) yl(1) yl(2) yl(2)], ...
          [0.92 0.92 0.92], 'EdgeColor', 'none');
end
end