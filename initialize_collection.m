

%     tablename_collection = 'BARFLEX_SPACE_AGAR';
%     collection = fetch(conn, sprintf(['select * ',...
%         'from %s order by 384plate asc, 384col asc, 384row asc'], tablename_collection));
%     n_ref = 5;
    
    collection = fetch(conn, ['select * from BARFLEX_SPACE_AGAR_180313 ',...
        'union ',...
        'select * from PROTOGENE_COLLECTION']);
    plate384 = fetch(conn, 'select * from PLATE384');
    n_ref = 5;
    col_plates = unique(collection.x384plate_1(~isnan(collection.x384plate_1)));
    n_col_plates = length(col_plates);
    
    for k = 1:n_col_plates
%       data{k} = col2grid(collection.strain_id(collection.x384plate_1 == k));
      temp = collection(collection.x384plate_1 == col_plates(k),:);
      temp = outerjoin(temp, plate384, 'Keys', {'x384col_1', 'x384row_1'},...
        'Type', 'right','MergeKeys',true);
      temp = sortrows(temp,'pos','ascend');
      data{k} = col2grid(temp.strain_id);
    end
    
    for kk = (n_col_plates + 1):(n_col_plates + n_ref)
        data{kk} = ones(16,24)*-1;
    end
    
    

    
    
    


   
    