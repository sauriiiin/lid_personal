%%  Sau MATLAB Colony Analyzer Toolkit
%   
%%  image2cs.m
% 
%   Author: Saurin Parikh
%   Created: March 2021
%
%   Image analysis of the SPImager Output
%
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files and Expt Info

    load_toolkit;

    file_dir = input('Path to image directory: ', 's');
    expt_set = "trial"; %input('Name of Experiment Arm: ','s');
    density = 6144; %input('Colony-density of plates: ');
    
%%  GETTING IMAGE FILES
    
    files = {};
    metadata = {};
    filedir = dir(file_dir);
    
    fileFlags = ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..') &...
        ~contains({filedir.name},'.binary') & ~contains({filedir.name},'.cs.txt') &...
        ~contains({filedir.name},'.info.mat');
    
    subFiles = filedir(fileFlags);
    for k = 1 : length(subFiles)
        tmpfile = strcat(subFiles(k).folder, '/',  subFiles(k).name);
        files = [files; tmpfile];
        metadata = [metadata; strsplit(erase(subFiles(k).name, '.JPG'), '_')];
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

    metadata = [metadata, num2cell(hours)];
    metadata = cell2table(metadata, 'VariableNames',...
        {'batch','temp','plate','date','time','hours'});
    
%%  PLATE DENSITY AND ANALYSIS PARAMETERS
    
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
    
%%  ANALYZE IMAGES

    analyze_directory_of_images(files, params{:} )
    
    all = zeros(1, size(files, 1));
    for ii = 1 : size(all, 2)
        all(ii) = exist(strcat(files{ii}, '.binary'));
    end
    pos = find(all==0);
    
% %%  LOAD COLONY SIZE DATA
% 
%     cs = load_colony_sizes(files)';
%     master = reshape(cs, [size(cs,1)*size(cs,2),1]);
% 
%     
% %%  UPLOAD TO SQL
% 
%     connectSQL;
%     tablename_raw  = sprintf('%s_%d_RAW',expt_set,density);
%         
%     p2c_info = {'F28FUR_pos2coor','plate','row','col'};
%     p2c = fetch(conn, sprintf(['select * from %s a ',...
%         'where density = %d ',...
%         'order by a.%s, a.%s, a.%s'],...
%         p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));
%     p2c = p2c(1:density*2,:);
% 
%     exec(conn, sprintf('drop table %s',tablename_raw));  
%     exec(conn, sprintf(['create table %s (pos bigint not null, hours double not null,'...
%         'pixels double default null, '...
%         'primary key (hours, pos))'], tablename_raw));
% 
%     colnames_raw = {'pos','hours','pixels'};
% 
%     tmpdata = [];
%     for p=1:length(plate_nos)
%         temp_hours = metadata.hours(strcmpi(metadata.plate, plate_nos(p)));
%         for ii=1:length(temp_hours)
%             tmpdata = [tmpdata; [p2c.pos(p2c.plate == p), ones(length(p2c.pos(p2c.plate == p)),1)*temp_hours(ii)]];
%         end
%     end
% 
%     data = [tmpdata,master];
%     tic
%     datainsert(conn,tablename_raw,colnames_raw,data);
%     toc
%     
    
    
    
%% END
    