function [R, AUC,RND,SHUF]=BCI_chain(ALLdata,Parameters,P)
% This classification chain is made to evaluate different methods of
% classfication and/or hyper-parameters. This is highly modulable.
%

%                        +------+            +------+
%    EEG INPUT --------->|train |--->------->|test  | ---> classif output
%                        |  /   |            |  /   |
%      P(hyper)--------->|init  |  P(local)->|adapti|
%                        +------+            +------+
%
% The EEG INPUT is the structure ALLdata containing :
%     Xte, 3D matrices encapsulated in cells 
%     Yte, vectors encapsulated in cells
%     isBad 
%
% The parameters INPUT is the structure P containing many hyper and local
% parameters. Hyper parameters are applicables for any classification
% method while local parameters are only applicable for the specific
% classification.
%
% see also: 
%% initialisation of the outputs

[R.AUC, R.scores,R.d, R.confM, R.perf,R.Yestimated,R.RNDseed, R.P1, R.SHUFseed, R.conv, R.niter P1]=deal([]);

%% PREPARATION FOR ALL THE CLASSIFIERS (hyper-parameters)


% * ELECTRODES selection
% PROTOTYPE : using user
% if P.nusers==2
%     BImapping=[P.BImap P.BImap+32];
% end
%% required parameters
% P.nusers=2; % default 1
% P.users=[2]; %default 1:P.nusers, check if max<P.nusers
% P.nelec=32; % default size(X,1)/P.nusers
% P.elec=[1:16]; %default 1:P.nelec
% P.samples=[65:192]; %default 1:size(X,2)

