clear;
[videos, path] = uigetfile( ...
    '\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\Behavior\CPP\*_CPP*.avi', ...
    'Select files','MultiSelect','on');
addpath(path);
if ischar(videos)
    videos = {videos};
end
roiFolder = fullfile(path, 'ROI_files');

if ~exist(roiFolder, 'dir')
    mkdir(roiFolder);
end
maxJump = 60; %Used for tracking loss

for vidIdx  = 1:numel(videos)
    videoFile = fullfile(path, videos{vidIdx});
    [~, baseName, ~] = fileparts(videos{vidIdx});
    fprintf('\nSelecting ROIs for %d/%d: %s\n', ...
        vidIdx, numel(videos), videos{vidIdx});

    v = VideoReader(videoFile);
    firstFrame = readFrame(v);

    %% Arena ROI
    figROI = figure;
    imshow(firstFrame);
    title({'Draw ARENA ROI', baseName}, 'Interpreter', 'none');

    arenaROI = drawpolygon;
    arenaMask = createMask(arenaROI);

    choice = questdlg('Use this ARENA ROI?', ...
        'Confirm arena ROI', ...
        'Yes','Redraw','Yes');

    while strcmp(choice, 'Redraw')
        delete(arenaROI)
        imshow(firstFrame);
        title({'Redraw ARENA ROI', baseName}, 'Interpreter', 'none');

        arenaROI = drawpolygon;
        arenaMask = createMask(arenaROI);

        choice = questdlg('Use this ARENA ROI?', ...
            'Confirm arena ROI', ...
            'Yes','Redraw','Yes');
    end

    %% Left chamber ROI
    figure(figROI)
    imshow(firstFrame);
    title({'Draw LEFT chamber ROI', baseName}, 'Interpreter', 'none');

    leftROI = drawpolygon;
    leftMask = createMask(leftROI);

    choice = questdlg('Use this LEFT ROI?', ...
        'Confirm left ROI', ...
        'Yes','Redraw','Yes');

    while strcmp(choice, 'Redraw')
        delete(leftROI)
        imshow(firstFrame);
        title({'Redraw LEFT chamber ROI', baseName}, 'Interpreter', 'none');

        leftROI = drawpolygon;
        leftMask = createMask(leftROI);

        choice = questdlg('Use this LEFT ROI?', ...
            'Confirm left ROI', ...
            'Yes','Redraw','Yes');
    end

    %% Right chamber ROI
    figure(figROI)
    imshow(firstFrame);
    title({'Draw RIGHT chamber ROI', baseName}, 'Interpreter', 'none');

    rightROI = drawpolygon;
    rightMask = createMask(rightROI);

    choice = questdlg('Use this RIGHT ROI?', ...
        'Confirm right ROI', ...
        'Yes','Redraw','Yes');

    while strcmp(choice, 'Redraw')
        delete(rightROI)
        imshow(firstFrame);
        title({'Redraw RIGHT chamber ROI', baseName}, 'Interpreter', 'none');

        rightROI = drawpolygon;
        rightMask = createMask(rightROI);

        choice = questdlg('Use this RIGHT ROI?', ...
            'Confirm right ROI', ...
            'Yes','Redraw','Yes');
    end

    %% Preview ROIs
    figure;
    imshow(firstFrame);
    hold on
    visboundaries(arenaMask, 'Color', 'w', 'LineWidth', 1);
    visboundaries(leftMask,  'Color', 'b', 'LineWidth', 1);
    visboundaries(rightMask, 'Color', 'r', 'LineWidth', 1);
    title({'Saved ROIs', baseName}, 'Interpreter', 'none');

    %% Save ROI file
    roiFile = fullfile(roiFolder, [baseName '_ROIs.mat']);

    save(roiFile, ...
        'arenaMask', ...
        'leftMask', ...
        'rightMask');

    fprintf('Saved ROI file: %s\n', roiFile);

    close(figROI)
end

