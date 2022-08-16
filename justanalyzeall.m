
load_toolkit;

file_dir = input('Path to image directory: ', 's');
density = input('Colony-density of plates: ');

files       = {};
filedir     = dir(file_dir);

fileFlags = ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..') &...
    ~strcmp({filedir.name},'.DS_Store') &...
    ~contains({filedir.name},'.binary') & ~contains({filedir.name},'.cs.txt') &...
    ~contains({filedir.name},'.info.mat') & ~contains({filedir.name},'.db') &...
    ~contains({filedir.name},'.xlsx') & ~contains({filedir.name},'.txt');

subFiles = filedir(fileFlags);
for k = 1 : length(subFiles)
    tmpfile = strcat(subFiles(k).folder, '/',  subFiles(k).name);
    files = [files; tmpfile];
end

if density == 6144
    dimensions = [64 96];
elseif density == 1536
    dimensions = [32 48];
elseif density == 384
    dimensions = [16 24];
else
    dimensions = [8 12];
end

params = { ...
    'parallel', true, ...
    'verbose', true, ...
    'grid', OffsetAutoGrid('dimensions', dimensions), ... default
    'threshold', BackgroundOffset('offset', 1.25) }; % default = 1.25


just_analyze = input('Do you want to just analyze? [Y/N] ', 's');
img2cs(files, dimensions, params, just_analyze);