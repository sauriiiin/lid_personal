

    tablename_collection = 'DELETION_BY4741_SPACE_AGAR';
    collection = fetch(conn, sprintf(['select * ',...
        'from %s order by 384plate asc, 384col asc, 384row asc'], tablename_collection));
    n_ref = 5;
    
    
    for k = 1:length(unique(collection.x384plate_1))
      data{k} = col2grid(collection.strain_id(collection.x384plate_1 == k));
    end
    
    for kk = (length(unique(collection.x384plate_1)) + 1):(length(unique(collection.x384plate_1)) + n_ref)
        data{kk} = ones(16,24)*-1;
    end