for vidIdx = 1:numel(videos)

    videoFile = fullfile(path, videos{vidIdx});
    [~, baseName, ext] = fileparts(videos{vidIdx});

    fprintf('\nProcessing %d/%d: %s\n', ...
        vidIdx, numel(videos), videos{vidIdx});

    v = VideoReader(videoFile);
    firstFrame = readFrame(v);
    roiFile = fullfile(path, 'ROI_files', [baseName '_ROIs.mat']);
    load(roiFile, 'arenaMask', 'leftMask', 'rightMask');
    %% Tracking
    % Use separate background videos for background subtraction 
    backgroundVideoFile = fullfile(path, [baseName '_Bckg' ext]);
    if ~exist(backgroundVideoFile, 'file')
        fprintf('Background video not found: %s', baseName);
        v.CurrentTime = 0;
    % Use experiment videos for background subtraction
        N = 200;
        frames = [];

        for i = 1:N
            if ~hasFrame(v)
                break
            end

            frame = readFrame(v);
            gray = im2gray(frame);
            gray(~arenaMask) = 0;

            frames(:,:,i) = gray;
        end

        background = median(frames, 3);
    else
        fprintf('Using background video: %s\n', backgroundVideoFile);
        vBg = VideoReader(backgroundVideoFile);
        bgFrames = [];
        bgIdx = 0;

        while hasFrame(vBg)

            bgIdx = bgIdx + 1;

            bgFrame = readFrame(vBg);
            bgGray = im2gray(bgFrame);

            % Apply same arena mask
            bgGray(~arenaMask) = 0;

            bgFrames(:,:,bgIdx) = bgGray;
        end

        background = median(bgFrames, 3);
    end

    %tracking
    v.CurrentTime = 0;
    frameNum = 0;

    xPos = [];
    yPos = [];
    while hasFrame(v)

        frame = readFrame(v);
        frameNum = frameNum + 1;

        gray = im2gray(frame);
        gray(~arenaMask) = 0;

        diffFrame = abs(double(gray) - double(background));
        diffFrame(~arenaMask) = 0;

        bw = diffFrame > 10;

        bw = bwareaopen(bw, 80);
        bw = imclose(bw, strel('disk', 7));
        bw = imfill(bw, 'holes');
        bw(~arenaMask) = 0;

        % Keep largest full mouse object
        bw = bwareafilt(bw, 1);

        % Body-only mask
        bodyMask = imerode(bw, strel('disk', 7));
        bodyMask = imdilate(bodyMask, strel('disk', 6));
        bodyMask = bwareafilt(bodyMask, 1);
        bodyMask = imfill(bodyMask, 'holes');

        % Get body centroid
        stats = regionprops(bodyMask, 'Area', 'Centroid');

        bodyCentroid = [];

        if ~isempty(stats)
            [~, idx] = max([stats.Area]);
            bodyCentroid = stats(idx).Centroid;
            xPos(frameNum) = bodyCentroid(1);
            yPos(frameNum) = bodyCentroid(2);
        else
            xPos(frameNum) = NaN;
            yPos(frameNum) = NaN;
        end

        % Show only every 2500 frames
        if mod(frameNum,2500) == 0

            figure(1)
            clf

            imshow(gray, []);
            hold on

            visboundaries(bw, 'Color', 'r');
            visboundaries(bodyMask, 'Color', 'g');

            if ~isempty(bodyCentroid)
                plot(bodyCentroid(1), bodyCentroid(2), ...
                    'b.', 'MarkerSize', 25);
            end

            title(sprintf('Frame %d', frameNum))

            hold off
            drawnow
        end
    end

    %% Check how bad is the tracking issue
    trackX = NaN(size(xPos));
    trackY = NaN(size(yPos));

    badPoint = false(size(xPos));

    maxMissing = 30;   % max number of frames to carry previous position

    lastGood = [];
    missingCount = 0;

    for frameIdx = 1:length(xPos)

        rawPoint = [xPos(frameIdx), yPos(frameIdx)];

        % Case 1: raw centroid missing
        if any(isnan(rawPoint))

            badPoint(frameIdx) = true;
            missingCount = missingCount + 1;

            if ~isempty(lastGood) && missingCount <= maxMissing
                trackX(frameIdx) = lastGood(1);
                trackY(frameIdx) = lastGood(2);
            end

            continue
        end

        % Case 2: first good point
        if isempty(lastGood)

            trackX(frameIdx) = rawPoint(1);
            trackY(frameIdx) = rawPoint(2);

            lastGood = rawPoint;
            missingCount = 0;

            continue
        end

        % Case 3: compare current raw point to last accepted point
        jumpNow = hypot(rawPoint(1) - lastGood(1), ...
            rawPoint(2) - lastGood(2));

        if jumpNow <= maxJump

            % Accept current point
            trackX(frameIdx) = rawPoint(1);
            trackY(frameIdx) = rawPoint(2);

            lastGood = rawPoint;
            missingCount = 0;

        else

            % Reject current point
            badPoint(frameIdx) = true;
            missingCount = missingCount + 1;

            if missingCount <= maxMissing
                trackX(frameIdx) = lastGood(1);
                trackY(frameIdx) = lastGood(2);
            end
        end
    end

    smoothX = smoothdata(trackX, 'gaussian', 7, 'omitnan');
    smoothY = smoothdata(trackY, 'gaussian', 7, 'omitnan');

    figure
    imshow(firstFrame)
    hold on

    plot(smoothX, smoothY, '-', ...
        'Color', [0.2 0.2 0.2], ...
        'LineWidth', 1)

    plot(xPos(badPoint), yPos(badPoint), ...
        'ro', 'MarkerSize', 3)

    title({'Sequentially corrected trajectory', baseName}, ...
        'Interpreter', 'none')

    legend('Corrected track','Rejected raw points')
    axis ij
    axis equal
    %% Cosmetic
    figTrack = figure;
    imshow(firstFrame)
    hold on
    color = [0.2 0.2 0.2];
    validIdx = ~isnan(smoothX) & ~isnan(smoothY);

    x = smoothX(validIdx);
    y = smoothY(validIdx);

    % cmap = turbo(length(x));
    %
    % for i = 1:length(x)-1
    %
    %     plot(x(i:i+1), y(i:i+1), ...
    %         'Color', cmap(i,:), ...
    %         'LineWidth', 1.5);
    %
    % end
    plot(x, y, '-', 'Color', color,'LineWidth', 1)

    title({'Smoothed continuity-corrected trajectory', baseName}, ...
    'Interpreter', 'none')

    axis ij
    axis equal
    % Save as PDF
    pdfName = fullfile(path, ['track_' baseName '.pdf']);
    exportgraphics(figTrack, pdfName, ...
        'ContentType', 'image', ...
        'Resolution', 300);
    %% Heatmap

    binSize = 10;   % pixels per bin; try 5, 10, 15, 20

    imgH = size(arenaMask,1);
    imgW = size(arenaMask,2);

    xEdges = 1:binSize:(imgW+1);
    yEdges = 1:binSize:(imgH+1);

    x = trackX;
    y = trackY;

    % Remove NaNs
    validIdx = ~isnan(x) & ~isnan(y);
    x = x(validIdx);
    y = y(validIdx);

    N = histcounts2(y, x, yEdges, xEdges);

    percentMap = N ./ sum(N(:)) * 100;

    sigma = 1;   % smoothing strength in bins; try 1, 2, 3
    percentMapSmooth = imgaussfilt(percentMap, sigma);

    arenaSmall = imresize(arenaMask, size(percentMapSmooth), 'nearest');
    percentMapSmooth(~arenaSmall) = NaN;

    heatmapFull = imresize(percentMapSmooth, size(arenaMask), 'bilinear');

    % Remove anything outside arena
    heatmapFull(~arenaMask) = NaN;

    props = regionprops(arenaMask, 'BoundingBox');
    bbox = round(props.BoundingBox);

    arenaMaskCrop = imcrop(arenaMask, bbox);
    heatmapCrop = imcrop(heatmapFull, bbox);

    % Remove outside arena again after cropping
    heatmapCrop(~arenaMaskCrop) = NaN;

    arenaBG = ones([size(arenaMaskCrop), 3]) * 0.15;

    figHeatmap = figure;
    imshow(arenaBG)
    hold on

    h = imagesc(heatmapCrop);

    % Transparency only where heatmap is valid
    alphaData = ~isnan(heatmapCrop) & heatmapCrop > 0;
    set(h, 'AlphaData', 0.85 * alphaData);

    axis image
    axis ij
    axis off

    colormap(turbo)

    cb = colorbar;
    cb.Label.String = '% of time spent';

    vals = heatmapCrop(:);
    vals = vals(~isnan(vals) & vals > 0);

    upperLim = prctile(vals, 100);   % same as max(vals)
    clim([0 upperLim])

    title({'Cropped occupancy heatmap within arena mask', baseName}, ...
        'Interpreter', 'none')
    pdfName = fullfile(path, ['Heatmap_' baseName '.pdf']);
    exportgraphics(figHeatmap, pdfName, ...
        'ContentType', 'image', ...
        'Resolution', 300);
    %% Calculate percentage
    % Use corrected centroid positions
    x = trackX;
    y = trackY;

    nFrames = length(x);

    isLeft = false(nFrames,1);
    isRight = false(nFrames,1);
    isOther = false(nFrames,1);

    for j = 1:nFrames

        if isnan(x(j)) || isnan(y(j))
            isOther(j) = true;
            continue
        end

        xi = round(x(j));
        yi = round(y(j));

        % Make sure centroid is inside image bounds
        if xi < 1 || xi > size(leftMask,2) || yi < 1 || yi > size(leftMask,1)
            isOther(j) = true;
            continue
        end

        if leftMask(yi, xi)
            isLeft(j) = true;
        elseif rightMask(yi, xi)
            isRight(j) = true;
        else
            isOther(j) = true;
        end
    end

    validFrames = isLeft | isRight | isOther;

    leftPercent  = sum(isLeft)  / sum(validFrames) * 100;
    rightPercent = sum(isRight) / sum(validFrames) * 100;
    otherPercent = sum(isOther) / sum(validFrames) * 100;

    fprintf('Left chamber: %.2f%%\n', leftPercent);
    fprintf('Right chamber: %.2f%%\n', rightPercent);
    fprintf('Other/center/outside: %.2f%%\n', otherPercent);
    %% Save results
    save(fullfile(path, [baseName '_trackingResults.mat']), ...
        'trackX', 'trackY', 'xPos', 'yPos', ...
        'isLeft', 'isRight', 'isOther', ...
        'leftPercent', 'rightPercent', 'otherPercent');
