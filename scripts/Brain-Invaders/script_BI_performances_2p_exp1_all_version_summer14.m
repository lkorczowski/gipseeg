% this script is made to load and evaluate a data set of EEG with several
% users.
% All the results should be saved in the structure 'Results'
% All the parameters can be saved in the structure 'Parameters'
clear all;
close all

Directory= 'D:\data\Hyperscanning\BI-multiplayers\Groups\'

% INPUT, LOADING FILES and PARAMETERS

%load epoch data with manually labeled artifacts in struc ALLdata
% Xte : epochs, Yte : class labels, isBad : rejected epochs
load([Directory 'ALLgroups.mat'])

%load index and name of groups
load([Directory 'Groups.mat'])

%OUTPUT FILE NAME
SAVEFILE='results_GROUPS_AUC_STATS_ALL.mat';

%if results file already exist, load it
%if exist([Directory SAVEFILE])
%load([Directory SAVEFILE]) % should content 'Results' and 'Parameters'
%else
load( [Directory 'results_AUC_STATS_all_VS_intra_vsMAPPING_P0_25.mat'],'BImap')
%%prepare parameters file
clear Parameters
Parameters.method_mean = {'ld'}; % PARAMETER
Parameters.method_dist = {'riemann'}; %PARAMETER
Parameters.nusers=2;
Parameters.BImap=BImap; % PARAMETER #3
Parameters.Stats={'all', 'intra'};% PARAMETER #2
Parameters.TRIALS=1:size(AUC,4); % PARAMETER #4
Parameters.GroupsName=ALLgroups;
Parameters.EIG={'all','limited'}
Parameters.P300_ref_orientation={'multiP1'} % PARAMETER
Parameters.RND=[]; %random seed for training/test set
Parameters.TestSetRatio={0.25};
%end
%% generate global parameters
clear all
Directory= 'D:\data\Hyperscanning\BI-multiplayers\Groups\'
load( [Directory 'results_AUC_STATS_all_VS_intra_vsMAPPING_P0_25.mat'],'BImap')
load([Directory 'Groups.mat'])
load([Directory 'ALLgroups.mat'])
clear Parameters
Parameters.method_mean = {'ld'}; % PARAMETER
Parameters.method_dist = {'riemann'}; %PARAMETER
Parameters.nusers=2;
Parameters.BImap=BImap; % PARAMETER #3
Parameters.Stats={'all', 'intra'};% PARAMETER #2
Parameters.GroupsName=ALLgroups;
Parameters.EIG={0}%,1,2,3,4,5,6,7,8,9,10,1:4,2:5,3:6,4:8,5:9,6:10}
Parameters.P300_ref_orientation={'multiP1'} % PARAMETER
Parameters.RND=[]; %random seed for training/test set
Parameters.TestSetRatio={0.75 0.25,0.5,0.625,0.75};
Parameters.Trials=1;
%%generate single trial parameters
%{
             method_mean: {'ld'}
             method_dist: {'riemann'}
                  nusers: 2
                   BImap: {1x9 cell}
                   Stats: {'all'  'intra'}
              GroupsName: {19x1 cell}
                     EIG: {'all'  'limited'}
    P300_ref_orientation: {'multiP1'}
                     RND: []
%}
indP=1;
clear P
%for TrialInd=1:25
for GroupsInd=1:2%length(Parameters.GroupsName)
    for P300ind=1:length(Parameters.P300_ref_orientation)
    for StatsInd=1:length(Parameters.Stats)
        for EIGInd=1:length(Parameters.EIG)
            for TestTrainInd=1:length(Parameters.TestSetRatio)
            INDEX={'method_mean',1;
                'method_dist',1;
                'nusers',1;
                'BImap',3;
                'Stats',StatsInd;
                'GroupsName',GroupsInd;
                'EIG',EIGInd;
                'P300_ref_orientation',P300ind;
                'RND',1;
                'TestSetRatio',TestTrainInd};
            tmp=generateParam(Parameters,INDEX);
            BOOL=1;
            if exist('P')
            for tmpIND=1:length(P)
                if isequal(P(tmpIND),tmp)
                    BOOL=0;
                end
            end
            end
            if BOOL
                P(indP)=tmp;
                fprintf('added ')
            end
            indP=indP+1;
        end
    end
    end
    end
end
fprintf('\n')
length(P)
%load('D:\data\Hyperscanning\BI-multiplayers\results_Groups.mat','R')

%%
%close all
%P(1).RND=[];
maxTest=length(P)
R.P=P;
R.Parameters=Parameters;
MaxTrial=25;
NbGroups=length(Parameters.GroupsName);

