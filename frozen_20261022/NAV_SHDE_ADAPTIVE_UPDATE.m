function [memoryF,memoryCR,pointer] = NAV_SHDE_ADAPTIVE_UPDATE(memoryF,memoryCR,pointer,F,CR,w,crMode)
% Production H5 update used by C/D. F always uses weighted Lehmer.
% CR uses weighted Lehmer for A compatibility, weighted arithmetic for C/D.
if nargin<7||isempty(crMode),crMode='LEHMER';end
if isempty(F)||isempty(CR)||isempty(w),return;end
F=double(F(:));CR=double(CR(:));w=double(w(:));
valid=isfinite(F)&isfinite(CR)&isfinite(w)&w>0;
if ~any(valid),return;end
F=F(valid);CR=CR(valid);w=w(valid);w=w./sum(w);
denF=sum(w.*F);
if denF>0,memoryF(pointer)=sum(w.*F.^2)/denF;end
switch upper(char(string(crMode)))
 case 'LEHMER'
  denCR=sum(w.*CR);if denCR>0,memoryCR(pointer)=sum(w.*CR.^2)/denCR;else,memoryCR(pointer)=0;end
 case 'ARITH'
  memoryCR(pointer)=sum(w.*CR);
 otherwise,error('SHDE:CRUpdateMode','Unsupported CR update mode: %s',char(string(crMode)));
end
pointer=mod(pointer,numel(memoryF))+1;
end