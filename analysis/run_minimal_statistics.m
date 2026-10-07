%% HE_TRIALS_SURVEY_STATISTICS_V10
% Uses the actual HE_trials.csv and survey_sum.xlsx column structures.
% MATLAB R2025b + Statistics and Machine Learning Toolbox
%
% INPUTS
%   HE_trials.csv   : one row per ME trial, as written by run_error_detection
%   survey_sum.xlsx : sheet "survey", one row per participant/session
%
% The script derives survey tasks from group/session, aligns rating direction,
% summarizes ME deviations, tests omnibus task effects, and tests the
% association between ME ratings and observed deviations. No exhaustive
% pairwise task comparisons are performed.

clear; clc;

%% -------------------------- USER SETTINGS -----------------------------
trialFile  = "HE_trials.csv";
surveyFile = "survey_sum.xlsx";
surveySheet = "survey";
outputDir = "stat_results";

% HE_trials.csv labels datasets by name, the survey by number.
% Position in this list is the survey's dataset number.
datasetNames = ["Gwon2023", "Gwon2024"];

dataset1Tasks = ["ME", "MI", "MO"];
meTask = "ME";

% Aligned direction: higher = more fatigue, more stress, better
% concentration, greater difficulty, and greater perceived accuracy.
ratingVars = ["fatigue_aligned", "stress_aligned", ...
              "concentration_aligned", "difficulty_aligned", ...
              "accuracy_aligned"];
ratingLabels = ["fatigue", "stress", "concentration", ...
                "difficulty", "accuracy"];

%% ---------------------------- LOAD DATA -------------------------------
trialFile = resolveInputFile(trialFile);
surveyFile = resolveInputFile(surveyFile);

T = readtable(trialFile, FileType="text", TextType="string", ...
    VariableNamingRule="preserve");
S = readtable(surveyFile, FileType="spreadsheet", Sheet=surveySheet, ...
    TextType="string", VariableNamingRule="preserve");

requiredTrial = ["trial", "class", "dataset", "task", ...
                 "subject", "session"];
requiredSurvey = ["dataset", "sub", "group", "session", ...
                  "fatigue", "stress", "concentration", ...
                  "difficulty", "accuracy"];
assertColumns(T, requiredTrial, trialFile);
assertColumns(S, requiredSurvey, surveyFile);

T.dataset = datasetNumber(T.dataset, datasetNames);
T.session = forceNumeric(T.session, "session");
T.subject = string(T.subject);
T.sub = subjectNumber(T.subject);
T.task = upper(strtrim(string(T.task)));
T.class = upper(strtrim(string(T.class)));

S.dataset = forceNumeric(S.dataset, "dataset");
S.sub = forceNumeric(S.sub, "sub");
S.group = forceNumeric(S.group, "group");
S.session = forceNumeric(S.session, "session");

rawRatingVars = ["fatigue", "stress", "concentration", ...
                 "difficulty", "accuracy"];
for v = rawRatingVars
    S.(v) = forceNumeric(S.(v), v);
end

assert(all(ismember(unique(T.dataset), [1 2])), ...
    "HE_trials contains a dataset other than 1 or 2.");
assert(all(ismember(unique(S.dataset), [1 2])), ...
    "survey_sum contains a dataset other than 1 or 2.");
assert(all(mod(S.group,1)==0 & mod(S.session,1)==0), ...
    "Survey group and session must be integers.");

if ~isfolder(outputDir), mkdir(outputDir); end

%% ------------------ DERIVE TASK FROM GROUP ORDER ----------------------
% Rows are group numbers; columns are chronological sessions 1--6.
sequenceD1 = [
    "ME", "MI", "ME", "MO", "MI", "MO";
    "ME", "MO", "ME", "MI", "MO", "MI";
    "MI", "ME", "MI", "MO", "ME", "MO";
    "MI", "MO", "MI", "ME", "MO", "ME";
    "MO", "MI", "MO", "ME", "MI", "ME";
    "MO", "ME", "MO", "MI", "ME", "MI"];

sequenceD2 = [
    "AO", "AO", "MI", "MI", "ME", "ME";
    "MI", "MI", "AO", "AO", "ME", "ME";
    "MO", "MO", "MI", "MI", "ME", "ME";
    "MI", "MI", "MO", "MO", "ME", "ME"];

S.task = deriveTask(S.dataset, S.group, S.session, sequenceD1, sequenceD2);

