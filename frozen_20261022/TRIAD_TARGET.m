function [target,gain]=TRIAD_TARGET(child,costs,parent,eligible,quota,weights,ideal)
% One strict improvement, one free direction, deterministic relative-gain order.
target=NaN;gain=0;child=double(child(:)');
if any(~isfinite(child))||any(child>1+1e-12),return;end
available=unique([eligible(:);parent]);available=available(quota(available)==0);
if isempty(available),return;end
W=max(double(weights(available,:)),1e-12);
old=double(costs(available,:));z=double(ideal(:)');
a=max(W.*max(0,old-z),[],2);b=max(W.*max(0,child-z),[],2);
relative=(a-b)./max(abs(a),1e-12);
valid=all(isfinite(old),2)&all(old<=1+1e-12,2)&isfinite(relative)&(a>b);
if ~any(valid),return;end
available=available(valid);relative=relative(valid);
[~,order]=sortrows([-relative(:),double(available(:))],[1 2]);
target=available(order(1));gain=relative(order(1));
end