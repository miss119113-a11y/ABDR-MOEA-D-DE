function value=NAV_LinearScheduleProbability(initialValue,finalValue,progress)
%NAV_LINEARSCHEDULEPROBABILITY Bounded linear probability schedule.
% Progress is clipped to [0,1].  Equal endpoints preserve the legacy
% constant-probability behavior exactly.
validateattributes(initialValue,{'numeric'},{'real','finite','scalar'});
validateattributes(finalValue,{'numeric'},{'real','finite','scalar'});
validateattributes(progress,{'numeric'},{'real','finite','scalar'});
progress=min(max(double(progress),0),1);
value=double(initialValue)+(double(finalValue)-double(initialValue))*progress;
value=min(max(value,0),1);
end

