function credit=TRIAD_CREDIT(child,origin,target,originWeight,targetWeight,ideal)
% A transfer may be accepted without teaching parameters that hurt its source.
credit=min(relativeGain(origin,child,originWeight,ideal),relativeGain(target,child,targetWeight,ideal));
end
function gain=relativeGain(old,new,w,z)
old=double(old(:)');new=double(new(:)');w=max(double(w(:)'),1e-12);z=double(z(:)');
gain=0;
if any(~isfinite([old new]))||any(old>1+1e-12)||any(new>1+1e-12),return;end
a=max(w.*max(0,old-z));b=max(w.*max(0,new-z));
if isfinite(a)&&isfinite(b)&&a>b,gain=min(1,max(0,(a-b)/max(abs(a),1e-12)));end
end
