function W = NAV_GenerateWeights(nPop,nObj)
% Fixed nonuniform reference-direction construction used by BI-MOEA/D.
if nObj ~= 4
    error('BI:Weights','Paper implementation expects four objectives.');
end

centers = [ ...
    0.50 0.15 0.08 0.27; ...
    0.28 0.34 0.10 0.28; ...
    0.24 0.14 0.34 0.28; ...
    0.24 0.12 0.08 0.56; ...
    0.25 0.25 0.25 0.25];
ratio = [0.35 0.20 0.10 0.15 0.20];

counts = max(1,round(ratio(:)*nPop));
counts(end) = counts(end) + nPop-sum(counts);

W = [];
for i=1:size(centers,1)
    W = [W; repmat(centers(i,:),counts(i),1)]; %#ok<AGROW>
end
W = W(1:nPop,:);
W = max(0.02,W + 0.055*randn(size(W)));
W = W./sum(W,2);
W = W(randperm(nPop),:);
end
