function video_label_gui
    %[fileName, pathName] = uigetfile('\\C:\Users\sally\HMS Dropbox\Jia Yin Xiao\ForSally\*.avi', 'Select avi files', 'MultiSelect', 'off');
    [fileName, pathName] = uigetfile('\\C:\Users\sally\Desktop\*.mp4', 'Select avi files', 'MultiSelect', 'off');
    videoFile = fullfile(pathName, fileName);
    v = VideoReader(fileName);
    nFrames = floor(v.Duration * v.FrameRate);

    % Store labels
    labeledSegments = {};
    rangeStart = [];

    isPlaying = false;     % Flag for playback loop
    playbackSpeed = 1.0;   % Default playback speed


    % Create figure and UI components
    hFig = figure('Name', 'Video Labeler', 'NumberTitle', 'off', ...
                  'Position', [100 100 2000 2000]);
    hAx = axes('Parent', hFig, 'Position', [0.1 0.2 0.8 0.7]);
    % hSlider = uicontrol('Style', 'slider', 'Min', 1, 'Max', nFrames, ...
    %     'Value', 1, 'SliderStep', [1/(nFrames-1), 10/(nFrames-1)], ...
    %     'Position', [150 20 600 20], 'Callback', @sliderCallback);
    % Panel to hold slider and allow mouse tracking
    hSliderPanel = uipanel('Position', [0.05, 0.02, 0.9, 0.08], ...
        'Units', 'normalized', ...
        'BorderType', 'none');

    % Large slider inside panel
    hSlider = uicontrol('Parent', hSliderPanel, 'Style', 'slider', ...
        'Min', 1, 'Max', nFrames, ...
        'Value', 1, ...
        'SliderStep', [1/(nFrames-1), 10/(nFrames-1)], ...
        'Units', 'normalized', ...
        'Position', [0, 0.3, 1, 0.5], ...
        'Callback', @sliderCallback);

    hText = uicontrol('Style', 'text', 'Position', [390 50 120 20], ...
                      'String', 'Frame 1');

    hStartBtn = uicontrol('Style', 'pushbutton', 'String', 'Set Start', ...
        'Position', [100 100 100 30], 'Callback', @setStart);

    hEndBtn = uicontrol('Style', 'pushbutton', 'String', 'Set End + Label', ...
        'Position', [220 100 120 30], 'Callback', @setEnd);

    hSaveBtn = uicontrol('Style', 'pushbutton', 'String', 'Save Labels', ...
        'Position', [360 100 100 30], 'Callback', @saveLabels);
    hPlayBtn = uicontrol('Style', 'pushbutton', 'String', 'Play', ...
        'Position', [480 100 70 30], 'Callback', @playVideo);

    hPauseBtn = uicontrol('Style', 'pushbutton', 'String', 'Pause', ...
        'Position', [560 100 70 30], 'Callback', @pauseVideo);

    hSpeedPopup = uicontrol('Style', 'popupmenu', ...
        'String', {'1x','2x','5x','10x','20x'}, ...
        'Position', [640 100 60 30], 'Callback', @setSpeed);
    hLabelTable = uitable('Parent', hFig, ...
    'Position', [1230 200 180 400], ...
    'Data', {}, ...
    'ColumnName', {'Start', 'End', 'Label'}, ...
    'ColumnWidth', {50, 50, 50});
    hTimeline = axes('Parent', hFig, ...
    'Position', [0.1 0.15 0.8 0.03], ...
    'XColor', 'none', 'YColor', 'none');
    % Frame input box
    hFrameInput = uicontrol('Style', 'edit', ...
        'Position', [1280 640 100 30], ...
        'String', '', ...
        'TooltipString', 'Enter frame number');

    % Go button
    hGotoButton = uicontrol('Style', 'pushbutton', ...
        'String', 'Go', ...
        'Position', [1230 640 50 30], ...
        'Callback', @gotoFrame);
    hEditLabelBtn = uicontrol('Style', 'pushbutton', ...
    'String', 'Edit Label', ...
    'Position', [850 100 100 30], ...
    'Callback', @editSelectedLabel);
    hTimelineBtn = uicontrol('Style', 'pushbutton', ...
    'String', 'Update Timeline', ...
    'Position', [1000 100 140 30], ...
    'Callback', @updateTimeline);





    % Display first frame
    v.CurrentTime = 0;
    frame = readFrame(v);
    hImg = imshow(frame, 'Parent', hAx);

    % Store current frame number
    currentFrame = 1;

    %% --- Nested callback functions ---
    function playVideo(~, ~)
        isPlaying = true;  % Set global flag
        v = VideoReader(fullfile(pathName, fileName));
        startFrame = round(hSlider.Value);  % <-- correct case
        v.CurrentTime = (startFrame - 1) / v.FrameRate;

        skipStep = round(playbackSpeed);  % 2, 5, or 10
        currentFrame = startFrame;

        while hasFrame(v) && isPlaying && currentFrame <= nFrames
            v.CurrentTime = (currentFrame - 1) / v.FrameRate;
            frame = readFrame(v);

            imshow(frame, 'Parent', hAx);  % <-- correct case
            hText.String = ['Frame ', num2str(currentFrame)];
            hSlider.Value = currentFrame;
            drawnow;

            pause(0.01);  % Optional: small pause to allow UI refresh
            currentFrame = currentFrame + skipStep;
        end
    end

    function pauseVideo(~, ~)
        isPlaying = false;
    end

    function setSpeed(src, ~)
        val = src.Value;
        switch val
            case 1
                playbackSpeed = 1.0;
            case 2
                playbackSpeed = 2.0;
            case 3
                playbackSpeed = 5.0;
            case 4
                playbackSpeed = 10.0;
            case 5
                playbackSpeed = 20.0;
        end
        disp(['Playback speed set to ', num2str(playbackSpeed), 'x']);
    end



    function sliderCallback(~, ~)
        %     currentFrame = round(hSlider.Value);
        %     v = VideoReader(videoFile);  % reinit reader
        %     v.CurrentTime = (currentFrame - 1) / v.FrameRate;
        %     frame = readFrame(v);
        %     imshow(frame, 'Parent', hAx);
        %     hText.String = ['Frame ', num2str(currentFrame)];
        % end
        currentFrame = round(hSlider.Value);
        try
            v = VideoReader(fullfile(pathName, fileName));  % safer
            v.CurrentTime = (currentFrame - 1) / v.FrameRate;
            frame = readFrame(v);
            imshow(frame, 'Parent', hAx);
            hText.String = ['Frame ', num2str(currentFrame)];
        catch
            warning('Could not read frame %d.', currentFrame);
        end
    end

    function setStart(~, ~)
        rangeStart = currentFrame;
        disp(['Start frame set to ', num2str(rangeStart)]);
    end
    function c = getColorForLabel(lbl)
        switch lbl
            case 'A', c = [0.2 0.6 1];
            case 'B', c = [1 0.4 0.4];
            case 'C', c = [0.4 1 0.4];
            case 'D', c = [1 0.8 0.2];
            case 'E', c = [0.8 0.2 1];
            case 'F', c = [0.6 0.6 0.6];
            otherwise, c = [0.8 0.8 0.8];
        end
    end

    function setEnd(~, ~)
        if isempty(rangeStart)
            warndlg('You must set a start frame first!', 'Warning');
            return;
        end

        rangeEnd = currentFrame;
        prompt = {'Enter label name:'};
        dlgtitle = 'Label Input';
        dims = [1 35];
        definput = {''};
        answer = inputdlg(prompt, dlgtitle, dims, definput);

        if ~isempty(answer)
            label = answer{1};
            labeledSegments{end+1, 1} = rangeStart; %#ok<AGROW>
            labeledSegments{end, 2} = rangeEnd;
            labeledSegments{end, 3} = label;
            fprintf('Labeled frames %d to %d as "%s"\n', ...
                rangeStart, rangeEnd, label);
            rangeStart = [];  % Reset
        end

        % Update the label table preview
        hLabelTable.Data = labeledSegments;

        % Update timeline (no selected index)
        % plotTimeline();  % Call with no input
    end

    function plotTimeline()
        cla(hTimeline);
        hold(hTimeline, 'on');

        for i = 1:size(labeledSegments, 1)
            s = labeledSegments{i, 1};
            e = labeledSegments{i, 2};
            lbl = labeledSegments{i, 3};
            c = getColorForLabel(lbl);

            rectangle('Parent', hTimeline, ...
                'Position', [s, 0, e - s + 1, 1], ...
                'FaceColor', c, ...
                'EdgeColor', 'none');
        end

        xlim(hTimeline, [1 nFrames]);
        ylim(hTimeline, [0 1]);
        hold(hTimeline, 'off');
    end

    function updateTimeline(~, ~)
        plotTimeline();  % Just call your existing function
    end



    function gotoFrame(~, ~)
        val = str2double(get(hFrameInput, 'String'));

        if isnan(val) || val < 1 || val > nFrames
            warndlg('Please enter a valid frame number within range.', 'Invalid Frame');
            return;
        end

        targetFrame = round(val);
        hSlider.Value = targetFrame;
        currentFrame = targetFrame;  % update shared variable if used
        sliderCallback();  % jump and display
    end

    function editSelectedLabel(~, ~)
        idx = hGotoLabelMenu.Value - 1;
        if idx < 1
            warndlg('Please select a labeled segment to edit.', 'No Selection');
            return;
        end

        oldLabel = labeledSegments{idx, 3};
        prompt = {sprintf('Change label from "%s" to:', oldLabel)};
        dlgtitle = 'Edit Label';
        dims = [1 35];
        definput = {oldLabel};
        answer = inputdlg(prompt, dlgtitle, dims, definput);

        if isempty(answer)
            return;  % User cancelled
        end

        newLabel = answer{1};
        labeledSegments{idx, 3} = newLabel;

        % Update label table
        hLabelTable.Data = labeledSegments;

        % Update dropdown menu
        menuItems = {'<Go to Label>'};
        for i = 1:size(labeledSegments, 1)
            s = labeledSegments{i, 1};
            e = labeledSegments{i, 2};
            lbl = labeledSegments{i, 3};
            menuItems{end+1} = sprintf('%s (%d–%d)', lbl, s, e);
        end
        set(hGotoLabelMenu, 'String', menuItems, 'Value', idx + 1);

        % Optional: replot timeline if using one
        plotTimeline();
    end



    function saveLabels(~, ~)
        if isempty(labeledSegments)
            warndlg('No labels to save.', 'Warning');
            return;
        end

        % Get total number of frames
        % Ensure totalFrames and labels match
        totalFrames = nFrames;
        frameNumbers = (1:totalFrames)';
        frameLabels = strings(totalFrames, 1);
        frameLabels(:) = "NA";  % Default

        % Assign labels with clipping
        for i = 1:size(labeledSegments, 1)
            s = labeledSegments{i, 1};
            e = labeledSegments{i, 2};
            lbl = labeledSegments{i, 3};

            % Clip to bounds
            s = max(1, min(totalFrames, s));
            e = max(1, min(totalFrames, e));

            frameLabels(s:e) = lbl;
        end

        % Now safe to create table
        fullLabelTable = table(frameNumbers, frameLabels, ...
            'VariableNames', {'Frame', 'Label'});
        labeledData = cell2table(labeledSegments, ...
            'VariableNames', {'StartFrame', 'EndFrame', 'Label'});


        % Save to .mat
        choice = questdlg('Do you want to save the results?', 'Yes', 'No');

        if strcmp(choice, 'Yes')
            uisave({'labeledData', 'fullLabelTable'}, fullfile(pathName,'labeled_output.mat'));
            %writetable(fullLabelTable, fullfile(pathName, 'frame_labels.csv'));
        end

        msgbox('Labeled data and full frame label table saved.', 'Success');
    end

    % function showPreviewOnHover(~, ~)
    %     mousePos = get(hFig, 'CurrentPoint');
    %     sliderPos = getpixelposition(hSlider, true);
    % 
    %     % Check if mouse is over the slider
    %     if mousePos(1) >= sliderPos(1) && mousePos(1) <= sliderPos(1) + sliderPos(3) && ...
    %             mousePos(2) >= sliderPos(2) && mousePos(2) <= sliderPos(2) + sliderPos(4)
    % 
    %         % Convert mouse X to frame number
    %         relativeX = (mousePos(1) - sliderPos(1)) / sliderPos(3);
    %         hoverFrame = round(1 + (nFrames - 1) * relativeX);
    % 
    %         % Bounds check
    %         hoverFrame = max(1, min(nFrames, hoverFrame));
    % 
    %         try
    %             v = VideoReader(videoFile);
    %             v.CurrentTime = (hoverFrame - 1) / v.FrameRate;
    %             previewFrame = readFrame(v);
    % 
    %             axes(hPreviewAxes);
    %             imshow(previewFrame, 'Parent', hPreviewAxes);
    %             set(hPreviewAxes, 'Visible', 'on');
    %             title(hPreviewAxes, ['Frame ', num2str(hoverFrame)], 'FontSize', 8);
    %         catch
    %             set(hPreviewAxes, 'Visible', 'off');
    %         end
    %     else
    %         set(hPreviewAxes, 'Visible', 'off');
    %     end
    % end


end
