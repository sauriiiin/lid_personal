%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  img2cs.m

%   Author: Saurin Parikh, July, 2021
%   load colony size data after all images are analyzed
%   dr.saurin.parikh@gmail.com

function data = loadcs(files)
    cs = load_colony_sizes(files);

%  Putting Colony Size (pixels) And Averages Together

    data = [];
    for ii = 1:size(cs,1) %single picture/time point
        data = [data, cs(ii,:)];
    end
    data = data';
    
end
