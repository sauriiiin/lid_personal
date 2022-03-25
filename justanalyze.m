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
    expt = input('Experiment Name: ', 's');
    fileID = fopen(sprintf('%s/%s_info.txt',toolkit_path,expt),'r');
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
        ~contains({filedir.name},'.info.mat') & ~contains({filedir.name},'.db') &...
        ~contains({filedir.name},'.xlsx') & ~contains({filedir.name},'.txt');
    
    subFiles = filedir(fileFlags);
    for k = 1 : length(subFiles)
        tmpfile = strcat(subFiles(k).folder, '/',  subFiles(k).name);
        files = [files; tmpfile];
        temp_meta = strsplit(erase(subFiles(k).name, '.JPG'), '_');
        temp_meta(1) = {strip(cell2mat(temp_meta(1)),'left','d')};
        metadata = [metadata; temp_meta];
    end
    metadata = [metadata files];
    metadata = sortrows(metadata, [1 3 4 5]);
    
    metadata = cell2table(metadata, 'VariableNames',...
        {'batch','temp','plate','date','time','filepath'});
 
    metadata.batch = str2double(metadata.batch);
    metadata.temp = str2double(metadata.temp);
    metadata.plate = str2double(metadata.plate);
    metadata.date = string(metadata.date);
    metadata.time = string(metadata.time);
    metadata.filepath = string(metadata.filepath);
    
    metadata = innerjoin(metadata, file_info, 'Keys',{'batch','plate'});
    metadata = sortrows(metadata,{'density','expt_id','stage_id','arm','date','time','plate'},...
        {'ascend','ascend','ascend','ascend','ascend','ascend','ascend'});
    
