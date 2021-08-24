

temp_files = metadata.filepath((metadata.expt_id == expi(e) &...
                        metadata.stage_id == stgs(s) & ...
                        ismember(metadata.hours, [0,40,68])));
                    
% temp_files = metadata.filepath(ismember(metadata.hours, [0,4,8]));
                    
destFolder = '/home/sbp29/RAW_Data/Methionine/NoSulfate_/S5';

for f = 1:length(temp_files)
    movefile(temp_files(f), destFolder);
end