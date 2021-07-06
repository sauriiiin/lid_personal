%%  COLLECT IMAGES WITH NO GRID
%   Those images that weren't analyzed correctly

        all = zeros(1, size(temp_files, 1));
        for ii = 1 : size(all, 2)
            all(ii) = exist(strcat(temp_files{ii}, '.binary'));
        end
        pos = find(all==0);

        if isempty(pos)
            disp('All images were successfully analyzed.')
        else
            fprintf('%d image/s were not analyzed.\n',length(pos))
            alt_thresh = input('Would you like to re-analyze all images using a different background threshold? [Y/N] ', 's');
            if alt_thresh == 'Y'
                thresh = input('New threshold (default = 1.25): ');
                params = { ...
                    'parallel', true, ...
                    'verbose', true, ...
                    'grid', OffsetAutoGrid('dimensions', dimensions), ... default
                    'threshold', BackgroundOffset('offset', thresh) };
                analyze_directory_of_images(temp_files, params{:} );

                all = zeros(1, size(temp_files, 1));
                for ii = 1 : size(all, 2)
                    all(ii) = exist(strcat(temp_files{ii}, '.binary'));
                end
                pos2 = find(all==0);
                if isempty(pos2)
                    disp('All images were successfully analyzed with the new threshold.')
                else
                    fprintf('%d image/s were not analyzed.\n Manually place grid using previous threshold\n',length(pos))
                    for ii = 1 : length(pos)
                        analyze_image( temp_files{pos(ii)}, params{:}, ...
                            'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                    end
                end
            else
                disp('Manually place grid on images')
                for ii = 1 : length(pos)
                    analyze_image( temp_files{pos(ii)}, params{:}, ...
                        'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                end
            end
        end

    fprintf('Examine binary images to verify proper colony detection before going forward.\nPress enter to proceed.\n')
    pause
    
    if input('Are the images properly analyzed? [Y/N]: ', 's') == 'N'
        if input('Is there a problem with all of them? [Y/N]: ', 's') == 'Y'
            disp('Manually place grid on all images')
            for ii = 1 : length(temp_files)
                analyze_image( temp_files{ii}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        else
            pos = input('Problematic images: ');
            
            disp('Manually place grid on images')
            for ii = 1 : length(pos)
                analyze_image( temp_files{pos(ii)}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        end
    end
    
%     disp('Press enter to proceed.')
%     pause
    
%%  LOAD COLONY SIZE

    disp('Proceeding to upload raw data to mySQL.')
    cs = load_colony_sizes(temp_files);

%  Putting Colony Size (pixels) And Averages Together
    master = [];
    tmp = [];
    i = 1;
    
    for ii = 1:size(cs,1) %single picture/time point
        tmp = cs(ii,:);
        master = [master, tmp];
    end
    master = master';

%%%%%%%%%%%%%%
%%  UPLOAD RAW COLONY SIZE DATA TO SQL

    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    tablename_raw  = sprintf('%s_%d_RAW',expt_set,density);
        
    p2c_info = {info{1,2}{5},'plate','row','col'};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

    exec(conn, sprintf('drop table %s',tablename_raw));  
    exec(conn, sprintf(['create table %s (pos bigint not null, hours double not null,'...
        'image1 double default null, image2 double default null, ',...
        'image3 double default null, average double default null, '...
        'primary key (pos, hours))'], tablename_raw));

    colnames_raw = {'pos','hours'...
        'image1','image2','image3',...
        'average'};

    tmpdata = [];
    for ii=1:length(hours)
        tmpdata = [tmpdata; [p2c.pos, ones(length(p2c.pos),1)*hours(ii)]];
    end

    data = [tmpdata,master];
    tic
    datainsert(conn,tablename_raw,colnames_raw,data);
    toc
    
%%  SPATIAL CLEANUP
%   Border colonies, light artefact and smudge correction
    disp('Cleaning raw data to remove borders and light artifact.')
    
    tablename_clean  = sprintf('%s_%d_CLEAN',expt_set,density);
    tablename_bpos  = info{1,2}{9};

    exec(conn, sprintf('drop table %s',tablename_clean));
    exec(conn, sprintf(['create table %s (primary key (pos, hours)) ',...
        '(select * from %s)'], tablename_clean, tablename_raw));

    exec(conn, sprintf(['update %s ',...
        'set image1 = NULL, image2 = NULL, ',...
        'image3 = NULL, average = NULL ',...
        'where pos in ',...
        '(select pos from %s)'],tablename_clean,tablename_bpos));

    exec(conn, sprintf(['update %s ',...
        'set image1 = NULL, image2 = NULL, ',...
        'image3 = NULL, average = NULL ',...
        'where average <= 10'],tablename_clean));

%%  SMUDGE_BOX

    if input('Did you notice any smudges on the colony grid? [Y/N] ', 's') == 'Y'
        tablename_sbox  = sprintf('%s_smudgebox', expt_set);

    %   [density, plate, row, col ; density, plate, row, col ;...; density, plate, row, col]
        sbox = input('Enter colony positions to reject: [density, plate, row, col; density, plate, row, col;... ] \n');

        exec(conn, sprintf('drop table %s',tablename_sbox));
        exec(conn, sprintf(['create table %s ',...
            '(pos bigint not null)'],tablename_sbox));

        for i = 1:size(sbox,1)
            exec(conn, sprintf(['insert into %s ',...
                'select pos from %s ',...
                'where density = %d ',...
                'and plate = %d and row = %d and col = %d'],...
                tablename_sbox, p2c_info{1},...
                sbox(i,:)));
        end  

        exec(conn, sprintf(['update %s ',...
            'set replicate1 = NULL, replicate2 = NULL, ',...
            'replicate3 = NULL, average = NULL ',...
            'where pos in ',...
            '(select pos from %s)'],tablename_clean,tablename_sbox));
    end