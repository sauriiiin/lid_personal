

    expi_nos = unique(metadata(:,1));
    for exp = 1:length(expi_nos)
        plate_nos = unique(metadata(strcmpi(metadata(:,1), expi_nos{exp}),3));
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
    end
    
    
    hours = [];
    expi_nos = unique(metadata.expt_id);
    for exp = 1:length(expi_nos)
        arm_nos = unique(metadata.arm(strcmpi(metadata.expt_id, expi_nos{exp})));
        for arm = 1:length(arm_nos)
            stage_nos = unique(metadata.stage_id(strcmpi(metadata.expt_id, expi_nos{exp}) &...
                strcmpi(metadata.arm, arm_nos{arm})));
            for stage = 1:length(stage_nos)
                plate_nos = unique(metadata.plate(strcmpi(metadata.expt_id, expi_nos{exp}) &...
                    strcmpi(metadata.arm, arm_nos{arm}) & strcmpi(metadata.stage_id, stage_nos{stage})));
                for i = 1:length(plate_nos)
                    temp_meta = metadata(strcmpi(metadata.expt_id, expi_nos{exp}) &...
                        strcmpi(metadata.arm, arm_nos{arm}) & strcmpi(metadata.stage_id, stage_nos{stage}) &...
                        metadata.plate == plate_nos(i),:);
                    
                    temp_t0 = sprintf('%s %s', temp_meta.date(1), temp_meta.time(1));
                    hours = [hours; 0];
                    for ii = 2:size(temp_meta, 1)
                        temp_tii = sprintf('%s %s', temp_meta.date(ii), temp_meta.time(ii));
                        [y,m,d,h,mi,s] = datevec(between(datetime(temp_t0,...
                            'Format', 'MM-dd-yy HH-mm-ss'), ...
                            datetime(temp_tii,...
                            'Format', 'MM-dd-yy HH-mm-ss')));
                        temp_interval = [y*365*24, m*30*24, d*24, h, mi/60, s/(60*60)];
                        hours = [hours; sum(temp_interval)];
                    end
                end
            end
        end
    end