end
%% Manual adjustment of the percentage, if the tracking gives many errors (due to lack of background subtraction; not necessary)
% Manually update CPP percentages
clear;
[fileName, filePath] = uigetfile('*.mat', ...
    'Select tracking results .mat file');

if isequal(fileName,0)
    disp('No file selected');
    return
end

matFile = fullfile(filePath, fileName);

% Load tracking data
S = load(matFile);

% Show current values if they exist
if isfield(S, 'leftPercent')
    currentLeft = S.leftPercent;
else
    currentLeft = NaN;
end

if isfield(S, 'rightPercent')
    currentRight = S.rightPercent;
else
    currentRight = NaN;
end

if isfield(S, 'otherPercent')
    currentOther = S.otherPercent;
else
    currentOther = NaN;
end

fprintf('\nCurrent values:\n');
fprintf('Left:  %.2f%%\n', currentLeft);
fprintf('Right: %.2f%%\n', currentRight);
fprintf('Other: %.2f%%\n', currentOther);

% Ask for manual values
prompt = { ...
    'Manual LEFT chamber percentage:', ...
    'Manual RIGHT chamber percentage:', ...
    'Manual OTHER/CENTER percentage:'};

dlgtitle = 'Update CPP percentages';
dims = [1 50];

definput = { ...
    num2str(currentLeft), ...
    num2str(currentRight), ...
    num2str(currentOther)};

answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    disp('Manual update cancelled');
    return
end

manualLeftPercent  = str2double(answer{1});
manualRightPercent = str2double(answer{2});
manualOtherPercent = str2double(answer{3});

if any(isnan([manualLeftPercent, manualRightPercent, manualOtherPercent]))
    error('Invalid input. Percentages must be numeric.');
end

%Optional check
totalPercent = manualLeftPercent + manualRightPercent + manualOtherPercent;

if abs(totalPercent - 100) > 1
    warning('Manual percentages sum to %.2f%%, not 100%%.', totalPercent);
end

% Add manual values to loaded structure
S.manualLeftPercent = manualLeftPercent;
S.manualRightPercent = manualRightPercent;
S.manualOtherPercent = manualOtherPercent;

S.manualTotalPercent = totalPercent;
S.manualUpdateDate = datetime('now');

% Save as updated file
[~, baseName, ~] = fileparts(fileName);

updatedFile = fullfile(filePath, [baseName '_updated.mat']);

save(updatedFile, '-struct', 'S');

fprintf('\nSaved updated file:\n%s\n', updatedFile);

%% After all tracking, plot the concatenated results
% Concatenate CPP tracking results across mice and days

[files, path] = uigetfile( ...
    '\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\Behavior\CPP\*_trackingResults*.mat', ...
    'Select CPP tracking result files', ...
    'MultiSelect', 'on');

