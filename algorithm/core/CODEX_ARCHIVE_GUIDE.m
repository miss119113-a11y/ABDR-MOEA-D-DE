function [guide,index,audit]=CODEX_ARCHIVE_GUIDE(F,X,current,original,w,ideal,nadir,normalize)
% Select a strictly superior, already-evaluated feasible historical guide.
% Uses the same raw Tchebycheff scalarization as the frozen Full-C engine.
guide=original;index=0;
w=max(double(w(:)'),1e-12);ideal=double(ideal(:)');
d=max(0,double(current(:)')-ideal);
if normalize,d=d./max(double(nadir(:)')-ideal,1e-12);end
oldScore=max(w.*d);newScore=oldScore;
if ~isempty(F)
    assert(size(F,1)==size(X,1)&&size(F,2)==numel(w),'CODEX:GuideDimensions','Archive shape mismatch');
    feasible=all(isfinite(F),2)&all(F<=1+1e-12,2);
    scores=inf(size(F,1),1);
    delta=max(0,double(F(feasible,:))-ideal);
    if normalize,delta=delta./max(double(nadir(:)')-ideal,1e-12);end
    scores(feasible)=max(delta.*w,[],2);
    [best,j]=min(scores);
    if best<oldScore-1e-12
        guide=X(j,:);index=j;newScore=best;
    end
end
audit=struct('OldScore',oldScore,'NewScore',newScore,'AdditionalObjectiveCalls',0,'AdditionalRandomDraws',0);
end
