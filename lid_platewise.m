%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  lid_platewise.m
%
%   Author: Saurin Parikh, April 2021
%   dr.saurin.parikh@gmail.com
%   
%   Final version of the LI Detector Pipeline
%       - applied platewise 
%       - for cases where each plate represents a different condition
%
%   Colony Size/JPEG data to P-VALUES for any experiment with  
%   Linear Interpolation based Reference Normalization.
%   Inputs Required:
%       sql info (username, password, database name),
%       experiment name, pos2coor tablename, pos2orf_name tablename, 
%       control name, borderpos, smudgebox

%%  Load Paths to Files and Expt Info

%   open load_toolkit.m and update the paths
    loadtoolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
    fileID = fopen(sprintf('%s/info.txt',toolkit_path),'r');
    info = textscan(fileID, '%s%s');

%%  INITIALIZATION
    
%   MySQL Connection
    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    cont.name = info{1,2}{10};
    
    stage = {{'F28FUR_S3',384}, {'F28FUR_PS2',1536},...
        {'F28FUR_FS',6144}, {'F28FUR_FS_R1',1536}, {'F28FUR_FS_R2',1536}};
    
%%   

    for s = 1:length(stage) 
        
        expt_set = stage{s}{1};
        density = stage{s}{2};

        if density == 6144
            dimensions = [64 96];
        elseif density == 1536
            dimensions = [32 48];
        elseif density == 384
            dimensions = [16 24];
        else
            dimensions = [8 12];
        end

        tablename_raw       = sprintf('%s_%d_RAW',expt_set,density);
        tablename_clean     = sprintf('%s_%d_CLEAN',expt_set,density);
        tablename_lac       = sprintf('%s_%d_LAC',expt_set,density);
        tablename_norm      = sprintf('%s_%d_NORM',expt_set,density);
        tablename_fit       = sprintf('%s_%d_FITNESS',expt_set,density);
        tablename_fits      = sprintf('%s_%d_FITNESS_STATS',expt_set,density);
        tablename_es        = sprintf('%s_%d_FITNESS_ES',expt_set,density);
        tablename_pval      = sprintf('%s_%d_PVALUE',expt_set,density);
        tablename_res       = sprintf('%s_%d_RES',expt_set,density);

        tablename_p2s  = info{1,2}{6};
        tablename_p2o  = info{1,2}{7};
        tablename_s2o  = info{1,2}{8};
        tablename_bpos = info{1,2}{9};

        tablename_p2p   = info{1,2}{11};

        p2c_info = {info{1,2}{5},'plate','row','col'};
        p2c = fetch(conn, sprintf(['select * from %s a ',...
            'where density = %d ',...
            'order by a.%s, a.%s, a.%s'],...
            p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

        n_plates = fetch(conn, sprintf(['select distinct %s from %s ',...
            'where density = %d ',...
            'order by %s asc'],...
            p2c_info{2},p2c_info{1},density,p2c_info{2}));
    
%%  JPEG COMPETITION CORRECTION

        lac = input('Do you want to use local artifact correction? [Y/N] ', 's');
        if  lac == 'Y'
            lac_data = LocalCorrection(p2c_info,density,cont.name,...
                tablename_s2o,tablename_p2s,tablename_raw,sql_info);

            exec(conn, sprintf('drop table %s',tablename_lac));
            exec(conn, sprintf(['create table %s ( ',...
                'pos bigint not NULL, ',...
                'hours double not NULL, ',...
                'average double default NULL, ',...
                'primary key (pos, hours))'],tablename_lac));
            datainsert(conn, tablename_lac,...
                {'pos','hours','average'},lac_data);

            exec(conn, sprintf(['update %s ',...
                'set average = NULL ',...
                'where pos in ',...
                '(select pos from %s)'],tablename_lac,tablename_bpos));

            exec(conn, sprintf(['update %s ',...
                'set average = NULL ',...
                'where average <= 10'],tablename_lac));

            if input('Do you have a smudgebox table? [Y/N] ', 's') == 'Y'
                tablename_sbox  = sprintf('%s_smudgebox', expt_set);
                exec(conn, sprintf(['update %s ',...
                    'set average = NULL ',...
                    'where pos in ',...
                    '(select pos from %s)'],tablename_lac,tablename_sbox));
            end
        end
    
%%  SPATIAL BIAS CORRECTION
%   Linear Interpolation based CN

        if input('Do you want to perform source-normalization? [Y/N] ', 's') == 'Y'
            IL = 1; % 1 = to source norm / 0 = to not
        else
            IL = 0;
        end

        if lac == 'Y'
            hours = fetch(conn, sprintf(['select distinct hours from %s ',...
                'order by hours asc'], tablename_lac));
            hours = hours.hours;
            fit_data = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
                tablename_p2o,tablename_lac,IL,density,dimensions,sql_info);
        else
            hours = fetch(conn, sprintf(['select distinct hours from %s ',...
                'order by hours asc'], tablename_clean));
            hours = hours.hours;
            fit_data = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
                tablename_p2o,tablename_clean,IL,density,dimensions,sql_info);
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
    
%%  FITNESS STATS

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
    
%%  FITNESS STATS to EMPIRICAL P VALUES

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

                sqlwrite(conn,tablename_pval,struct2table(pdata{iii}));
            end
        end
    end
        
%%  END
    close(conn)
%%