if isequal(files,0)
    disp('No files selected');
    return
end

if ischar(files)
    files = {files};
end

%Initialize struct
cppResults = struct([]);

for fileIdx = 1:numel(files)

    fileName = files{fileIdx};
    filePath = fullfile(path, fileName);

    S = load(filePath);

    [~, baseName, ~] = fileparts(fileName);

    % Parse filename
    % Example:
    % D2_M3_habituation_mjpeg_trackingResults.mat

    tokens = regexp(baseName, ...
        'D(\d+)_M(\d+)_(.*?)(?:_mjpeg)?_trackingResults', ...
        'tokens');

    if isempty(tokens)
        warning('Could not parse filename: %s', fileName);
        continue
    end

    tokens = tokens{1};

    dayNum = str2double(tokens{1});
    mouseNum = str2double(tokens{2});
    trialName = tokens{3};

    %Use manual values if available
    if isfield(S, 'manualLeftPercent')
        leftPct = S.manualLeftPercent;
    else
        leftPct = S.leftPercent;
    end

    if isfield(S, 'manualRightPercent')
        rightPct = S.manualRightPercent;
    else
        rightPct = S.rightPercent;
    end

    if isfield(S, 'manualOtherPercent')
        otherPct = S.manualOtherPercent;
    else
        otherPct = S.otherPercent;
    end

    % Preference index
    % Positive = more right chamber
    % Negative = more left chamber
    preferenceIndex = (rightPct - leftPct) / (rightPct + leftPct);

    %Store in struct
    cppResults(fileIdx).fileName = fileName;
    cppResults(fileIdx).baseName = baseName;
    cppResults(fileIdx).day = dayNum;
    cppResults(fileIdx).mouse = mouseNum;
    cppResults(fileIdx).trialName = trialName;

    cppResults(fileIdx).leftPercent = leftPct;
    cppResults(fileIdx).rightPercent = rightPct;
    cppResults(fileIdx).otherPercent = otherPct;
    cppResults(fileIdx).preferenceIndex = preferenceIndex;

    cppResults(fileIdx).rawData = S;
end

% Remove empty entries if any filenames failed parsing
cppResults = cppResults(~arrayfun(@isempty, {cppResults.fileName}));

% Convert to table for easier plotting/statistics
cppTable = struct2table(cppResults);