%% ---------------- ALIGN QUESTIONNAIRE DIRECTION -----------------------
% Dataset 2 fatigue, stress, and difficulty run opposite to Dataset 1 and
% are reverse-scored as 11-x. Concentration and accuracy already agree.
S.fatigue_aligned = S.fatigue;
S.stress_aligned = S.stress;
S.concentration_aligned = S.concentration;
S.difficulty_aligned = S.difficulty;
S.accuracy_aligned = S.accuracy;

idxD2 = S.dataset == 2;
S.fatigue_aligned(idxD2) = 11 - S.fatigue(idxD2);
S.stress_aligned(idxD2) = 11 - S.stress(idxD2);
S.difficulty_aligned(idxD2) = 11 - S.difficulty(idxD2);

% Dataset 1 uses a valid 0--10 scale; zero is retained as data.
validateRatingRanges(S);
writetable(S, fullfile(outputDir, "survey_prepared_with_task.csv"));

%% ---------------- PREPARE TRIAL-LEVEL DEVIATIONS ----------------------
T = T(T.task == meTask,:);
assert(~isempty(T), "No ME trials were found in HE_trials.");

validClasses = ["CORR", "MISS", "BOTH", "TERM", "COMP", "WRONG"];
unknownClasses = setdiff(unique(T.class), validClasses);
assert(isempty(unknownClasses), "Unknown HE class labels: %s", ...
    strjoin(unknownClasses, ", "));

sessionDev = aggregateTrialSessions(T);
participantDev = aggregateDeviationByParticipant(sessionDev);
deviationSummary = summarizeDeviation(participantDev, sessionDev);
categorySummary = summarizeClasses(T);

writetable(sessionDev, fullfile(outputDir, "me_session_deviation_rates.csv"));
writetable(participantDev, fullfile(outputDir, "participant_deviation_rates.csv"));
writetable(deviationSummary, fullfile(outputDir, "deviation_summary.csv"));
writetable(categorySummary, fullfile(outputDir, "deviation_category_summary.csv"));

%% -------------- CHECK ME SESSION MATCHING BETWEEN FILES --------------
surveyMeKeys = unique(S(S.task == meTask, ...
    ["dataset", "sub", "session"]), "rows");
trialMeKeys = unique(sessionDev(:,["dataset", "sub", "session"]), "rows");
surveyKey = makeKey(surveyMeKeys.dataset, surveyMeKeys.sub, surveyMeKeys.session);
trialKey = makeKey(trialMeKeys.dataset, trialMeKeys.sub, trialMeKeys.session);
unmatchedSurvey = surveyMeKeys(~ismember(surveyKey, trialKey),:);
unmatchedTrial = trialMeKeys(~ismember(trialKey, surveyKey),:);

if ~isempty(unmatchedSurvey)
    warning("%d survey rows are labeled ME by the supplied group order " + ...
        "but have no HE trial session. See unmatched_survey_ME.csv.", ...
        height(unmatchedSurvey));
    writetable(unmatchedSurvey, fullfile(outputDir, "unmatched_survey_ME.csv"));
end
if ~isempty(unmatchedTrial)
    warning("%d HE trial sessions have no corresponding ME survey row. " + ...
        "See unmatched_HE_ME.csv.", height(unmatchedTrial));
    writetable(unmatchedTrial, fullfile(outputDir, "unmatched_HE_ME.csv"));
end

%% ------------------ TASK EFFECT ON RATINGS ----------------------------
ratingDescriptives = makeRatingDescriptives(S, ratingVars, ratingLabels);
writetable(ratingDescriptives, fullfile(outputDir, "rating_descriptives.csv"));

omnibus = table();
for i = 1:numel(ratingVars)
    omnibus = [omnibus; repeatedMeasuresOmnibus(S, 1, dataset1Tasks, ...
        ratingVars(i), ratingLabels(i))]; %#ok<AGROW>
end
for i = 1:numel(ratingVars)
    omnibus = [omnibus; mixedModelOmnibus(S, 2, meTask, ...
        ratingVars(i), ratingLabels(i))]; %#ok<AGROW>
end

omnibus.p_fdr = nan(height(omnibus),1);
for ds = unique(omnibus.dataset, "stable")'
    idx = omnibus.dataset == ds;
    omnibus.p_fdr(idx) = bhFdr(omnibus.p_raw(idx));
end
writetable(omnibus, fullfile(outputDir, "rating_task_omnibus.csv"));

