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

    load_toolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
    fileID = fopen(sprintf('%s/info.txt',toolkit_path),'r');
    info = textscan(fileID, '%s%s');

    file_dir    = input('Path to image directory: ', 's');
    file_info   = readtable(input('Path to EXPT INFO file: ', 's'));
%     readtable('/home/sbp29/RAW_Data/Methionine/Deletion/MET_DEL_INFO.xlsx');
    file_info.arm = string(file_info.arm);
    file_info.condition = string(file_info.condition);
    file_info.expt_id = string(file_info.expt_id);
    file_info.stage_id = string(file_info.stage_id);
    
%%  GETTING IMAGE FILES
    
    files       = {};
    metadata    = {};
    filedir     = dir(file_dir);
    
    fileFlags = ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..') &...
        ~strcmp({filedir.name},'.DS_Store') &...
        ~contains({filedir.name},'.binary') & ~contains({filedir.name},'.cs.txt') &...
        ~contains({filedir.name},'.info.mat') & ~contains({filedir.name},'.db');
    
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
    metadata.hours = round(metadata.hours);
    metadata = sortrows(metadata,{'batch','hours','plate'},...
        {'ascend','ascend','ascend'});
    
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
                
                fprintf('Analyzing %s %s %s at %d.\n',...
                    expi(e), stgs(s), arms(a), density);
                
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
            
                img2cs(temp_files, dimensions, params, 'Y'); % justanalyze = 'Y'
                