%only for generate new seed
R.RNDseed=cell(MaxTrial,NbGroups);
tic
for TrialInd=1:1
    
    for TestInd=1:maxTest
        
        P(TestInd).RND=R.RNDseed{TrialInd,strcmp(Parameters.GroupsName,P(TestInd).GroupsName)};
        
        [R.AUCall{TrialInd,TestInd}...
            R.Scores{TrialInd,TestInd}...
            R.Distances{TrialInd,TestInd}...
            R.ConfM{TrialInd,TestInd}...
            R.Perf{TrialInd,TestInd}...
            R.EIG{TrialInd,TestInd}...
            R.RNDseed{TrialInd,strcmp(Parameters.GroupsName,P(TestInd).GroupsName)}...
            R.P1{TrialInd,TestInd}]=...
            mdm_chain_hyper(ALLdata,Parameters,P(TestInd));
        
        
    end
end
directory='D:\data\Hyperscanning\BI-multiplayers\Groups\Results\';
    save([directory 'results_Groups_' datestr(now,30) '.mat'],'R')

toc
%% plot analysis
nbsections=20;
figure
autoSubplot(2,hist(R.Scores{1},nbsections),hist(R.Scores{2},nbsections));
figure
autoSubplot(2,hist(R.Distances{1}(:,1),nbsections),hist(R.Distances{1}(:,2),nbsections),hist(R.Distances{2}(:,1),nbsections),hist(R.Distances{2}(:,2),nbsections));
figure
autoSubplot(2,hist(R.EIG{INDICEALL},nbsections),hist(R.EIG{INDICEALL}(:,2),nbsections));

%% EIGvalues analysis

for EIGind=1:length(R.Parameters.EIG)
EIGindex=ParametersIndex(P,'EIG',R.Parameters.EIG{EIGind});
INTRA=ParametersIndex(P,'Stats',R.Parameters.Stats{2});
INTER=ParametersIndex(P,'Stats',R.Parameters.Stats{1});
GROUPS=~ParametersIndex(P,'GroupsName',R.Parameters.GroupsName{12})|ParametersIndex(P,'GroupsName',R.Parameters.GroupsName{18});

PerfINTRA(EIGind)=mean(mean([R.AUCall{:,EIGindex&INTRA&GROUPS}]));
PerfINTER(EIGind)=mean(mean([R.AUCall{:,EIGindex&INTER&GROUPS}]));

end

figure;plot(PerfINTER);hold all;plot(PerfINTRA);legend(Parameters.Stats)
set(gca,'XTick',1:17,'XTickLabel',cellfun(@num2str,Parameters.EIG,'UniformOutput',0))
rotateticklabel(gca)
ylabel('AUC ROC')

%% Performances analysis

%% Performances Analysis
close all
f1=figure
title('lol')
subplot(121)
%for GroupInd=[1 2 3 4 5 6 7 8 9 10 11 13 14 15 16 17 19]
    
SOLO=ParametersIndex(P,'Stats',R.Parameters.Stats{3});
INTRA=ParametersIndex(P,'Stats',R.Parameters.Stats{2});
INTER=ParametersIndex(P,'Stats',R.Parameters.Stats{1});

NOP1=ParametersIndex(P,'P300_ref_orientation',R.Parameters.P300_ref_orientation{2});
MULTIP1=ParametersIndex(P,'P300_ref_orientation',R.Parameters.P300_ref_orientation{1});

GROUPS=~(ParametersIndex(P,'GroupsName',R.Parameters.GroupsName{12})|ParametersIndex(P,'GroupsName',R.Parameters.GroupsName{18}));

PerfINTRA=[R.AUCall{:,INTRA&~MULTIP1}];
PerfINTER=[R.AUCall{:,INTER&~MULTIP1}];
PerfSOLO=[R.AUCall(:,SOLO&~MULTIP1)];
PerfSOLO1=cellfun(@(x) x{1},PerfSOLO);
PerfSOLO2=cellfun(@(x) x{2},PerfSOLO);


boxplot([PerfSOLO1(:) PerfSOLO2(:) PerfINTRA' PerfINTER'])
disp(GroupInd)
set(gca,'XTick', 1:4);set(gca,'XTickLabel', {'P1' 'P2' 'INTRA' 'INTRA+INTER'})
ylabel('ROC AUC score')
subplot(122)
%for GroupInd=[1 2 3 4 5 6 7 8 9 10 11 13 14 15 16 17 19]
    
SOLO=ParametersIndex(P,'Stats',R.Parameters.Stats{3});
INTRA=ParametersIndex(P,'Stats',R.Parameters.Stats{2});
INTER=ParametersIndex(P,'Stats',R.Parameters.Stats{1});

NOP1=ParametersIndex(P,'P300_ref_orientation',R.Parameters.P300_ref_orientation{2});
MULTIP1=ParametersIndex(P,'P300_ref_orientation',R.Parameters.P300_ref_orientation{1});