%% ------------ ASSOCIATION BETWEEN ME RATING AND DEVIATION ------------
joinedMe = joinMeSessions(sessionDev, S, ratingVars);
writetable(joinedMe, fullfile(outputDir, "ME_joined_analysis_input.csv"));

association = table();
for ds = [1 2]
    for i = 1:numel(ratingVars)
        association = [association; ratingDeviationGlmm(joinedMe, ds, ...
            ratingVars(i), ratingLabels(i))]; %#ok<AGROW>
    end
end

association.p_fdr = nan(height(association),1);
for ds = unique(association.dataset, "stable")'
    idx = association.dataset == ds;
    association.p_fdr(idx) = bhFdr(association.p_raw(idx));
end
writetable(association, fullfile(outputDir, "rating_deviation_association.csv"));

fprintf("Analysis complete. Results saved in: %s\n", outputDir);

%% ========================== LOCAL FUNCTIONS ===========================
function pathOut = resolveInputFile(fileName)
    candidates = [string(fileName), fullfile("upload", string(fileName))];
    idx = find(isfile(candidates), 1);
    assert(~isempty(idx), "Cannot find input file: %s", fileName);
    pathOut = candidates(idx);
end

function assertColumns(T, required, sourceName)
    present = string(T.Properties.VariableNames);
    missing = required(~ismember(required, present));
    assert(isempty(missing), "Missing columns in %s: %s", ...
        sourceName, strjoin(missing, ", "));
end

function x = forceNumeric(x, variableName)
    if ~isnumeric(x), x = str2double(string(x)); end
    x = double(x);
    if all(isnan(x)), error("Column '%s' could not be numeric.", variableName); end
end

function d = datasetNumber(x, names)
    if isnumeric(x), d = double(x); return; end   % already 1/2
    [known, d] = ismember(string(x), names);
    assert(all(known), "Unknown dataset label in HE_trials: %s", ...
        strjoin(unique(string(x(~known))), ", "));
end

function sub = subjectNumber(subject)
    token = regexp(cellstr(subject), '\d+', 'match', 'once');
    sub = str2double(string(token));
    assert(all(isfinite(sub)), "Could not extract numeric subject IDs.");
end

function task = deriveTask(dataset, group, session, seq1, seq2)
    task = strings(numel(dataset),1);
    for i = 1:numel(dataset)
        if dataset(i) == 1
            assert(group(i)>=1 && group(i)<=size(seq1,1), ...
                "Invalid Dataset 1 group at survey row %d.", i);
            assert(session(i)>=1 && session(i)<=size(seq1,2), ...
                "Invalid Dataset 1 session at survey row %d.", i);
            task(i) = seq1(group(i),session(i));
        elseif dataset(i) == 2
            assert(group(i)>=1 && group(i)<=size(seq2,1), ...
                "Invalid Dataset 2 group at survey row %d.", i);
            assert(session(i)>=1 && session(i)<=size(seq2,2), ...
                "Invalid Dataset 2 session at survey row %d.", i);
            task(i) = seq2(group(i),session(i));
        else
            error("Unknown dataset at survey row %d.", i);
        end
    end
end

function validateRatingRanges(S)
    basic = ["fatigue", "stress", "concentration", "difficulty"];
    idx1 = S.dataset == 1; idx2 = S.dataset == 2;
    for v = basic
        a = S.(v)(idx1); b = S.(v)(idx2);
        assert(all((a>=0 & a<=10) | isnan(a)), ...
            "Dataset 1 %s contains a value outside 0--10.", v);
        assert(all((b>=1 & b<=10) | isnan(b)), ...
            "Dataset 2 %s contains a value outside 1--10.", v);
    end
    assert(all((S.accuracy>=0 & S.accuracy<=100) | isnan(S.accuracy)), ...
        "accuracy contains a value outside 0--100.");
end

function D = aggregateTrialSessions(T)
    [G,dataset,sub,session] = findgroups(T.dataset,T.sub,T.session);
    validTrials = splitapply(@numel,T.trial,G);
    deviationCount = splitapply(@(x) sum(x~="CORR"),T.class,G);
    deviationRate = deviationCount./validTrials;
    D = table(dataset,sub,session,validTrials,deviationCount,deviationRate, ...
        VariableNames=["dataset","sub","session","valid_trials", ...
        "deviation_count","deviation_rate"]);
end

