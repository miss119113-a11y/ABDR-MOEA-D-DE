function W = NAV_GenerateWeights(nPop, nObj, mode)
% Biased reference vectors for four UAV objectives.
    if nargin < 3
        mode = 'balanced';
    end
    if nObj ~= 4
        raw = rand(nPop, nObj);
        W = raw ./ sum(raw, 2);
        return;
    end

    switch lower(mode)
        case 'length'
            centers = [0.68 0.10 0.06 0.16; 0.52 0.15 0.08 0.25; 0.35 0.25 0.10 0.30];
            ratio = [0.42 0.38 0.20];
        case 'safe'
            centers = [0.45 0.25 0.08 0.22; 0.22 0.52 0.08 0.18; 0.30 0.18 0.18 0.34];
            ratio = [0.35 0.30 0.35];
        otherwise
            centers = [0.50 0.15 0.08 0.27; 0.28 0.34 0.10 0.28; 0.24 0.14 0.34 0.28; 0.24 0.12 0.08 0.56; 0.25 0.25 0.25 0.25];
            ratio = [0.35 0.20 0.10 0.15 0.20];
    end

    counts = max(1, round(ratio(:) * nPop));
    counts(end) = counts(end) + nPop - sum(counts);
    W = [];
    for i = 1:size(centers,1)
        W = [W; repmat(centers(i,:), counts(i), 1)]; %#ok<AGROW>
    end
    if size(W,1) < nPop
        W = [W; repmat(centers(1,:), nPop-size(W,1), 1)]; %#ok<AGROW>
    elseif size(W,1) > nPop
        W = W(1:nPop,:);
    end

    W = max(0.02, W + 0.055 * randn(size(W)));
    W = W ./ sum(W, 2);
    W = W(randperm(nPop), :);
end