disp(cppTable(:, {'fileName','day','mouse','trialName', ...
    'leftPercent','rightPercent','otherPercent','preferenceIndex'}));

% % Save concatenated result
% save(fullfile(path, 'CPP_concatenated_results.mat'), ...
%     'cppResults', 'cppTable');
% 
% writetable(cppTable, fullfile(path, 'CPP_concatenated_summary.csv'));

%% Plot Right Chamber Percentage across days

metricName = 'rightPercent';
yLabelText = 'Right chamber time (%)';

days = unique(cppTable.day);
mice = unique(cppTable.mouse);

nDays = numel(days);
nMice = numel(mice);

summaryplot = figure;
hold on

% Bar graph: mean for each day
meanVals = NaN(nDays,1);
semVals = NaN(nDays,1);
barColors = repmat([0.8 0.8 0.8], nDays, 1);
cppGreen = [0.2 0.7 0.2];
for d = 1:nDays
    thisDay = days(d);
    dayRows = cppTable.day == thisDay;

    vals = cppTable.(metricName)(cppTable.day == thisDay);

    meanVals(d) = mean(vals, 'omitnan');
    semVals(d) = std(vals, 'omitnan') / sqrt(sum(~isnan(vals)));
    trialNamesThisDay = unique(string(cppTable.trialName(dayRows)));
    if any(strcmpi(trialNamesThisDay, "CPP"))
        barColors(d,:) = cppGreen;
    end
end

b = bar(days, meanVals);
b.FaceColor = 'flat';
b.CData = barColors;
b.EdgeColor = 'k';

errorbar(days, meanVals, semVals, ...
    'k.', ...
    'LineWidth', 1.5);

% Scatter + connect same mouse across days
%color choice
%mouseColors = parula(nMice);
mouseHex = { ...
    '#ff595e', ... % red
    '#ffca3a', ... % yellow
    '#89cf18', ... % green
    '#1982c4', ... % blue
    '#6a4c93'};    % purple

mouseColors = zeros(numel(mouseHex),3);

for c = 1:numel(mouseHex)
    mouseColors(c,:) = sscanf(mouseHex{c}(2:end), '%2x%2x%2x', [1 3]) / 255;
end
%
legendHandles = gobjects(nMice,1);
legendLabels = strings(nMice,1);

for m = 1:nMice

    thisMouse = mice(m);

    mouseRows = cppTable.mouse == thisMouse;

    mouseDays = cppTable.day(mouseRows);
    mouseVals = cppTable.(metricName)(mouseRows);

    % Sort by day
    [mouseDays, sortIdx] = sort(mouseDays);
    mouseVals = mouseVals(sortIdx);

    plot(mouseDays, mouseVals, '--', ...
        'Color', mouseColors(m,:), ...
        'LineWidth', 1,'HandleVisibility','off');

    legendHandles(m) = scatter(mouseDays, mouseVals, ...
        60, ...
        mouseColors(m,:), ...
        'filled','MarkerFaceAlpha', 0.6);
    legendLabels(m) = sprintf('Mouse %d', thisMouse);
end

xlabel('Day')
ylabel(yLabelText)
legend(legendHandles, legendLabels, ...
    'Location', 'bestoutside');
title('CPP chamber preference across days')

xticks(days)
ylim([0 100])

box off

%Save

pdfName = fullfile(path, 'Concatenated_scatterplots_habituation.pdf');
exportgraphics(summaryplot, pdfName, ...
    'ContentType', 'image', ...
    'Resolution', 300);
%% Extract Stimulation Side
% Assign stimulation chamber for each mouse

mice = unique(cppTable.mouse);

stimSideByMouse = strings(numel(mice),1);

for m = 1:numel(mice)

    thisMouse = mice(m);

    choice = questdlg( ...
        sprintf('Which chamber was stimulated for Mouse %d?', thisMouse), ...
        'Assign stimulation chamber', ...
        'LeftChamber', ...
        'RightChamber', ...
        'LeftChamber');

    if isempty(choice)
        error('Stimulation chamber assignment cancelled.');
    end

    stimSideByMouse(m) = string(choice);