%                 if input('Do you want to upload data to MySQL? [Y/N] ', 's') == 'Y'
%                     disp('Proceeding to upload...')
% 
%                     cs_data = loadcs(temp_files);
% 
%                     cs2sql(cs_data, info,...
%                         expi(e), stgs(s), arms(a), density,...
%                         unique(metadata.hours(metadata.expt_id == expi(e) &...
%                         metadata.stage_id == stgs(s) &...
%                         metadata.arm == arms(a))));
% 
%                     disp('Cleaning raw data to remove borders and light artifact.')
% 
%                     sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
%                     conn = connSQL(sql_info);
%                     
%                     tablename_bpos   = info{1,2}{9};
%                     tablename_raw    = sprintf('%s_%s_%s_%d_RAW',expi(e), stgs(s), arms(a),density);
%                     tablename_clean  = sprintf('%s_%s_%s_%d_CLEAN',expi(e), stgs(s), arms(a),density);
% 
%                     exec(conn, sprintf('drop table %s',tablename_clean));
%                     exec(conn, sprintf(['create table %s (primary key (pos, hours)) ',...
%                         '(select * from %s)'], tablename_clean, tablename_raw));
%                     
%                     exec(conn, sprintf(['update %s ',...
%                         'set average = NULL ',...
%                         'where pos in ',...
%                         '(select pos from %s)'],tablename_clean,tablename_bpos));
% 
%                     exec(conn, sprintf(['update %s ',...
%                         'set average = NULL ',...
%                         'where average <= 10'],tablename_clean));
% 
%                     if input('Do you want to perform LID Normalization? [Y/N] ', 's') == 'Y'
%                         cont.name = info{1,2}{10};
% 
%                         tablename_lac       = sprintf('%s_%s_%s_%d_LAC',expi(e), stgs(s), arms(a),density);
%                         tablename_norm      = sprintf('%s_%s_%s_%d_NORM',expi(e), stgs(s), arms(a),density);
%                         tablename_fit       = sprintf('%s_%s_%s_%d_FITNESS',expi(e), stgs(s), arms(a),density);
%                         tablename_fits      = sprintf('%s_%s_%s_%d_FITNESS_STATS',expi(e), stgs(s), arms(a),density);
%                         tablename_es        = sprintf('%s_%s_%s_%d_FITNESS_ES',expi(e), stgs(s), arms(a),density);
%                         tablename_pval      = sprintf('%s_%s_%s_%d_PVALUE',expi(e), stgs(s), arms(a),density);
%                         tablename_res       = sprintf('%s_%s_%s_%d_RES',expi(e), stgs(s), arms(a),density);
% 
%                         tablename_p2s  = info{1,2}{6};
%                         tablename_p2o  = info{1,2}{7};
%                         tablename_s2o  = info{1,2}{8};
% 
%                         tablename_p2p   = info{1,2}{11};
% 
%                         p2c_info = {info{1,2}{5},'plate','row','col'};
%                         p2c = fetch(conn, sprintf(['select * from %s a ',...
%                             'where density = %d ',...
%                             'order by a.%s, a.%s, a.%s'],...
%                             p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));
% 
%                         n_plates = fetch(conn, sprintf(['select distinct %s from %s ',...
%                             'where density = %d ',...
%                             'order by %s asc'],...
%                             p2c_info{2},p2c_info{1},density,p2c_info{2}));
% 
%     % % % % % % %                     
%                         if input('Do you want to perform source-normalization? [Y/N] ', 's') == 'Y'
%                             IL = 1; % 1 = to source norm / 0 = to not
%                         else
%                             IL = 0;
%                         end
% 
%                         hours = fetch(conn, sprintf(['select distinct hours from %s ',...
%                             'order by hours asc'], tablename_clean));
%                         hours = hours.hours;
%                         fit_data = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
%                             tablename_p2o,tablename_clean,IL,density,dimensions,sql_info);
% 
%                         exec(conn, sprintf('drop table %s',tablename_norm));
%                         exec(conn, sprintf(['create table %s ( ',...
%                                     'pos bigint not NULL, ',...
%                                     'hours double not NULL, ',...
%                                     'bg double default NULL, ',...
%                                     'average double default NULL, ',...
%                                     'fitness double default NULL, ',...
%                                     'primary key (pos, hours))'],tablename_norm));
%                         for i=1:length(hours)
%                             datainsert(conn, tablename_norm,...
%                                 {'pos','hours','bg','average','fitness'},fit_data{i});
%                         end
% 
%                         exec(conn, sprintf('drop table %s',tablename_fit)); 
%                         exec(conn, sprintf(['create table %s (primary key (pos, hours))',...
%                             '(select c.strain_id, b.orf_name, a.pos, a.hours, a.bg, a.average, a.fitness ',...
%                             'from %s a, %s b , %s c ',...
%                             'where a.pos = b.pos and b.pos = c.pos ',...
%                             'order by a.hours, a.pos asc)'],...
%                             tablename_fit,tablename_norm,tablename_p2o,tablename_p2s));                  
%                     end
% 
%     % % % % %                 
%                     if input('Do you want to calculate empirical p-values? [Y/N] ', 's') == 'Y'
% 
%                         clear data
% 
%                         exec(conn, sprintf('drop table %s', tablename_fits));
%                         exec(conn, sprintf(['create table %s (strain_id int not null, ',...
%                             'orf_name varchar(255) null, ',...
%                             'hours double not null, N int not null, cs_mean double null, ',...
%                             'cs_median double null, cs_std double null, ',...
%                             'primary key (strain_id, hours))'],tablename_fits));
% 
%                         colnames_fits = {'strain_id','orf_name','hours','N','cs_mean','cs_median','cs_std'};
% 
%                         stat_data = fitstats_sid(tablename_fit,sql_info);
% 
%                         tic
%                         datainsert(conn,tablename_fits,colnames_fits,stat_data)
%                     %     sqlwrite(conn,tablename_fits,struct2table(stat_data));
%                         toc  
% 
%     % % % % % % 
% 
%                         exec(conn, sprintf('drop table %s',tablename_pval));
%                         exec(conn, sprintf(['create table %s (strain_id int not null, ',...
%                             'orf_name varchar(255) null,'...
%                             'hours double not null, p double null, stat double null, ',...
%                             'es double null, ',...
%                             'primary key (strain_id, hours))'],tablename_pval));
%                         colnames_pval = {'strain_id','orf_name','hours','p','stat','es'};
% 
%                         contpos = fetch(conn, sprintf(['select a.pos, a.rep_pos ',...
%                             'from %s a, %s b ',...
%                             'where a.density = %d and a.pos = b.pos and b.orf_name = "%s" ',...
%                             'and a.pos not in (select pos from %s) ',...
%                             'order by a.pos'],...
%                             tablename_p2p, tablename_p2o,...
%                             density, cont.name,...
%                             tablename_bpos));
% 
%                         iden_contpos = unique(contpos.pos);
% 
%                         for iii = 1:length(hours)
%                             contfit = [];
%                             for ii = 1:length(iden_contpos)
%                                 cp = sprintf('%d,',contpos.rep_pos(contpos.pos == iden_contpos(ii)));
%                                 temp = fetch(conn, sprintf(['select fitness from %s ',...
%                                     'where hours = %0.2f and pos in (%s) ',...
%                                     'and fitness is not null'],tablename_fit,hours(iii),...
%                                     cp(1:end-1)));
% 
%                                 if nansum(temp.fitness) > 0
%                                     outlier = isoutlier(temp.fitness);
%                                     temp.fitness(outlier) = NaN;
%                                     contfit = [contfit, nanmean(temp.fitness)];
%                                 end
%                             end
%                             contmean = nanmean(contfit);
%                             contstd = nanstd(contfit);
% 
%                             orffit = fetch(conn, sprintf(['select strain_id, ',...
%                                 'orf_name, cs_median, ',...
%                                 'cs_mean, cs_std from %s ',...
%                                 'where hours = %0.2f and orf_name != ''%s'' ',...
%                                 'order by orf_name asc'],tablename_fits,hours(iii),cont.name));
% 
%                             m = contfit';
%                             tt = length(m);
%                             pvals = [];
%                             es = [];
%                             stat = [];
%                             for i = 1:length(orffit.strain_id)
%                                 if sum(m<orffit.cs_mean(i)) < tt/2
%                                     if m<orffit.cs_mean(i) == 0
%                                         pvals = [pvals; 1/tt];
%                                         es = [es; (orffit.cs_mean(i) - contmean)/contmean];
%                                         stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
%                                     else
%                                         pvals = [pvals; ((sum(m<=orffit.cs_mean(i)))/tt)*2];
%                                         es = [es; (orffit.cs_mean(i) - contmean)/contmean];
%                                         stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
%                                     end
%                                 else
%                                     pvals = [pvals; ((sum(m>=orffit.cs_mean(i)))/tt)*2];
%                                     es = [es; (orffit.cs_mean(i) - contmean)/contmean];
%                                     stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
%                                 end
%                             end
% 
%                             pdata{iii}.strain_id                                = orffit.strain_id;
%                             pdata{iii}.orf_name                                 = orffit.orf_name;
%                             pdata{iii}.hours                                    = ones(length(pdata{iii}.orf_name),1)*hours(iii);
%                             pdata{iii}.p                                        = num2cell(pvals);
%                             pdata{iii}.p(cellfun(@isnan,pdata{iii}.p))          = {[]};
%                             pdata{iii}.stat                                     = num2cell(stat);
%                             pdata{iii}.stat(cellfun(@isnan,pdata{iii}.stat))    = {[]};
%                             pdata{iii}.es                                       = num2cell(es);
%                             pdata{iii}.es(cellfun(@isnan,pdata{iii}.es))        = {[]};
% 
%                             sqlwrite(conn,tablename_pval,struct2table(pdata{iii}));
%                         end
%                     end
%                 end
            end
        end
    end
    
%%  END
%%
    
    