function P = aggregateDeviationByParticipant(D)
    [G,dataset,sub] = findgroups(D.dataset,D.sub);
    nSessions = splitapply(@numel,D.session,G);
    dev = splitapply(@sum,D.deviation_count,G);
    n = splitapply(@sum,D.valid_trials,G);
    rate = dev./n;
    P = table(dataset,sub,nSessions,dev,n,rate, ...
        VariableNames=["dataset","sub","n_sessions","deviation_count", ...
        "valid_trials","deviation_rate"]);
end

function S = summarizeDeviation(P,D)
    S = table();
    for ds = unique(P.dataset,"stable")'
        p=P(P.dataset==ds,:); d=D(D.dataset==ds,:);
        row=table(ds,height(p),height(d),sum(d.deviation_count), ...
            sum(d.valid_trials),sum(d.deviation_count)/sum(d.valid_trials), ...
            finiteMean(p.deviation_rate),finiteStd(p.deviation_rate), ...
            finiteMedian(p.deviation_rate),finiteIqr(p.deviation_rate), ...
            VariableNames=["dataset","n_subjects","n_sessions", ...
            "total_deviations","total_valid_trials","pooled_rate", ...
            "participant_mean","participant_sd","participant_median", ...
            "participant_iqr"]);
        S=[S;row]; %#ok<AGROW>
    end
end

function S = summarizeClasses(T)
    S=table();
    for ds=unique(T.dataset,"stable")'
        td=T(T.dataset==ds,:); nSubjects=numel(unique(td.sub));
        totalDev=sum(td.class~="CORR");
        classes=setdiff(unique(td.class,"stable"),"CORR","stable");
        for c=classes'
            tc=td(td.class==c,:); count=height(tc);
            row=table(ds,c,count,50*count/height(td), ...
                count/max(totalDev,1),numel(unique(tc.sub))/nSubjects, ...
                VariableNames=["dataset","category","count", ...
                "count_per_50_trials","composition","prevalence"]);
            S=[S;row]; %#ok<AGROW>
        end
    end
end

function key = makeKey(dataset,sub,session)
    key=string(dataset)+"|"+string(sub)+"|"+string(session);
end

function S = makeRatingDescriptives(R,ratingVars,ratingLabels)
    S=table();
    for ds=unique(R.dataset,"stable")'
        tasks=unique(R.task(R.dataset==ds),"stable");
        for task=tasks'
            rt=R(R.dataset==ds & R.task==task,:);
            for i=1:numel(ratingVars)
                [G,~]=findgroups(rt.sub);
                values=splitapply(@finiteMean,rt.(ratingVars(i)),G);
                values=values(isfinite(values));
                row=table(ds,task,ratingLabels(i),numel(values), ...
                    finiteMean(values),finiteStd(values), ...
                    finiteMedian(values),finiteIqr(values), ...
                    VariableNames=["dataset","task","rating","n_subjects", ...
                    "mean","sd","median","iqr"]);
                S=[S;row]; %#ok<AGROW>
            end
        end
    end
end

function out = repeatedMeasuresOmnibus(R,dataset,tasks,ratingVar,ratingLabel)
    r=R(R.dataset==dataset & ismember(R.task,tasks),:);
    subjects=unique(r.sub,"stable"); Y=nan(numel(subjects),numel(tasks));
    for i=1:numel(subjects)
        for j=1:numel(tasks)
            idx=r.sub==subjects(i) & r.task==tasks(j);
            if any(idx)
                Y(i,j)=finiteMean(r.(ratingVar)(idx));
            end
        end
    end
    complete=all(isfinite(Y),2); Y=Y(complete,:); nExcluded=sum(~complete);
    assert(size(Y,1)>=3,"Too few complete participants for %s.",ratingLabel);
    taskNames=matlab.lang.makeValidName(cellstr(tasks));
    wide=array2table(Y,VariableNames=taskNames);
    within=table(categorical(tasks(:)),VariableNames="Task");
    rm=fitrm(wide,sprintf("%s-%s ~ 1",taskNames{1},taskNames{end}), ...
        WithinDesign=within);
    ra=ranova(rm,WithinModel="Task");
    rn=lower(string(ra.Properties.RowNames));
    effectIdx=find(contains(rn,"task") & ~contains(rn,"error"),1);
    errorIdx=find(contains(rn,"error") & contains(rn,"task"),1);
    pUncorrected=ra.pValue(effectIdx);
    pGG=getTableValue(ra,effectIdx,"pValueGG",NaN);
    mauchlyP=NaN; epsilonGG=1;
    try
        mt=mauchly(rm); mauchlyP=getTableValue(mt,1,"pValue",NaN);
        et=epsilon(rm);
        epsilonGG=getTableValueContaining(et,1,"greenhouse",1);
    catch
    end
    if isfinite(mauchlyP) && mauchlyP<.05 && isfinite(pGG)
        pUsed=pGG; correction="Greenhouse-Geisser";
        df1=ra.DF(effectIdx)*epsilonGG; df2=ra.DF(errorIdx)*epsilonGG;
    else
        pUsed=pUncorrected; correction="none";
        df1=ra.DF(effectIdx); df2=ra.DF(errorIdx);
    end
    etaPartial=ra.SumSq(effectIdx)/(ra.SumSq(effectIdx)+ra.SumSq(errorIdx));
    out=table(dataset,ratingLabel,"RM-ANOVA",size(Y,1),nExcluded, ...
        ra.F(effectIdx),df1,df2,pUncorrected,pGG,mauchlyP,correction, ...
        etaPartial,pUsed,VariableNames=["dataset","rating","model", ...
        "n_subjects","n_excluded_incomplete","statistic","df1","df2", ...
        "p_uncorrected","p_greenhouse_geisser","mauchly_p", ...
        "correction","effect_size","p_raw"]);