end
% Add stimulation side and stimulation-side percentage to table

cppTable.stimSide = strings(height(cppTable),1);
cppTable.stimPercent = NaN(height(cppTable),1);

for rowIdx = 1:height(cppTable)

    thisMouse = cppTable.mouse(rowIdx);

    mouseIdx = find(mice == thisMouse, 1);

    thisStimSide = stimSideByMouse(mouseIdx);

    cppTable.stimSide(rowIdx) = thisStimSide;

    if thisStimSide == "LeftChamber"
        cppTable.stimPercent(rowIdx) = cppTable.leftPercent(rowIdx);
    elseif thisStimSide == "RightChamber"
        cppTable.stimPercent(rowIdx) = cppTable.rightPercent(rowIdx);
    end
end

%% Plot stimulation chamber percentage across days

metricName = 'stimPercent';
yLabelText = 'Time in stimulation-paired chamber (%)';

days = unique(cppTable.day);
mice = unique(cppTable.mouse);

nDays = numel(days);
nMice = numel(mice);

figure
hold on

% Mean bar for each day
meanVals = NaN(nDays,1);
semVals = NaN(nDays,1);
barColors = repmat([0.8 0.8 0.8], nDays, 1);

cppGreen = [0.2 0.7 0.2];

for d = 1:nDays

    thisDay = days(d);
    dayRows = cppTable.day == thisDay;

    vals = cppTable.(metricName)(dayRows);

    meanVals(d) = mean(vals, 'omitnan');
    semVals(d) = std(vals, 'omitnan') / sqrt(sum(~isnan(vals)));

    trialNamesThisDay = unique(string(cppTable.trialName(dayRows)));

    if any(contains(trialNamesThisDay, "CPP", 'IgnoreCase', true))
        barColors(d,:) = cppGreen;
    end
end

b = bar(days, meanVals);
b.FaceColor = 'flat';
b.CData = barColors;
b.EdgeColor = 'k';

errorbar(days, meanVals, semVals, ...
    'k.', ...
    'LineWidth', 1.5);

% Custom mouse colors
mouseHex = { ...
    '#ff595e', ...
    '#ffca3a', ...
    '#89cf18', ...
    '#1982c4', ...
    '#6a4c93'};

mouseColors = zeros(numel(mouseHex),3);

for c = 1:numel(mouseHex)
    mouseColors(c,:) = sscanf(mouseHex{c}(2:end), '%2x%2x%2x', [1 3]) / 255;
end

legendHandles = gobjects(nMice,1);
legendLabels = strings(nMice,1);

for m = 1:nMice

    thisMouse = mice(m);

    colorIdx = mod(m-1, size(mouseColors,1)) + 1;
    thisColor = mouseColors(colorIdx,:);

    mouseRows = cppTable.mouse == thisMouse;

    mouseDays = cppTable.day(mouseRows);
    mouseVals = cppTable.(metricName)(mouseRows);

    [mouseDays, sortIdx] = sort(mouseDays);
    mouseVals = mouseVals(sortIdx);

    plot(mouseDays, mouseVals, '--', ...
        'Color', thisColor, ...
        'LineWidth', 1, ...
        'HandleVisibility','off');

    legendHandles(m) = scatter(mouseDays, mouseVals, ...
        60, ...
        thisColor, ...
        'filled', ...
        'MarkerFaceAlpha', 0.6);

    legendLabels(m) = sprintf('M%d', thisMouse);
end

xlabel('Day')
ylabel(yLabelText)
title('CPP: time in stimulation-paired chamber')

xticks(days)
ylim([0 100])

legend(legendHandles, legendLabels, ...
    'Location', 'bestoutside');

box off
%% Plot percentage change
mice = unique(cppTable.mouse);

