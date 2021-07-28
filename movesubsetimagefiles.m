temp_files = metadata.filepath((metadata.expt_id == expi(e) &...
                        metadata.stage_id == stgs(s) & ...
                        metadata.arm == arms(1) & ...
                        ismember(metadata.hours, [0,40,80,120,164])));
                    
destFolder = '/home/sbp29/RAW_Data/Methionine/Overexpression/04_PS2_';

for f = 1:length(temp_files)
    movefile(temp_files(f), destFolder);
end