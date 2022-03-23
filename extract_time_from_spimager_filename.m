

%     expi_nos = unique(metadata(:,1));
%     for exp = 1:length(expi_nos)
%         plate_nos = unique(metadata(strcmpi(metadata(:,1), expi_nos{exp}),3));
%         for i = 1:size(plate_nos,1)
%             temp_meta = metadata(strcmpi(metadata(:,3), plate_nos(i)),:);
%             temp_t0 = temp_meta(1,4:5);
%             hours = [hours; 0];
%             for ii = 2:size(temp_meta, 1)
%                 temp_t1 = temp_meta(ii,4:5);
%                 [y,m,d,h,mi,s] = datevec(between(datetime(sprintf('%s %s', temp_t0{:}),...
%                     'Format', 'MM-dd-yy HH-mm-ss'), ...
%                     datetime(sprintf('%s %s', temp_t1{:}),...
%                     'Format', 'MM-dd-yy HH-mm-ss')));
%                 temp_interval = [y*365*24, m*30*24, d*24, h, mi/60, s/(60*60)];
%                 hours = [hours; sum(temp_interval)];
%             end
%         end
%     end