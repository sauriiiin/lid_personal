

temp_files = metadata.filepath((metadata.expt_id == expi(e) &...
                        metadata.stage_id == stgs(s) & ...
                        ismember(metadata.hours, [30])));
                    
% temp_files = metadata.filepath(ismember(metadata.hours, [0,4,8]));
                    
destFolder = '/home/sbp29/RAW_Data/TranslatomeOE/30h';

for f = 1:length(temp_files)
    copyfile(temp_files(f), destFolder); %movefile
end