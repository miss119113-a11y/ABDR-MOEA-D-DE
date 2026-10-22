function pop = DetermineDomination(pop)
%DETERMINEDOMINATION Mark dominated particles for active legacy baselines.
%   This preserves the original NMOPSO/SPEA2-compatible dominance semantics
%   while keeping the helper on the package path rather than in an archive.

nPop = numel(pop);
if nPop == 0
    return;
end

for i = 1:nPop
    pop(i).IsDominated = false;
end

for i = 1:nPop-1
    if any(pop(i).Cost == Inf)
        pop(i).IsDominated = true;
    end
    for j = i+1:nPop
        if Dominates(pop(i), pop(j))
            pop(j).IsDominated = true;
        end
        if Dominates(pop(j), pop(i))
            pop(i).IsDominated = true;
        end
    end
end

if any(pop(end).Cost == Inf)
    pop(end).IsDominated = true;
end
for j = 1:nPop-1
    if Dominates(pop(end), pop(j))
        pop(j).IsDominated = true;
    end
    if Dominates(pop(j), pop(end))
        pop(end).IsDominated = true;
        break;
    end
end
end