GROUPS=~(ParametersIndex(P,'GroupsName',R.Parameters.GroupsName{12})|ParametersIndex(P,'GroupsName',R.Parameters.GroupsName{18}));

PerfINTRA=[R.AUCall{:,INTRA&MULTIP1}];
PerfINTER=[R.AUCall{:,INTER&MULTIP1}];
PerfSOLO=[R.AUCall(:,SOLO&MULTIP1)];
PerfSOLO1=cellfun(@(x) x{1},PerfSOLO);
PerfSOLO2=cellfun(@(x) x{2},PerfSOLO);


boxplot([PerfSOLO1(:) PerfSOLO2(:) PerfINTRA' PerfINTER'])
hold all
disp(GroupInd)
set(gca,'XTick', 1:4);set(gca,'XTickLabel', {'P1' 'P2' 'INTRA' 'INTRA+INTER'})
        saveas(f1,[directory 'figures\' 'ROC' 'all' '.jpeg'])

%end
%%
mean(mean(xcorr(R.P1{1,1}(:,:,1),R.P1{2,1}(:,:,1))))
%plot(R.P1{:,1}(:,:,1)')
%%
figure;plot(PerfINTER);hold all;plot(PerfINTRA);legend(Parameters.Stats)
set(gca,'XTick',1:17,'XTickLabel',cellfun(@num2str,Parameters.EIG,'UniformOutput',0))
rotateticklabel(gca)
ylabel('AUC ROC')

%% load all data
clear all
close all
Stats={'all', 'intra'}
Directory= 'D:\data\Hyperscanning\BI-multiplayers\Groups\'

load([Directory 'Groups.mat']);
load([Directory 'GroupsSYNC.mat']);
%load( [Directory 'results_AUC_STATS_all_VS_intra_P0_25.mat'])
load( [Directory 'results_AUC_STATS_all_VS_intra_vsMAPPING_P0_25.mat'])

%GroupSYNC
%%analysis
%close all

selectedGroups=[1,2,3,4,5,6,7,8,9,10,11,13,14,15,16,17,19];
%%
selectedGroups=[1];

Groups=ALLgroups(selectedGroups);
AUCn=cell2mat(AUC(selectedGroups,:,SelectedMap,1:2,:));
AUCn=squeeze(AUCn)
subplot(211);hist(scores{1,strcmp(Stats,'intra'),3,Trial,1}(Ytest==1));hold all;scores{1,strcmp(Stats,'intra'),3,Trial,1}(Ytest==2)
scores{1,strcmp(Stats,'all'),3,Trial,1}
scores{1,strcmp(Stats,'intra'),3,Trial,2}
scores{1,strcmp(Stats,'all'),3,Trial,2}

%% Analyse mapping
close all
MEANmapping=squeeze(mean(mean(AUCn,2),1));
VARmapping=squeeze(mean(var(AUCn,[],4),1));
figure
subplot(211);plot(MEANmapping');legend(Stats);ylabel('Mean ROC Perf');xlabel('Set of electrods')
[MAXperf INDmap]=max(MEANmapping,[],2);
hold on;plot(INDmap,MEANmapping(:,INDmap),'or')
title('Test on different set of electrods')

subplot(212);plot(VARmapping');legend(Stats);ylabel('Var ROC Perf');xlabel('Set of electrods')
[MAXperf INDmap]=min(VARmapping,[],2);
hold on;plot(INDmap,VARmapping(:,INDmap),'or')

size(AUCn)
%%
SelectedMap=3
figure

plot(MEANmapping(:,SelectedMap)');legend(Stats);ylabel('Mean ROC Perf');xlabel('Set of electrods')
[MAXperf INDmap]=max(MEANmapping,[],2);
hold on;plot(INDmap,MEANmapping(SelectedMap)-VARmapping(SelectedMap,INDmap),'or')
title('Test on different set of electrods')
plot(VARmapping');legend(Stats);ylabel('Var ROC Perf');xlabel('Set of electrods')
[MAXperf INDmap]=min(VARmapping,[],2);
hold on;plot(INDmap,VARmapping(SelectedMap,INDmap),'or')

%% Analyse intra VS inter
close all
SelectedMap=3
AUCmean=squeeze(mean(AUCn(:,:,SelectedMap,:),4));
figure;bar(squeeze(AUCmean(:,1)),1,'g')
axis([0 19 min(min(AUCmean)) 1])
hold all;bar(squeeze(AUCmean(:,2)),0.5,'r');hold off;
set(gca, 'XTick', 1:length(Groups),'XTickLabel', Groups);
legend(Stats)
ylabel('AUC ROC')
title({'Overview of group performances' ...
    'If Green>Red, the InterStats increase perf'...
    'If Red>Green, the InterStats decrease perf'})
%%
close all
SelectedMap=3
AUCmean=squeeze(mean(AUCn(:,:,SelectedMap,:),4));
figure;bar(squeeze(AUCmean(:,1)),1,'g')
axis([0 19 min(AUCmean) 1])
hold all;bar(squeeze(AUCmean(:,2)),0.5,'r');hold off;
set(gca, 'XTick', 1:length(Groups),'XTickLabel', Groups);
legend(Stats)
ylabel('AUC ROC')
title({'Overview of group performances' ...
    'If Green>Red, the InterStats increase perf'...
    'If Red>Green, the InterStats decrease perf'})
%%
close all
SelectedMap=3
AUCmean=squeeze(mean(AUCn(:,:,SelectedMap,:),4));
figure;subplot(311);bar(squeeze(AUCmean(:,1)),1,'g')
axis([0 19 0.5 1])
hold all;bar(squeeze(AUCmean(:,2)),0.5,'r');hold off;
set(gca, 'XTick', 1:length(Groups),'XTickLabel', Groups);
legend(Stats)
ylabel('AUC ROC')
title({'Overview of group performances' ...
    'If Green>Red, the InterStats increase perf'...
    'If Red>Green, the InterStats decrease perf'})

diffAUC=AUCmean(:,1)-AUCmean(:,2);
x=squeeze(mean(SYNC.riem(selectedGroups,SelectedMap,:),3));y=diffAUC;
subplot(312); plot(x,y,'*')
title(['Correlation Coefficient=' num2str(corrcoef(x,y))])
xlabel('RiemSYNC, d_R^2(C^{-1/2}*C_{ref}*C^{-1/2} <-> \itI)');ylabel('Diff Perf AUCinter-AUCintra')
x=squeeze(mean(SYNC.FroNormP1P2(selectedGroups,SelectedMap,:),3));y=diffAUC;
subplot(313); plot(x,y,'*')
title(['Correlation Coefficient=' num2str(corrcoef(x,y))])
xlabel('FroNorm, ||(C^{-1/2}*C_{ref}*C^{-1/2} - \itI||_F^2');ylabel('Diff Perf AUCinter-AUCintra')

%% permutation test
%--- set some parameters
alpha   = 0.05;     % significance level
nPerm   = 50000;    % number of permutations (i.e., size of surrogate data)
nObs    = length(AUCmean(:,1));     	% number of observations
mean_1  = 10;       % mean of first vector of observations
mean_2  = 12.5;       % mean of second vector of observations
var_1   = 5;        % variance of first vector of observations
var_2   = 5;        % variance of second vector of observations


% --- simulate two vectors of paired obervation
vec_OBS_1   = mean_1 + var_1*randn(1,nObs);
vec_OBS_2   = mean_2 + var_2*randn(1,nObs);

vec_OBS_1   = AUCmean(:,1);
vec_OBS_2   = AUCmean(:,2);

% --- perform permutation tests
if alpha < (1/nPerm)
    disp(['Not enough permutations for this significance level (' num2str(alpha) ')']);
    alpha = 1/nPerm;
    disp(['--> Significance level set to minimum possible (' num2str(alpha) ')']);
end
schuffle_index = uniqueShuffle2(nPerm, nObs, 1); % permutation matrix used to shuffle values between observation sets
diff_PERM = zeros(1,nPerm);
% compute OBSERVATION (reference/real value)
diff_OBS = mean(vec_OBS_2 - vec_OBS_1);  % here: average paired differences (CAN BE A SIMPLE DIFFERENCE, OR ANY CALCULATION!!!)
% compute PERMUTATION (surrogate values)
vec_PERM_1 = zeros(1,nObs);
vec_PERM_2 = zeros(1,nObs);
for perm_ix = 1:nPerm
    % draw specific permutation using 'schuffle_index' logical indexes
    vec_PERM_1(schuffle_index(perm_ix,:))   = vec_OBS_1(schuffle_index(perm_ix,:));
    vec_PERM_1(~schuffle_index(perm_ix,:))  = vec_OBS_2(~schuffle_index(perm_ix,:));
    vec_PERM_2(~schuffle_index(perm_ix,:))  = vec_OBS_1(~schuffle_index(perm_ix,:));
    vec_PERM_2(schuffle_index(perm_ix,:))   = vec_OBS_2(schuffle_index(perm_ix,:));
    % compute surrogate surrogate value for this specific permutation
    diff_PERM(perm_ix) =  mean(vec_PERM_2 - vec_PERM_1);
end

% compute statistical significance and plot results
p_val = (1/nPerm)*(1+length(find(diff_PERM > diff_OBS)));
h_val = p_val < alpha;
figure;dispBootstrap(diff_OBS, diff_PERM)
