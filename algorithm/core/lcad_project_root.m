function rootDir = lcad_project_root()
%LCAD_PROJECT_ROOT Resolve repository root for terrain input lookup.
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~isfolder(fullfile(rootDir,'algorithm'))
    error('ABDR:ProjectRoot','Expected algorithm/ directory at repository root.');
end
end
