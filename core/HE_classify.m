function T = HE_classify(onR, onL, cue_t, cue_side, c)
% Three windows per trial, all anchored on the cue (not on the first
% detection, so boundaries do not move with response latency):
%
%   ant  [cue - pre_win, cue)                movement before the go signal
%   set  [cue, cue + exec_len + residual)    any number of crossings = 1 response
%   post [set_end, next cue - pre_win)       counted, merged by post_refrac
%
% The anticipation window exists because activity just before a cue is
% preparation for that trial, not a late error in the previous one. Without
% it, a small pre-cue burst on the upcoming hand lands in the previous
% trial's post window and scores BOTH there - an error in the wrong place.
% It is recorded in antC / antW and kept out of numC / numW, so the six
% outcome categories are unchanged and anticipation can be reported on its
% own. Nothing is discarded: every detection lands in some window.
%
% Taxonomy:
%   numC numW
%    1    0   CORR
%   >=2   0   TERM     repetition on the cued side
%    0    0   MISS
%    0   >=1  WRONG    non-cued side only, regardless of count
%    1    1   BOTH
%   else      COMP     both sides active, three or more responses total

n       = numel(cue_t);
set_end = c.exec_len + c.residual;
pre     = c.pre_win;

trial = (1:n).';
numC  = zeros(n,1); numW  = zeros(n,1);
setC  = zeros(n,1); postC = zeros(n,1); antC = zeros(n,1);
setW  = zeros(n,1); postW = zeros(n,1); antW = zeros(n,1);
cls   = strings(n,1);

for i = 1:n
    t0 = cue_t(i);
    a  = t0 + set_end;
    if i < n, b = cue_t(i+1) - pre;      % observed ISI absorbs the jitter
    else,     b = t0 + c.isi_min - pre; end
    b = max(a, b);

    [sR, pR, aR] = count_side(onR, t0, a, b, pre, c.post_refrac);
    [sL, pL, aL] = count_side(onL, t0, a, b, pre, c.post_refrac);

    if cue_side(i) == 1        % left cue
        setC(i)=sL; postC(i)=pL; antC(i)=aL; setW(i)=sR; postW(i)=pR; antW(i)=aR;
    else                       % right cue
        setC(i)=sR; postC(i)=pR; antC(i)=aR; setW(i)=sL; postW(i)=pL; antW(i)=aL;
    end
    numC(i) = setC(i) + postC(i);
    numW(i) = setW(i) + postW(i);
    cls(i)  = classify_one(numC(i), numW(i));
end

T = table(trial, cue_t(:), cue_side(:), numC, numW, ...
          setC, postC, antC, setW, postW, antW, cls, ...
    'VariableNames', {'trial','cue_t','cue_side','numC','numW', ...
                      'setC','postC','antC','setW','postW','antW','class'});
end


function [nset, npost, nant] = count_side(on, t0, a, b, pre, refrac)
% set window collapses to a single response: the instructed sequence was
% two consecutive grasps, which count as one compliant execution
nset = double(any(on >= t0 & on < a));
nant = double(any(on >= t0 - pre & on < t0));

p     = on(on >= a & on < b);
npost = 0;
last  = -inf;
for k = 1:numel(p)
    if p(k) >= last + refrac
        npost = npost + 1;
        last  = p(k);
    end
end
end


function k = classify_one(numC, numW)
if     numC == 0 && numW == 0, k = "MISS";
elseif numC == 1 && numW == 0, k = "CORR";
elseif numC >= 2 && numW == 0, k = "TERM";
elseif numC == 0 && numW >= 1, k = "WRONG";
elseif numC == 1 && numW == 1, k = "BOTH";
else,                          k = "COMP";
end
end