%%  PLATE DENSITY AND ANALYSIS PARAMETERS

    interval = input('Time interval between images: ');
    
    expi = unique(metadata.expt_id);
    for e = 1:length(expi)
        stgs = unique(metadata.stage_id(metadata.expt_id == expi(e)));
        for s = 1:length(stgs)
            arms = unique(metadata.arm(metadata.expt_id == expi(e) &...
                metadata.stage_id == stgs(s)));
            for a = 1:length(arms)
                temp_meta = metadata(metadata.expt_id == expi(e) &...
                    metadata.stage_id == stgs(s) & ...
                    metadata.arm == arms(a),:);
              
                hours = [];
                batch_nos  = unique(temp_meta.batch);
                for batch = 1:length(batch_nos)
                    file_nos  = length(temp_meta.filepath(temp_meta.batch == batch_nos(batch)));
                    plate_nos = length(unique(temp_meta.plate(temp_meta.batch == batch_nos(batch))));
                    if batch == 1
                        tmp_hrs = 0:interval:(file_nos/plate_nos - 1)*interval;
                        hours   = [hours; repmat(tmp_hrs, 1, plate_nos)'];
                    else
                        file_nos  = length(temp_meta.filepath(temp_meta.batch == batch_nos(batch)));
                        plate_nos = length(unique(temp_meta.plate(temp_meta.batch == batch_nos(batch))));
                        tmp_hrs = (hours(end)+interval):interval:((file_nos/plate_nos - 1)*interval+hours(end)+interval);
                        hours   = [hours; repmat(tmp_hrs, 1, plate_nos)'];
                    end
                end

                temp_files = cellstr(temp_meta.filepath);
                density = unique(temp_meta.density);
                
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
            
                skip_analysis = input('Do you want to skip image to colony-size analysis? [Y/N] ', 's');
                if skip_analysis == 'N'
                    just_analyze = input('Do you want to just analyze? [Y/N] ', 's');
                    img2cs(temp_files, dimensions, params, just_analyze);
                else
                    just_analyze = 'N';
                end
                
                if just_analyze == 'N' || skip_analysis == 'Y'
                    if input('Do you want to upload data to MySQL? [Y/N] ', 's') == 'Y'
                        disp('Proceeding to upload...')

                        cs_data = loadcs(temp_files);
                        raw_data = cs2sql(cs_data, info,...
                            expi(e), stgs(s), arms(a), density,...
                            unique(hours));

                        disp('Cleaning raw data to remove borders and light artifact.')

                        sql_info = {info{1,2}{3:5}}; % {usr, pwd, db}
                        conn = connSQL(sql_info);

                        tablename_bpos   = sprintf('%s_borderpos',expi(e));
                        tablename_raw    = sprintf('%s_%s_%s_%d_RAW',expi(e), stgs(s), arms(a),density);
                        tablename_clean  = sprintf('%s_%s_%s_%d_CLEAN',expi(e), stgs(s), arms(a),density);

                        exec(conn, sprintf('drop table %s',tablename_clean));
                        exec(conn, sprintf(['create table %s (pos bigint not null, hours double not null,'...
                            'average double default null, '...
                            'primary key (pos, hours))'], tablename_clean));

                        data_bpos = fetch(conn, sprintf('select * from %s',...
                            tablename_bpos));
                        
%                         raw_data = fetch(conn, sprintf('select * from %s', tablename_raw));
%                         clean_data = table2array(raw_data);
                        clean_data = raw_data;
                        clean_data(ismember(clean_data(:,1),data_bpos.pos),3) = NaN;
                        clean_data(clean_data(:,3) < 300, 3) = NaN;

                        datainsert(conn,tablename_clean,{'pos','hours','average'},clean_data);

                        if input(sprintf('Do you want a smudgebox for %s %s %s %d? [Y/N] ',...
                                expi(e), stgs(s), arms(a),density), 's') == 'Y'
                            tablename_sbox   = sprintf('%s_%s_%s_%d_smudgebox',expi(e), stgs(s), arms(a),density);
                            p2c_info = {info{1,2}{6},'plate_no','plate_row','plate_col'};
                            sbox = input('Enter colony positions to reject: [density, plate, row, col; density, plate, row, col;... ] \n');
                            exec(conn, sprintf('drop table %s',tablename_sbox));
                            exec(conn, sprintf(['create table %s ',...
                                '(pos bigint not null, primary key (pos))'],tablename_sbox));
                            for i = 1:size(sbox,1)
                                exec(conn, sprintf(['insert into %s ',...
                                    'select pos from %s ',...
                                    'where density = %d ',...
                                    'and plate_no = %d and plate_row = %d and plate_col = %d'],...
                                    tablename_sbox, p2c_info{1},...
                                    sbox(i,:)));
                            end  
                            exec(conn, sprintf(['update %s ',...
                                'set average = NULL ',...
                                'where pos in ',...
                                '(select pos from %s)'],tablename_clean,tablename_sbox));
                        end
                        
                        fprintf('Press enter to proceed.\n')
                        pause
                        
                        perform_lid = input('Do you want to perform LID Normalization? [Y/N] ', 's');
                        
                        if  perform_lid == 'Y'
                            cont.name = info{1,2}{11};

                            tablename_lac       = sprintf('%s_%s_%s_%d_LAC',expi(e), stgs(s), arms(a),density);
                            tablename_norm      = sprintf('%s_%s_%s_%d_NORM',expi(e), stgs(s), arms(a),density);
                            tablename_fit       = sprintf('%s_%s_%s_%d_FITNESS',expi(e), stgs(s), arms(a),density);
                            tablename_fits      = sprintf('%s_%s_%s_%d_FITNESS_STATS',expi(e), stgs(s), arms(a),density);
                            tablename_es        = sprintf('%s_%s_%s_%d_FITNESS_ES',expi(e), stgs(s), arms(a),density);
                            tablename_pval      = sprintf('%s_%s_%s_%d_PVALUE',expi(e), stgs(s), arms(a),density);
                            tablename_res       = sprintf('%s_%s_%s_%d_RES',expi(e), stgs(s), arms(a),density);

                            tablename_p2s       = sprintf('%s_pos2strainid',expi(e));
                            tablename_p2o       = sprintf('%s_pos2orf_name',expi(e));
                            tablename_s2o       = sprintf('%s_strainid2orf_name',expi(e));

                            tablename_p2p       = sprintf('%s_pos2rep',expi(e));

                            p2c_info = {sprintf('%s_pos2coor',expi(e)),'plate_no','plate_row','plate_col'};
                            p2c = fetch(conn, sprintf(['select * from %s a ',...
                                'where density = %d ',...
                                'order by a.%s, a.%s, a.%s'],...
                                p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

                            n_plates = fetch(conn, sprintf(['select distinct %s from %s ',...
                                'where density = %d ',...
                                'order by %s asc'],...
                                p2c_info{2},p2c_info{1},density,p2c_info{2}));
    
                            if input('Do you want to perform source-normalization? [Y/N] ', 's') == 'Y'
                                IL = 1; % 1 = to source norm / 0 = to not
                            else
                                IL = 0;
                            end

                            hours = fetch(conn, sprintf(['select distinct hours from %s ',...
                                'order by hours asc'], tablename_clean));
                            hours = hours.hours;
                            fit_data = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
                                tablename_p2o,tablename_clean,IL,density,dimensions,sql_info);

                            if isopen(conn) == 0
                                conn = connSQL(sql_info);
                            end

                            exec(conn, sprintf('drop table %s',tablename_norm));
                            exec(conn, sprintf(['create table %s ( ',...
                                        'pos bigint not NULL, ',...
                                        'hours double not NULL, ',...
                                        'bg double default NULL, ',...
                                        'average double default NULL, ',...
                                        'fitness double default NULL, ',...
                                        'primary key (pos, hours))'],tablename_norm));
                            for i=1:length(hours)
                                datainsert(conn, tablename_norm,...
                                    {'pos','hours','bg','average','fitness'},fit_data{i});
                            end

                            exec(conn, sprintf('drop table %s',tablename_fit)); 
                            exec(conn, sprintf(['create table %s (primary key (pos, hours))',...
                                '(select c.strain_id, b.orf_name, a.pos, a.hours, a.bg, a.average, a.fitness ',...
                                'from %s a, %s b , %s c ',...
                                'where a.pos = b.pos and b.pos = c.pos ',...
                                'order by a.hours, a.pos asc)'],...
                                tablename_fit,tablename_norm,tablename_p2o,tablename_p2s));  
                            
                            if input('Do you want to calculate empirical p-values? [Y/N] ', 's') == 'Y'

                                clear data

                                exec(conn, sprintf('drop table %s', tablename_fits));
                                exec(conn, sprintf(['create table %s (strain_id int not null, ',...
                                    'orf_name varchar(255) null, ',...
                                    'hours double not null, N int not null, cs_mean double null, ',...
                                    'cs_median double null, cs_std double null, ',...
                                    'primary key (strain_id, hours))'],tablename_fits));

                                colnames_fits = {'strain_id','orf_name','hours','N','cs_mean','cs_median','cs_std'};

                                stat_data = fitstats_sid(tablename_fit,sql_info);

                                tic
                                datainsert(conn,tablename_fits,colnames_fits,stat_data)
                            %     sqlwrite(conn,tablename_fits,struct2table(stat_data));
                                toc  

        % % % % % % % 

                                exec(conn, sprintf('drop table %s',tablename_pval));
                                exec(conn, sprintf(['create table %s (strain_id int not null, ',...
                                    'orf_name varchar(255) null,'...
                                    'hours double not null, p double null, stat double null, ',...
                                    'es double null, ',...
                                    'primary key (strain_id, hours))'],tablename_pval));
                                colnames_pval = {'strain_id','orf_name','hours','p','stat','es'};

                                contpos = fetch(conn, sprintf(['select a.pos, a.rep_pos ',...
                                    'from %s a, %s b ',...
                                    'where a.density = %d and a.pos = b.pos and b.orf_name = "%s" ',...
                                    'and a.pos not in (select pos from %s) ',...
                                    'order by a.pos'],...
                                    tablename_p2p, tablename_p2o,...
                                    density, cont.name,...
                                    tablename_bpos));

                                iden_contpos = unique(contpos.pos);

                                for iii = 1:length(hours)
                                    contfit = [];
                                    for ii = 1:length(iden_contpos)
                                        cp = sprintf('%d,',contpos.rep_pos(contpos.pos == iden_contpos(ii)));
                                        temp = fetch(conn, sprintf(['select fitness from %s ',...
                                            'where hours = %0.2f and pos in (%s) ',...
                                            'and fitness is not null'],tablename_fit,hours(iii),...
                                            cp(1:end-1)));

                                        if nansum(temp.fitness) > 0
                                            outlier = isoutlier(temp.fitness);
                                            temp.fitness(outlier) = NaN;
                                            contfit = [contfit, nanmean(temp.fitness)];
                                        end
                                    end
                                    contmean = nanmean(contfit);
                                    contstd = nanstd(contfit);

                                    orffit = fetch(conn, sprintf(['select strain_id, ',...
                                        'orf_name, cs_median, ',...
                                        'cs_mean, cs_std from %s ',...
                                        'where hours = %0.2f and orf_name != ''%s'' ',...
                                        'order by orf_name asc'],tablename_fits,hours(iii),cont.name));

                                    m = contfit';
                                    tt = length(m);
                                    pvals = [];
                                    es = [];
                                    stat = [];
                                    for i = 1:length(orffit.strain_id)
                                        if sum(m<orffit.cs_mean(i)) < tt/2
                                            if m<orffit.cs_mean(i) == 0
                                                pvals = [pvals; 1/tt];
                                                es = [es; (orffit.cs_mean(i) - contmean)/contmean];
                                                stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                                            else
                                                pvals = [pvals; ((sum(m<=orffit.cs_mean(i)))/tt)*2];
                                                es = [es; (orffit.cs_mean(i) - contmean)/contmean];
                                                stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                                            end
                                        else
                                            pvals = [pvals; ((sum(m>=orffit.cs_mean(i)))/tt)*2];
                                            es = [es; (orffit.cs_mean(i) - contmean)/contmean];
                                            stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                                        end
                                    end

                                    pdata{iii}.strain_id                                = orffit.strain_id;
                                    pdata{iii}.orf_name                                 = orffit.orf_name;
                                    pdata{iii}.hours                                    = ones(length(pdata{iii}.orf_name),1)*hours(iii);
                                    pdata{iii}.p                                        = num2cell(pvals);
                                    pdata{iii}.p(cellfun(@isnan,pdata{iii}.p))          = {[]};
                                    pdata{iii}.stat                                     = num2cell(stat);
                                    pdata{iii}.stat(cellfun(@isnan,pdata{iii}.stat))    = {[]};
                                    pdata{iii}.es                                       = num2cell(es);
                                    pdata{iii}.es(cellfun(@isnan,pdata{iii}.es))        = {[]};

                                    if isempty(pdata{iii}.hours) == 0
                                        sqlwrite(conn,tablename_pval,struct2table(pdata{iii}));
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
%%  END
%%
    
    
