%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  justanalyze.m

%   Author: Saurin Parikh
%   Created: March 2021
%
%   Image analysis of the SPImager Output
%
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files and Expt Info

    load_scripts;

    file_dir    = input('Path to image directory: ', 's');
    file_info   = readtable('/Users/SBP29/Desktop/Methionine/Deletion/MET_DEL_INFO.xlsx');
    file_info.arm = string(file_info.arm);
    file_info.condition = string(file_info.condition);
    file_info.expt_id = string(file_info.expt_id);
    file_info.stage_id = string(file_info.stage_id);
    
%%  GETTING IMAGE FILES
    
    files       = {};
    metadata    = {};
    filedir     = dir(file_dir);
    
    fileFlags = ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..') &...
        ~contains({filedir.name},'.binary') & ~contains({filedir.name},'.cs.txt') &...
        ~contains({filedir.name},'.info.mat');
    
    subFiles = filedir(fileFlags);
    for k = 1 : length(subFiles)
        tmpfile = strcat(subFiles(k).folder, '/',  subFiles(k).name);
        files = [files; tmpfile];
        temp_meta = strsplit(erase(subFiles(k).name, '.JPG'), '_');
        temp_meta(1) = {strip(cell2mat(temp_meta(1)),'left','d')};
        metadata = [metadata; temp_meta];
    end
    
%%  GETTING TIME FROM METADATA

    hours = [];
    plate_nos = unique(metadata(:,3));
    for i = 1:size(plate_nos,1)
        temp_meta = metadata(strcmpi(metadata(:,3), plate_nos(i)),:);
        temp_t0 = temp_meta(1,4:5);
        hours = [hours; 0];
        for ii = 2:size(temp_meta, 1)
            temp_t1 = temp_meta(ii,4:5);
            [y,m,d,h,mi,s] = datevec(between(datetime(sprintf('%s %s', temp_t0{:}),...
                'Format', 'MM-dd-yy HH-mm-ss'), ...
                datetime(sprintf('%s %s', temp_t1{:}),...
                'Format', 'MM-dd-yy HH-mm-ss')));
            temp_interval = [y*365*24, m*30*24, d*24, h, mi/60, s/(60*60)];
            hours = [hours; sum(temp_interval)];
        end
    end

    metadata = [metadata, [num2cell(hours), files]];
    metadata = cell2table(metadata, 'VariableNames',...
        {'batch','temp','plate','date','time','hours','filepath'});
    metadata.batch = str2double(metadata.batch);
    metadata.temp = str2double(metadata.temp);
    metadata.plate = str2double(metadata.plate);
    metadata.date = string(metadata.date);
    metadata.time = string(metadata.time);
    metadata.filepath = string(metadata.filepath);
    
    metadata = join(metadata, file_info, 'Keys',{'batch','plate'});
    
%%  PLATE DENSITY AND ANALYSIS PARAMETERS

    expi = unique(metadata.expt_id);
    for e = 1:length(expi)
        stgs = unique(metadata.stage_id(metadata.expt_id == expi(e)));
        for s = 1:length(stgs)
            arms = unique(metadata.arm(metadata.expt_id == expi(e) &...
                metadata.stage_id == stgs(s)));
            for a = 1:length(arms)
                temp_files = metadata.filepath(metadata.expt_id == expi(e) &...
                    metadata.stage_id == stgs(s) & ...
                    metadata.arm == arms(a));
                temp_files = cellstr(temp_files);
                
                density = unique(metadata.density(metadata.expt_id == expi(e) &...
                    metadata.stage_id == stgs(s) & ...
                    metadata.arm == arms(a)));
                
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
            
                analyze_directory_of_images(temp_files, params{:} );
            end
        end
    end
    
    
%%  RECORD FAILED IMAGES

    all = zeros(1, size(files, 1));
    for ii = 1 : size(all, 2)
        all(ii) = exist(strcat(files{ii}, '.binary'));
    end
    pos = find(all==0);
    
    metadata.failed = contains(metadata.filepath, files(pos));
    
%%  SAVE METADATA
    
    writetable(metadata, sprintf('%s/%s_output.xlsx', file_dir, expt_set),...
        'WriteVariableNames',true)
   
%%  END
%%
    
    