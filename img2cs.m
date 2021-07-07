%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  img2cs.m

%   Author: Saurin Parikh, July, 2021
%   image file analysis using MCAT
%   image analysis heart
%   dr.saurin.parikh@gmail.com

function img2cs(files, dimensions, params)
    
    all = zeros(1, size(files, 1));
    for ii = 1 : size(all, 2)
        all(ii) = exist(strcat(files{ii}, '.binary'));
    end
    pos = find(all==0);
    
    if isempty(pos)
        disp('All files are already analyzed.')
        if input('Do you want to re-analyze them? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
            direct_upload = 'Y';
        end
    else
        fprintf('%d out of %d images remain to be analyzed.\n',...
            length(pos),...
            length(files))
        if input('Do you want to re-analyze all? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
%             files2 = files(pos);
%             analyze_directory_of_images(files2, params{:} );
            direct_upload = 'N';
        end
    end

    if direct_upload == 'N'
%%  COLLECT IMAGES WITH NO GRID
%   Those images that weren't analyzed correctly

        all = zeros(1, size(files, 1));
        for ii = 1 : size(all, 2)
            all(ii) = exist(strcat(files{ii}, '.binary'));
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
                analyze_directory_of_images(files, params{:} );

                all = zeros(1, size(files, 1));
                for ii = 1 : size(all, 2)
                    all(ii) = exist(strcat(files{ii}, '.binary'));
                end
                pos2 = find(all==0);
                if isempty(pos2)
                    disp('All images were successfully analyzed with the new threshold.')
                else
                    fprintf('%d image/s were not analyzed.\n Manually place grid using previous threshold\n',length(pos))
                    for ii = 1 : length(pos)
                        analyze_image( files{pos(ii)}, params{:}, ...
                            'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                    end
                end
            else
                disp('Manually place grid on images')
                for ii = 1 : length(pos)
                    analyze_image( files{pos(ii)}, params{:}, ...
                        'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                end
            end
        end
    end
    
    fprintf('Examine binary images to verify proper colony detection before going forward.\nPress enter to proceed.\n')
    pause
    
    if input('Are the images properly analyzed? [Y/N]: ', 's') == 'N'
        if input('Is there a problem with all of them? [Y/N]: ', 's') == 'Y'
            disp('Manually place grid on all images')
            for ii = 1 : length(files)
                analyze_image( files{ii}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        else
            pos = input('Problematic images: ');
            
            disp('Manually place grid on images')
            for ii = 1 : length(pos)
                analyze_image( files{pos(ii)}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        end
    end
    
end