end

function out = mixedModelOmnibus(R,dataset,referenceTask,ratingVar,ratingLabel)
    r=R(R.dataset==dataset,:); r=r(isfinite(r.(ratingVar)),:);
    [G,sub,task]=findgroups(r.sub,r.task);
    value=splitapply(@finiteMean,r.(ratingVar),G);
    t=table(categorical(sub),categorical(task),value, ...
        VariableNames=["subject","task","rating_value"]);
    t=t(isfinite(t.rating_value),:);
    cats=string(categories(t.task));
    assert(ismember(referenceTask,cats),"Reference task is absent.");
    t.task=reordercats(t.task,cellstr([referenceTask;cats(cats~=referenceTask)]));
    lme=fitlme(t,"rating_value ~ task + (1|subject)", ...
        FitMethod="REML",DummyVarCoding="reference");
    beta=fixedEffects(lme);
    H=[zeros(numel(beta)-1,1),eye(numel(beta)-1)];
    C=zeros(size(H,1),1);
    [pValue,Fstat,df1,df2]=coefTest(lme,H,C, ...
        'DFMethod','satterthwaite');
    out=table(dataset,ratingLabel,"LMM",numel(unique(t.subject)),0, ...
        Fstat,df1,df2,pValue,NaN,NaN,"not applicable",NaN,pValue, ...
        VariableNames=["dataset","rating","model","n_subjects", ...
        "n_excluded_incomplete","statistic","df1","df2", ...
        "p_uncorrected","p_greenhouse_geisser","mauchly_p", ...
        "correction","effect_size","p_raw"]);
end

function J = joinMeSessions(D,S,ratingVars)
    cols=["dataset","sub","session",ratingVars];
    sm=S(S.task=="ME",cols);
    [G,dataset,sub,session]=findgroups(sm.dataset,sm.sub,sm.session);
    Jsurvey=table(dataset,sub,session);
    for v=ratingVars
        Jsurvey.(v)=splitapply(@finiteMean,sm.(v),G);
    end
    J=innerjoin(D,Jsurvey,Keys=["dataset","sub","session"]);
end

