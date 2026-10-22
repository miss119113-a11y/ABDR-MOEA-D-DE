function rootDir = lcad_project_root()
%LCAD_PROJECT_ROOT Return the root folder of this clean ARCMOVWO package.

thisFile = mfilename('fullpath');
rootDir = fileparts(fileparts(thisFile));

if exist(fullfile(rootDir, 'setup_lcad_paths.m'), 'file') ~= 2
    currentDir = pwd;
    if exist(fullfile(currentDir, 'setup_lcad_paths.m'), 'file') == 2
        rootDir = currentDir;
    else
        error('lcad_project_root:NotFound', ...
            'Cannot locate setup_lcad_paths.m. Run from the LCAD project root.');
    end
end
end
