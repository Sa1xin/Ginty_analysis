%% Run the code by section
close all
clearvars -except path

[fileNames, pathName] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\resultsForSally_26.1.20\*.csv', 'Select CSV files', 'MultiSelect', 'on');
addpath(genpath("\\research.files.med.harvard.edu\neurobio\GintyLab\Qi\code\current_matlab\calcium"));
datatable = struct([]);

% Loop through each selected file and read it
for i = 1:length(fileNames)
    fullFileName = fullfile(pathName, fileNames{i});
    stimuli = fileNames{i};
    cur_data = readtable(fullFileName);      % or csvread/fullfile depending on format
    datatable(i).name = stimuli;
    datatable(i).Oridata = cur_data(:,startsWith(cur_data.Properties.VariableNames, 'Mean'));
    if ~contains(stimuli,'pinch')   %Make sure the pinch filename contains pinch and others dont
        datatable(i).framerate = 5; %Hz CHANGE FOR DIFFERENT SETTING
        fps = 5;
    else
        datatable(i).framerate = 10;
        fps = 10;
    end
    normDeltaF = initialProcess(pathName, fileNames{i}, fps);%, 'bleach correction', 6, 0.975); SKIPPING bleach correction
    NewnormDeltaF = normDeltaF(:,:) - mean(normDeltaF(1:100,:)); %baseline fixed to be 100 frames
    datatable(i).dataABC = NewnormDeltaF(:,:);%,27:end); %REMOVE SOME DUPLICATES
end
%% You may want to close the figures before next section
close all
%% Sort responses by stimuli and plot heatmaps and grouped duration plots
Sorting_stim = [3,4]; %first sort with stim 2, then stim 3  YOU MAY WANT TO CHANGE THIS!

nstd = 5; % Set for defining response thresholds
duration_threshold = 5; %in sec, for plotting response duration difference
all_data = vertcat(datatable(:).dataABC);