function out = ratingDeviationGlmm(J,dataset,ratingVar,ratingLabel)
    t=J(J.dataset==dataset,:);
    t=t(isfinite(t.(ratingVar)) & t.valid_trials>0,:);
    t.rating_value=double(t.(ratingVar));
    t.valid_trials=round(double(t.valid_trials));
    t.deviation_count=round(double(t.deviation_count));
    nSubjects=numel(unique(t.sub)); nSessions=height(t);
    modelStatus="ok";
    modelError="";
    try
        assert(all(t.valid_trials>=1 & mod(t.valid_trials,1)==0), ...
            "valid_trials must contain positive integers.");
        assert(all(t.deviation_count>=0 & ...
            t.deviation_count<=t.valid_trials & ...
            mod(t.deviation_count,1)==0), ...
            "deviation_count must be an integer from 0 to valid_trials.");

        % fitglme can reject session proportions supplied with BinomialSize
        % because response*BinomialSize may not be represented as an exact
        % integer. Reconstruct the equivalent Bernoulli rows from the two
        % integer counts instead. This preserves zero-deviation sessions.
        totalTrials=sum(t.valid_trials);
        trialSubject=strings(totalTrials,1);
        trialRating=zeros(totalTrials,1);
        trialDeviation=zeros(totalTrials,1);
        firstRow=1;
        for row=1:height(t)
            lastRow=firstRow+t.valid_trials(row)-1;
            rows=firstRow:lastRow;
            trialSubject(rows)=string(t.sub(row));
            trialRating(rows)=t.rating_value(row);
            nDeviation=t.deviation_count(row);
            if nDeviation>0
                trialDeviation(firstRow:firstRow+nDeviation-1)=1;
            end
            firstRow=lastRow+1;
        end
        trialData=table(categorical(trialSubject),trialRating, ...
            trialDeviation,VariableNames=["subject","rating_value", ...
            "deviation"]);

        glme=fitglme(trialData, ...
            'deviation ~ rating_value + (1|subject)', ...
            'Distribution','Binomial', ...
            'Link','logit', ...
            'FitMethod','Laplace');

        [beta,betaNames,statsFixed]=fixedEffects(glme);
        if istable(betaNames)
            if ismember("Name",string(betaNames.Properties.VariableNames))
                coefficientNames=string(betaNames.Name);
            else
                coefficientNames=string(betaNames{:,1});
            end
        else
            coefficientNames=string(betaNames);
        end
        idx=find(coefficientNames=="rating_value",1);
        assert(~isempty(idx),"rating_value coefficient was not found.");

        estimate=beta(idx);
        oddsRatio=exp(estimate);
        ciLow=exp(statsFixed.Lower(idx));
        ciHigh=exp(statsFixed.Upper(idx));
        pValue=statsFixed.pValue(idx);
    catch ME
        warning("GLMM failed for Dataset %d, %s: %s",dataset,ratingLabel,ME.message);
        estimate=NaN; oddsRatio=NaN; ciLow=NaN; ciHigh=NaN; pValue=NaN;
        modelStatus="failed";
        modelError=string(ME.message);
    end
    out=table(dataset,ratingLabel,nSubjects,nSessions,estimate,oddsRatio, ...
        ciLow,ciHigh,pValue,modelStatus,modelError, ...
        VariableNames=["dataset","rating","n_subjects", ...
        "n_sessions","log_odds_beta","odds_ratio","ci95_low", ...
        "ci95_high","p_raw","model_status","model_error"]);
end

function q = bhFdr(p)
    q=nan(size(p)); valid=isfinite(p); pv=p(valid);
    if isempty(pv), return; end
    [ps,order]=sort(pv); m=numel(ps);
    qs=ps.*m./(1:m)'; qs=flipud(cummin(flipud(qs))); qs=min(qs,1);
    restored=nan(m,1); restored(order)=qs; q(valid)=restored;
end

function value = getTableValue(T,row,requestedName,defaultValue)
    names=string(T.Properties.VariableNames);
    idx=find(strcmpi(names,requestedName),1);
    if isempty(idx), value=defaultValue; else, value=T{row,idx}; end
end

function value = getTableValueContaining(T,row,fragment,defaultValue)
    names=lower(string(T.Properties.VariableNames));
    idx=find(contains(names,lower(fragment)),1);
    if isempty(idx), value=defaultValue; else, value=T{row,idx}; end
end

function m = finiteMean(x)
    x=double(x(:));
    x=x(isfinite(x));
    if isempty(x)
        m=NaN;
    else
        m=sum(x)/numel(x);
    end
end

function s = finiteStd(x)
    x=double(x(:));
    x=x(isfinite(x));
    n=numel(x);
    if n==0
        s=NaN;
    elseif n==1
        s=0;
    else
        m=sum(x)/n;
        s=sqrt(sum((x-m).^2)/(n-1));
    end
end

function m = finiteMedian(x)
    x=sort(double(x(isfinite(x))));
    n=numel(x);
    if n==0
        m=NaN;
    elseif mod(n,2)==1
        m=x((n+1)/2);
    else
        m=(x(n/2)+x(n/2+1))/2;
    end
end

function value = finiteIqr(x)
    x=sort(double(x(isfinite(x))));
    if isempty(x)
        value=NaN;
        return;
    end
    value=finitePercentile(x,0.75)-finitePercentile(x,0.25);
end

function value = finitePercentile(sortedX,p)
    n=numel(sortedX);
    if n==1
        value=sortedX(1);
        return;
    end
    position=1+(n-1)*p;
    lower=floor(position);
    upper=ceil(position);
    fraction=position-lower;
    value=sortedX(lower)+fraction*(sortedX(upper)-sortedX(lower));
end