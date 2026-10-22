function i = RouletteWheelSelection(P)
%ROULETTEWHEELSELECTION Legacy categorical sampler used by archive helpers.
% Canonical source: utils/legacy_movwo/RouletteWheelSelection.m in the supplied export.

    r = rand;
    
    C = cumsum(P); % cumulative sum
    
    i = find(r <= C, 1, 'first');

end
