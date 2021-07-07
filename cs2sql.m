%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  cs2sql.m

%   Author: Saurin Parikh, July, 2021
%   upload colony size data to SQL
%   dr.saurin.parikh@gmail.com

function cs2sql(cs_data, info, expt_name, stage_name, arm_name, density)

    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    tablename_raw  = sprintf('%s_%s_%s_%d_RAW',...
        expt_name,stage_name,arm_name,density);
        
    p2c_info = {info{1,2}{5},'plate','row','col'};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

    exec(conn, sprintf('drop table %s',tablename_raw));  
    exec(conn, sprintf(['create table %s (pos bigint not null, hours double not null,'...
        'average double default null, '...
        'primary key (pos, hours))'], tablename_raw));

    colnames_raw = {'pos','hours','average'};

    tmpdata = [];
    uhours = unique(metadata.hours);
    for ii=1:length(uhours)
        tmpdata = [tmpdata; [p2c.pos, ones(length(p2c.pos),1)*uhours(ii)]];
    end

    data = [tmpdata,cs_data];
    tic
    datainsert(conn,tablename_raw,colnames_raw,data);
    toc
    
end