%%
% * ELECTRODES selection
selectedelectrodes=[];
for indU=1:length(P.users)
    selectedelectrodes=[selectedelectrodes P.elec+P.nelec*(P.users(indU)'-1)];
end

% * SUBJECTS selection
indSubj=find(strcmp(Parameters.GroupsName,P.GroupsName));

% * TRAINING-TEST set ratio (INIT-TEST for adaptive)
Ratio= P.TestSetRatio;

% * SAMPLES selection
if ~isfield(P,'samples')
    P.samples=1:size(ALLdata.Xte{indSubj(1)},2);
end

%remove the unused subjects, electrodes and samples
X=ALLdata.Xte{indSubj}(selectedelectrodes,P.samples,:);Y=ALLdata.Yte{indSubj};

% * DO SCHUFFLE ? (if 2 subjects)
% this parameters is used to compared the results from synchroneous EEG
% (real multi-user dataset) to non-synchroneous EEG (simulated multi-user).
if P.ShuffleCouple==1
    [X SHUF]=Shuffle_Set(X,Y,P.SHUF);
else
    SHUF=P.SHUF;
end

% * P300 orientation (when common)
if strcmp(P.classifier,'common')
    P.P300_ref_orientation='commonP1';
end

% * artifact removal from labelled trials
if isfield(ALLdata,'isBad')
    NoArte=~ALLdata.isBad{indSubj};%index of epochs without artifacts
else
    NoArte=1:size(X,3);
end
labels=unique(Y);
Nclass=length(labels);
% * generate the training-test set accordingly
[Xtraining Ytraining Xtest Ytest RND]=gp_gen_training_test_set(X,Y,Ratio,[]);
% plotEEG(mean(mean(Xtest(:,:,Ytest==1),3),1),2);
Yestimated=[];
%% *Classification

switch P.classifier
    case 'MDM'
        %%
        clear C
        [COVtr P1] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        [COVte] = covariances_p300_hyper(Xtest,P1,length(P.users),P.P300_ref_orientation);
        
        for i=1:Nclass
            
            [C{i} R.conv{i} R.niter(i)] = mean_covariances(COVtr(:,:,Ytraining==labels(i)),P.method_mean);
            
        end
        
        % classification
        NTesttrial = size(COVte,3);
        if 0 % only if P.classifieroptions.multiusers==multi
            COVte=covariances_p300_clean_inter(COVte,NbUsers,P.P300_ref_orientation);
        end
        d=[];
        for j=1:NTesttrial
            for i=1:Nclass
                [d(j,i)] = distance(COVte(:,:,j),C{i},P.method_dist);
            end
        end
        R.d=d;
%         [~,ix] = min(d,[],2);
%         Yestimated = labels(ix);
        scores= -diff(d')';
    case 'MDM-LR'
        %%
        clear C
        [COVtr P1] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        [COVte] = covariances_p300_hyper(Xtest,P1,length(P.users),P.P300_ref_orientation);
        
        for i=1:Nclass
            C{i} = mean_covariances(COVtr(:,:,Ytraining==labels(i)),P.method_mean);
        end
        dt=[];
        NTesttrial = size(COVtr,3);
        
        for j=1:NTesttrial
            for i=1:Nclass
                [dt(j,i)] = distance(COVtr(:,:,j),C{i},P.method_dist);
            end
        end
        [B,dev,stats] = mnrfit(dt,Ytraining+1);
        % classification
        NTesttrial = size(COVte,3);
        if 0 % only if P.classifieroptions.multiusers==multi
            COVte=covariances_p300_clean_inter(COVte,NbUsers,P.P300_ref_orientation);
        end
        d=[];
        for j=1:NTesttrial
            for i=1:Nclass
                [d(j,i)] = distance(COVte(:,:,j),C{i},P.method_dist);
            end
        end
        scores= -diff(d')';
        PHAT = mnrval(B,d);
        [~,ix] = max(PHAT,[],2);
        scores=diff(PHAT,[],2);
%         Yestimated = labels(ix);
        
    case 'MDM-adaptive'
        %assume that their are arranged by repetitions (i.e. 10 NT and 2
        %TA)
        [COVtr P1init] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        for i=1:Nclass
            Cinit{i} = mean_covariances(COVtr(:,:,Ytraining==labels(i)),P.method_mean);
        end
        counter=size(COVtr,3)/12;
        
        % supplementary inputs P1init and Cinit
        [Yestimated, scores, R.errclass,R.irep,R.C,P1]=mdm_adaptive_hyper(Xtest,Ytest,P1init,Cinit,counter,P);
        %         [Yestimated d C] = mdm(COVte,COVtr,Ytraining);
        %         mdm
    case 'Tangent-SWLDA'
        %riemmannian tangeant space with step wise regression
        [COVtr P1] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        C = mean_covariances(COVtr,P.method_mean);
        [FeatTr C] = Tangent_space(COVtr,C);
        regressors=(Ytraining-0.5)*2;
        maxFeature=[60];
        [b,se,pval,inmodel,sta] = stepwisefit( ...
            FeatTr',regressors, ...
            'maxiter',maxFeature,'display','off','penter',0.1,'premove',0.15);%,'scale','on');
        intercept= sta.intercept;
        [COVte] = covariances_p300_hyper(Xtest,P1,length(P.users),P.P300_ref_orientation);
        [FeatTe C] = Tangent_space(COVte, C);
        scores=b'*FeatTe+intercept;
    case 'Tangent-lasso'
        %% riemmannian tangeant space with logistic regression
        [COVtr P1] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        C = mean_covariances(COVtr(:,:,Ytraining==1),P.method_mean);
        [FeatTr] = Tangent_space(COVtr,C);
%         [B,dev,stats] = glmfit(FeatTr', Ytraining, 'binomial', 'link', 'logit');
        [B,FitInfo]=lasso(FeatTr',Ytraining,'lambda',1e-2);
        [COVte] = covariances_p300_hyper(Xtest,P1,length(P.users),P.P300_ref_orientation);
        [FeatTe] = Tangent_space(COVte, C);
%         Output = 1 ./ (1 + exp(-B(1) + FeatTe' * (B(2:end))));
        scores=B'*FeatTe+FitInfo.Intercept;
%         scores>FitInfo.Intercept
%         PHAT = glmval(B,FeatTe','logit')
%         [~,ix] = max(PHAT,[],2);
%         scores=PHAT-0.5;
%         Yestimated = labels(ix);
    case 'Tangent-LR'
        %% riemmannian tangeant space with logistic regression
        [COVtr P1] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        C = mean_covariances(COVtr,P.method_mean);
        [FeatTr] = Tangent_space(COVtr,C);
        [B,dev,stats] = glmfit(FeatTr',Ytraining,'binomial');
%          [B,dev,stats] = mnrfit(FeatTr',Ytraining+1);
%         [B,FitInfo]=lasso(FeatTr',Ytraining,'lambda',1e-2);
        [COVte] = covariances_p300_hyper(Xtest,P1,length(P.users),P.P300_ref_orientation);
        [FeatTe] = Tangent_space(COVte, C);
        scores = 1 ./ (1 + exp(-B(1) + FeatTe' * (B(2:end))));
%         scores=B'*FeatTe+FitInfo.Intercept;
    case 'SWLDA'
        [weights, intercept] = train_swlda(Xtraining,Ytraining);
        scores = test_swlda(Xtest,weights,intercept);
    case 'covSWLDA'
        [COVtr P1] = covariances_p300_hyper(Xtraining,Ytraining,length(P.users),P.P300_ref_orientation);
        [weights, intercept] = train_swlda(COVtr,Ytraining);
        [COVte] = covariances_p300_hyper(Xtest,P1,length(P.users),P.P300_ref_orientation);
        scores = test_swlda(COVte,weights,intercept);
end

%% compute the results from the classification
 if size(scores,2)>size(scores,1),scores=scores';end
%  plotroc(Ytest',scores')

 if isempty(Yestimated),
     ratioReal=count(Ytest)/length(Ytest);
     indR=1;
     thr=min(scores):0.0001:max(scores);
     for threshold=thr
         Yhat=double(scores>threshold);
         ratioEsti(indR)=count(Yhat)/length(Yhat);
         indR=indR+1;
     end
     [~ ,indm]=min(abs(ratioEsti-ratioReal));
     threshold=thr(indm);
     
     Yestimated=double(scores>threshold);
 end

R.perf=length(find(Yestimated==Ytest))/length(Ytest);
R.confM=confusionmat(Ytest,Yestimated);
[~,~,~,AUC,OPTROCPT] = perfcurve(Ytest',scores',1);
if strcmp(P.classifier(1:3),'MDM'),MSG=P.method_mean;else,MSG='';end
fprintf(['Stats(' P.classifier '-' MSG '), ratio(' num2str(P.TestSetRatio) ') AUC(' num2str(AUC) '), Perf(' num2str(R.perf*100) '%%)\n\n'])

R.AUC=AUC;
R.scores=scores;
R.Yestimated=Yestimated;
R.Ytest=Ytest;
R.RNDseed=RND;
R.P1=P1;
R.SHUFseed=SHUF;

 
end