deltaStim = NaN(numel(mice),1);
cppStim = NaN(numel(mice),1);
lastHabStim = NaN(numel(mice),1);
lastHabDay = NaN(numel(mice),1);
meanHabStim = NaN(numel(mice),1);

for m = 1:numel(mice)

    thisMouse = mice(m);

    mouseRows = cppTable.mouse == thisMouse;

    % Find CPP row for this mouse
    cppRows = mouseRows & contains(string(cppTable.trialName), "CPP", ...
        'IgnoreCase', true);

    if ~any(cppRows)
        warning('No CPP trial found for Mouse %d', thisMouse);
        continue
    end

    % If more than one CPP row exists, use the latest day
    cppDays = cppTable.day(cppRows);
    [~, cppIdxLocal] = max(cppDays);
    cppIdxAll = find(cppRows);
    cppIdx = cppIdxAll(cppIdxLocal);

    cppStim(m) = cppTable.stimPercent(cppIdx);

    % Find habituation rows for this mouse
    habRows = mouseRows & contains(string(cppTable.trialName), "habituation", ...
        'IgnoreCase', true);

    if ~any(habRows)
        warning('No habituation trial found for Mouse %d', thisMouse);
        continue
    end

    % Use the last habituation day
    habDays = cppTable.day(habRows);
    [lastHabDay(m), habIdxLocal] = max(habDays);
    habIdxAll = find(habRows);
    habIdx = habIdxAll(habIdxLocal);
    lastHabStim(m) = cppTable.stimPercent(habIdx);

    meanHabStim(m) = mean(cppTable.stimPercent(habRows), 'omitnan');

    % CPP minus last habituation
    deltaStim(m) = cppStim(m) - lastHabStim(m);
    %deltaStim(m) = cppStim(m) - meanHabStim(m);
end

% Store as table
deltaTable = table( ...
    mice, ...
    meanHabStim,...
    lastHabDay, ...
    lastHabStim, ...
    cppStim, ...
    deltaStim, ...
    'VariableNames', {'Mouse','MeanHabStimPercent','LastHabDay','LastHabStimPercent','CPPStimPercent','DeltaStimPercent'});

disp(deltaTable)
%% Plot CPP - last habituation
validIdx = ~isnan(deltaStim);

deltaValid = deltaStim(validIdx);
miceValid = mice(validIdx);

meanDelta = mean(deltaValid, 'omitnan');
semDelta = std(deltaValid, 'omitnan') / sqrt(sum(~isnan(deltaValid)));

figure
hold on

% One group bar
bar(1, meanDelta, ...
    'FaceColor', [0.8 0.8 0.8], ...
    'EdgeColor', 'k', ...
    'LineWidth', 1.2);

% SEM error bar
errorbar(1, meanDelta, semDelta, ...
    'k.', ...
    'LineWidth', 1.5, ...
    'CapSize', 15);

% Mouse colors
mouseHex = { ...
    '#ff595e', ...
    '#ffca3a', ...
    '#89cf18', ...
    '#1982c4', ...
    '#6a4c93'};

mouseColors = zeros(numel(mouseHex),3);

for c = 1:numel(mouseHex)
    mouseColors(c,:) = sscanf(mouseHex{c}(2:end), '%2x%2x%2x', [1 3]) / 255;
end

% Overlay individual mice with slight horizontal jitter
rng(1)  % reproducible jitter
jitterAmount = 0.08;

for m = 1:numel(miceValid)

    colorIdx = mod(m-1, size(mouseColors,1)) + 1;
    xJitter = 1 + (rand - 0.5) * 2 * jitterAmount;

    scatter(xJitter, deltaValid(m), ...
        80, ...
        mouseColors(colorIdx,:), ...
        'filled', ...
        'MarkerEdgeColor', 'k', ...
        'MarkerFaceAlpha', 0.7);
end

yline(0, 'k--');

xlim([0.4 1.6])
xticks(1)
xticklabels({'CPP - last habituation'})

ylabel('Change in stim-side time (%)')
title('Stimulation-side preference change')

box off