numStim = numel(datatable);
numCells =  size(datatable(1).dataABC, 2);  
response_duration = zeros(numCells, numStim);
%response_duration_mean = zeros(numCells, numStim);%Put the duration and mean response into consideration
for i = 1:numStim
    stim_lengths(i) = size(datatable(i).dataABC, 1);  % time length of each
    eachstim_data = datatable(i).dataABC;
    baseline_std = std(eachstim_data(1:100, :), 0, 1); %The first 100 frames are the baseline
    baseline_mean = mean(eachstim_data(1:100,:), 1); 
    stim_mean = mean(eachstim_data(101:end,:),1);
    isAbove = eachstim_data(101:end,:) >= (baseline_mean + nstd*baseline_std);%isAbove = eachstim_data >= (mean(datatable(i).dataABC', 2)'+nstd*std(datatable(i).dataABC(1:100,:)', [], 2)');%threshold;
    response_duration(:, i) = sum(isAbove, 1)'/datatable(i).framerate .* stim_mean';
    %response_duration_mean(:,i) = sum(isAbove, 1)'/datatable(i).framerate .* stim_mean';
end

resp2 = response_duration(:,Sorting_stim(1));
resp3 = response_duration(:,Sorting_stim(2));

% resp2 = max(datatable(Sorting_stim(1)).dataABC', [], 2);
% resp3 = max(datatable(Sorting_stim(2)).dataABC', [], 2);

% %Split into two groups
% idx_high = find(resp2 >= resp3);  % threshold);  % High responders to stimulus 2
% idx_low = find(resp2 < resp3);    % Low responders to stimulus 2

% Split into three groups

idx_high = find(resp2 >= resp3);
idx_low = find(resp2 < resp3);

%Sort high group by stim 2 (descending)
[~, subIdx_high] = sort(resp2(idx_high), 'descend');
sorted_high = idx_high(subIdx_high);

%Sort low group by stim 3 (descending)
[~, subIdx_low] = sort(resp3(idx_low), 'descend');
sorted_low = idx_low(subIdx_low);

%Concatenate final sort order
sortIdx = [sorted_high; sorted_low];  % Combined index list

sorted_data = all_data(:,sortIdx);

Max_sorted = sort(max(sorted_data));

stim_boundaries = cumsum(stim_lengths);
stim_boundaries_2 = cumsum(stim_lengths)+100;

if size(sorted_data,2)>4
    MaxLimit = mean(Max_sorted(end-4:end));
else
    MaxLimit = max(Max_sorted);
end

if MaxLimit > 2 || MaxLimit < 0.2
    Limit = 2;
else
    Limit = MaxLimit;
end

% Plot heatmap of all stimuli sorted by stim 2 and stim 3
close all
fig1 = figure('Name','dF/F Heatmap','NumberTitle', 'off');
set(fig1, 'Units', 'pixels', 'Position', [100, 100, 1600, 800]);
nCells = size(sorted_data, 2);
nTime = size(sorted_data, 1);
imagesc(1:nTime, 1:nCells, sorted_data'); % rows = cells, columns = timepoints
colormap turbo;
colorbar;
caxis([0 Limit]);

%xticks(timelength/2 + (0:numStim-1)*timelength);
xticks(stim_lengths/2 + [0 cumsum(stim_lengths(1:end-1))]);
%labels = {datatable.name};
%labels = arrayfun(@(x) extractBetween(x.name, 'm1648_', '_new'), datatable);
labels = {datatable.name};
labels_new = erase(labels, '.csv');
xticklabels(string(labels_new));
yticks(5:5:nCells);
xlabel('Timepoints');
ylabel('Cell');
title('ΔF/F Heatmap');
axis tight;

hold on;

%label the onset of the video and the stimuli
for i = 1:numStim-1
    %xline(i * timelength + 0.5, 'w--', 'LineWidth', 1.2);              
    xline(stim_boundaries(i), 'w--', 'LineWidth', 1.2);
    xline(stim_boundaries_2(i), 'r--', 'LineWidth', 1.2);
end
xline(100, 'r--','LineWidth', 1.2);

hold off;

% plot response duration
stim2 = response_duration(:, Sorting_stim(1));
stim3 = response_duration(:, Sorting_stim(2));
subgroup_mask = stim2 > duration_threshold | stim3 > duration_threshold; %find the cells responding to either stim2 or stim3
subgroup_idx = find(subgroup_mask);

group1_idx = subgroup_idx(stim2(subgroup_idx) > stim3(subgroup_idx));
group2_idx = subgroup_idx(stim2(subgroup_idx) <= stim3(subgroup_idx));

group1_data = response_duration(group1_idx, Sorting_stim);  % rows = cells
group2_data = response_duration(group2_idx, Sorting_stim);

xlabels = {datatable(Sorting_stim).name};
xlabels = erase(xlabels, '.csv');

fig2 = figure('Name','Barplot','NumberTitle', 'off');
set(fig2, 'Units', 'pixels', 'Position', [100, 100, 800, 1200]);
subplot(1,2,1);
hold on;
x = [1, 2];
for i = 1:size(group1_data, 1)
    plot(x, group1_data(i, :), 'o:', 'Color', [0.9 0.6 0.6],'MarkerFaceColor', [0.6 0.6 0.6]);
end
% Plot mean as bar
bar(x, mean(group1_data, 1), 'FaceColor', [0.9,0,0.1],'FaceAlpha', 0.3, 'EdgeColor', 'none');
title(sprintf('Group 1 (%s resp dur > 1), n=%d', xlabels{1}, size(group1_data,1)));
ylabel('Response (Duration*Mean)');
xticks(x);
xticklabels(xlabels);
ylim([0, max(response_duration(:)) + 2]);

subplot(1,2,2);
hold on;
for i = 1:size(group2_data, 1)
    plot(x, group2_data(i, :), 'o:', 'Color', [0.6 0.9 0.6],'MarkerFaceColor', [0.6 0.6 0.6]);
end
bar(x, mean(group2_data, 1), 'FaceColor', [0.1,0.9,0],'FaceAlpha', 0.5, 'EdgeColor', 'none');
title(sprintf('Group 2 (%s resp dur ≤ 1), n=%d', xlabels{1}, size(group2_data,1)));
xticks(x);
xticklabels(xlabels);
ylim([0, max(response_duration(:)) + 2]);

%plot heatmap of capsaicin and AITC only
both_mask = stim2 > duration_threshold & stim3 > duration_threshold;
subgroup_mask = stim2 > duration_threshold | stim3 > duration_threshold;
single_mask = subgroup_mask & ~both_mask;

both_idx   = find(both_mask);
single_idx = find(single_mask);

group1_idx = single_idx(stim2(single_idx) > stim3(single_idx));
group2_idx = single_idx(stim2(single_idx) <= stim3(single_idx));


[~, g1_sort] = sort(stim2(group1_idx), 'descend');
[~, g2_sort] = sort(stim3(group2_idx), 'descend');
sorted_g1_idx = group1_idx(g1_sort);
sorted_g2_idx = group2_idx(g2_sort);
final_sorted_idx = [sorted_g1_idx; sorted_g2_idx; both_idx];
final_sorted_data = [];
for i = 1:numel(Sorting_stim)
    final_sorted_data = [final_sorted_data; datatable(Sorting_stim(i)).dataABC(:, final_sorted_idx)];
end
fig3 = figure('Name','dF/F Heatmap of chemicals only','NumberTitle', 'off');
set(fig3, 'Units', 'pixels', 'Position', [100, 100, 1600, 800]);
nCells = size(final_sorted_data, 2);
nTime = size(final_sorted_data, 1);
imagesc(1:nTime, 1:nCells, final_sorted_data'); % rows = cells, columns = timepoints
colormap turbo;
colorbar;
caxis([0 Limit]);

%xticks(timelength/2 + (0:numStim-1)*timelength);
xticks(stim_lengths(Sorting_stim)/2 + [0 cumsum(stim_lengths(Sorting_stim(1:end-1)))]);
%labels = {datatable.name};
%labels = arrayfun(@(x) extractBetween(x.name, 'm1648_', '_new'), datatable);
xticklabels(xlabels);
yticks(1:5:nCells);
xlabel('Timepoints');
ylabel('Cell');
title('ΔF/F Heatmap');
axis tight;
hold on;
stim_boundaries = cumsum(stim_lengths(Sorting_stim));
stim_boundaries_2 = cumsum(stim_lengths(Sorting_stim)) +100;
for i = 1:numel(Sorting_stim)-1
    %xline(i * timelength + 0.5, 'w--', 'LineWidth', 1.2);
    xline(stim_boundaries(i), 'w--', 'LineWidth', 1.2);
    xline(stim_boundaries_2(i), 'r--', 'LineWidth', 1.2);
end
xline(100, 'r--','LineWidth', 1.2);

hold off;
%% Save figures and matlab files
heatmap_name = 'Heatmap Plot of cell responses.pdf';
bargraph_name = 'Response duration comparison.pdf';
filtered_heatmap_name = 'Heatmap Plot of cell responding to chemicals.pdf';
heatmap_path = fullfile(pathName,heatmap_name);
bargraph_path = fullfile(pathName,bargraph_name);
filtered_heatmap_path = fullfile(pathName,filtered_heatmap_name);
exportgraphics(fig1, heatmap_path, 'ContentType', 'vector');
exportgraphics(fig2, bargraph_path, 'ContentType', 'vector');
exportgraphics(fig3, filtered_heatmap_path, 'ContentType', 'vector');

extractedname = extractBetween(pathName, '1.20\', 'results');
if contains(extractedname,'\')
    extractedname = replace(extractedname,'\','_');
end

%define stimuli names for future concatenation
name2 = datatable(Sorting_stim(1)).name;
name3 = datatable(Sorting_stim(2)).name;


if contains(name2, 'cap') && contains(name3, 'AITC')
    resp2_name = 'capsaicin';
    resp3_name = 'AITC';
elseif contains(name2, 'AITC') && contains(name3, 'cap')
    resp2_name = 'AITC';
    resp3_name = 'capsaicin';
else
    %warning('Problem with datatable names: expected one capsaicin and one AITC.');
    disp([name2,name3]);
    resp2_name = 'stim2'; %you can manually set the name here if the filename is slightly off
    resp3_name = 'stim3';
end

filename_output = strcat(extractedname, name2,'_datatable.mat');
filename_output = filename_output{1};

sortedfilename_output = strcat(extractedname, name2,'_final_sorted_data.mat');
sortedfilename_output = sortedfilename_output{1};

save(fullfile(pathName, filename_output), 'datatable');
save(fullfile(pathName, sortedfilename_output), 'final_sorted_data')

%for response duration only to capsaicin and/or AITC


clear resp_dur_output;
resp_dur_output = struct([]);
resp_dur_output(1).preferredstim = resp2_name;
resp_dur_output(2).preferredstim = resp3_name;

group1_table = array2table(group1_data, 'VariableNames', {resp2_name, resp3_name});
group2_table = array2table(group2_data, 'VariableNames', {resp2_name, resp3_name});
resp_dur_output(1).response = group1_table;
resp_dur_output(2).response = group2_table;

resp_dur_output_filename = strcat(extractedname, '_resp_dur_output.mat');
resp_dur_output_filename = resp_dur_output_filename{1};
save(fullfile(pathName, resp_dur_output_filename), 'resp_dur_output')

%% After having multiple files analyzed using codes above, concatenate the output files
clear;
[sorted, sorted_path] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\resultsForSally_26.1.20\*final_sorted_data*.mat', 'Select one or more MAT files', 'MultiSelect', 'on');
[dur_files, dur_path] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\resultsForSally_26.1.20\*resp_dur_output*.mat', 'Select one or more MAT files', 'MultiSelect', 'on');
[data_files, data_path] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\resultsForSally_26.1.20\*datatable*.mat', 'Select one or more MAT files', 'MultiSelect', 'on');

sorted_all = [];
dur_all = [];
data_all = [];
data_all_concatenated = [];
for k = 1:length(sorted)
    filePath_sorted = fullfile(sorted_path, sorted{k});
    loadedSorted = load(filePath_sorted, 'final_sorted_data'); 
    currentSorted = loadedSorted.final_sorted_data;
    sorted_all = [sorted_all, currentSorted];
end

for j = 1:length(dur_files)
    filePath_dur = fullfile(dur_path, dur_files{j});
    loadedDur = load(filePath_dur, 'resp_dur_output'); 
    currentDur = loadedDur.resp_dur_output;
    dur_all = [dur_all, currentDur];
end

for i = 1:length(data_files)
    filePath_data = fullfile(data_path, data_files{i});
    loadedData = load(filePath_data, 'datatable'); 
    currentdata = loadedData.datatable;
    data_all = [data_all, currentdata];
end

%Sort again
% 
% Sorting_stim = [3 4];     % cap/AITC indices (or whatever your two are)
% baselineFrames = 100;
% nstd = 5;
% metricMode = "durXmean";  % "dur" or "durXmean"
% 
% % --- load all datatables into a cell array
% D = cell(numel(data_files),1);
% for i = 1:numel(data_files)
%     S = load(fullfile(data_path, data_files{i}), 'datatable');
%     D{i} = S.datatable;
% end
% 
% % --- determine common length per selected stim (crop to min)
% stimLen = zeros(numel(D), numel(Sorting_stim));
% for e = 1:numel(D)
%     for k = 1:numel(Sorting_stim)
%         stimLen(e,k) = size(D{e}(Sorting_stim(k)).dataABC, 1);
%     end
% end
% commonLen = min(stimLen, [], 1);   % [lenStimA lenStimB]
% 
% % --- pool traces + metrics
% pooled_traces = [];     % (sum(commonLen)) x pooledCells
% pooled_resp   = [];     % pooledCells x 2
% pooled_exp_id = [];     % pooledCells x 1
% pooled_cell_id= [];     % pooledCells x 1
% 
% for e = 1:numel(D)
%     datatable = D{e};
%     nCells = size(datatable(1).dataABC, 2);
% 
%     exp_concat = [];
%     exp_resp = zeros(nCells, numel(Sorting_stim));
% 
%     for k = 1:numel(Sorting_stim)
%         si = Sorting_stim(k);
%         X = datatable(si).dataABC;
%         X = X(1:commonLen(k), :);  % crop
%         fr = datatable(si).framerate;
% 
%         baseEnd = min(baselineFrames, size(X,1));
%         stimStart = baseEnd + 1;
% 
%         base = X(1:baseEnd, :);
%         stim = X(stimStart:end, :);
% 
%         bmu = mean(base, 1);
%         bsd = std(base, 0, 1);
%         smu = mean(stim, 1);
% 
%         thresh = bmu + nstd .* bsd;
%         isAboveStim = stim >= thresh;
%         durSec = sum(isAboveStim, 1)' / fr;
% 
%         switch metricMode
%             case "dur"
%                 exp_resp(:,k) = durSec;
%             case "durXmean"
%                 exp_resp(:,k) = durSec .* smu';
%         end
% 
%         % baseline subtract for pooled visualization
%         X = X - bmu;
% 
%         exp_concat = [exp_concat; X]; %#ok<AGROW>
%     end
% 
%     pooled_traces = [pooled_traces, exp_concat]; %#ok<AGROW>
%     pooled_resp   = [pooled_resp; exp_resp];     %#ok<AGROW>
%     pooled_exp_id = [pooled_exp_id; e*ones(nCells,1)]; %#ok<AGROW>
%     pooled_cell_id= [pooled_cell_id; (1:nCells)']; %#ok<AGROW>
% end
% 
% resp2 = pooled_resp(:,1);
% resp3 = pooled_resp(:,2);
% 
% idx_high = find(resp2 >= resp3);
% idx_low  = find(resp2 <  resp3);
% 
% [~, subIdx_high] = sort(resp2(idx_high), 'descend');
% sorted_high = idx_high(subIdx_high);
% 
% [~, subIdx_low]  = sort(resp3(idx_low), 'descend');
% sorted_low = idx_low(subIdx_low);
% 
% sortIdx = [sorted_high; sorted_low];
% sorted_pooled_traces = pooled_traces(:, sortIdx);
% sorted_pooled_resp   = pooled_resp(sortIdx, :);
% 
% figure('Name','POOLED Heatmap','NumberTitle','off','Position',[100 100 1600 800]);
% imagesc(sorted_pooled_traces');  % cells x time
% colormap turbo; colorbar;
% 
% xlabel('Timepoints'); ylabel('Pooled cells');
% title(sprintf('Pooled cells=%d | metric=%s', size(sorted_pooled_traces,2), metricMode));
% 
% stim_boundaries = cumsum(commonLen);
% xticks(commonLen/2 + [0 cumsum(commonLen(1:end-1))]);
% 
% % label from first experiment
% labels = {D{1}(Sorting_stim).name};
% labels = erase(labels, '.csv');
% xticklabels(labels);
% 
% hold on;
% for k = 1:numel(commonLen)-1
%     xline(stim_boundaries(k), 'w--', 'LineWidth', 1.2);
% end
% hold off;
%% Combined heatmap sorting based on 3,4
Sorting_stim = [3 4];     % the two used for sorting
Plot_stim    = 1:5;       % the ones you want to display in the heatmap

baselineFrames = 100;
nstd = 5;
metricMode = "durXmean";  % "dur" or "durXmean"

% --- Load datatables from your selected files (your existing picker)
% data_files, data_path already exist from uigetfile part
if ~iscell(data_files); data_files = {data_files}; end

D = cell(numel(data_files),1);
for e = 1:numel(data_files)
    S = load(fullfile(data_path, data_files{e}), 'datatable');
    D{e} = S.datatable;
end

% 1) Determine common length
stimLenPlot = zeros(numel(D), numel(Plot_stim));
for e = 1:numel(D)
    for k = 1:numel(Plot_stim)
        si = Plot_stim(k);
        stimLenPlot(e,k) = size(D{e}(si).dataABC, 1);
    end
end
commonLenPlot = min(stimLenPlot, [], 1);   % 1 x 5 (for plot stims)

% 2) Compute pooled response metric ONLY for Sorting_stim (3–4), and pool traces for ALL stims (1–5)
pooled_resp = [];        % pooledCells x 2 (sorting metric)
pooled_traces_all = [];  % totalTime(=sum(commonLenPlot)) x pooledCells
pooled_exp_id = [];
pooled_cell_id = [];

for e = 1:numel(D)
    datatable = D{e};
    nCells = size(datatable(1).dataABC, 2);

    % ---- A) build the "display" trace: concatenate stim 1–5 (cropped)
    exp_concat_all = [];
    for k = 1:numel(Plot_stim)
        si = Plot_stim(k);
        X = datatable(si).dataABC;
        X = X(1:commonLenPlot(k), :);  % crop to common length

        % baseline subtract (per stim) for nicer pooled visualization
        baseEnd = min(baselineFrames, size(X,1));
        bmu = mean(X(1:baseEnd,:), 1);
        X = X - bmu;

        exp_concat_all = [exp_concat_all; X]; %#ok<AGROW>
    end

    % ---- B) compute sorting metric for stim 3 and stim 4 only
    exp_resp = zeros(nCells, numel(Sorting_stim));
    for k = 1:numel(Sorting_stim)
        si = Sorting_stim(k);

        % IMPORTANT: use same crop length as in plot IF si is among Plot_stim
        % so metrics and display align. If you prefer full length, change this.
        plotIndex = find(Plot_stim == si, 1);
        if isempty(plotIndex)
            X = datatable(si).dataABC;
        else
            X = datatable(si).dataABC(1:commonLenPlot(plotIndex), :);
        end

        fr = datatable(si).framerate;

        baseEnd = min(baselineFrames, size(X,1));
        stimStart = baseEnd + 1;
        if stimStart > size(X,1)
            error("Stim trace too short after cropping (exp %d, stim %d).", e, si);
        end

        base = X(1:baseEnd,:);
        stim = X(stimStart:end,:);

        bmu = mean(base, 1);
        bsd = std(base, 0, 1);
        smu = mean(stim, 1);

        thresh = bmu + nstd .* bsd;
        isAboveStim = stim >= thresh;
        durSec = sum(isAboveStim, 1)' / fr;

        switch metricMode
            case "dur"
                exp_resp(:,k) = durSec;
            case "durXmean"
                exp_resp(:,k) = durSec .* smu';
        end
    end

    % ---- append pooled
    pooled_traces_all = [pooled_traces_all, exp_concat_all]; %#ok<AGROW>
    pooled_resp = [pooled_resp; exp_resp]; %#ok<AGROW>
    pooled_exp_id = [pooled_exp_id; e*ones(nCells,1)]; %#ok<AGROW>
    pooled_cell_id = [pooled_cell_id; (1:nCells)']; %#ok<AGROW>
end

% 3) Global sort using pooled_resp(:,1) vs pooled_resp(:,2)
resp2 = pooled_resp(:,1);
resp3 = pooled_resp(:,2);

idx_high = find(resp2 >= resp3);
idx_low  = find(resp2 <  resp3);

[~, subIdx_high] = sort(resp2(idx_high), 'descend');
sorted_high = idx_high(subIdx_high);

[~, subIdx_low]  = sort(resp3(idx_low), 'descend');
sorted_low = idx_low(subIdx_low);

sortIdx = [sorted_high; sorted_low];

sorted_traces_all = pooled_traces_all(:, sortIdx);

% 4) Plot pooled heatmap for ALL stimuli 1–5 using the sort from stim3&4
figure('Name','POOLED Heatmap (all stimuli)','NumberTitle','off','Position',[100 100 1600 800]);
imagesc(sorted_traces_all');  % cells x time
colormap turbo; colorbar;caxis([0 2])
xlabel('Timepoints'); ylabel('Pooled cells');
title(sprintf('Sorted by stim %d vs %d, plotted stims %d-%d', Sorting_stim(1), Sorting_stim(2), Plot_stim(1), Plot_stim(end)));

% boundaries + labels
boundaries = cumsum(commonLenPlot);
xticks(commonLenPlot/2 + [0 cumsum(commonLenPlot(1:end-1))]);

labels = {D{1}(Plot_stim).name};
labels = erase(labels, '.csv');
xticklabels(labels);

hold on;
for k = 1:numel(boundaries)-1
    xline(boundaries(k), 'w--', 'LineWidth', 1.2);
end
hold off;

%% Save
pooled_out.sorted_traces_all = sorted_traces_all;
pooled_out.sortIdx = sortIdx;
pooled_out.pooled_resp = pooled_resp;
pooled_out.pooled_exp_id = pooled_exp_id;
pooled_out.pooled_cell_id = pooled_cell_id;
pooled_out.Plot_stim = Plot_stim;
pooled_out.Sorting_stim = Sorting_stim;
pooled_out.commonLenPlot = commonLenPlot;
pooled_out.metricMode = metricMode;

save(fullfile(data_path, 'POOLED_sortedBy34_plotted1to5.mat'), 'pooled_out');