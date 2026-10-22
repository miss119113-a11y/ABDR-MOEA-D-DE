function p = NAV_CopyEmptyParticle()
    p.Position = [];
    p.Vector = [];
    p.Cost = [];
    p.Best.Position = [];
    p.Best.Vector = [];
    p.Best.Cost = [];
    p.IsDominated = [];
    p.GridIndex = [];
    p.GridSubIndex = [];
    p.Weight = [];
    p.Rank = [];
    p.CrowdingDistance = [];
end
