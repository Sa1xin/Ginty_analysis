%% Run the code by section
close all
clearvars -except path

[fileNames, pathName] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\ratResultsForSally_26.3.2\*.csv', 'Select CSV files', 'MultiSelect', 'on');
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

    if i == 1
        baselineFirst = mean(normDeltaF(1:100, :), 1);
    end
    datatable(i).dataABC_first = normDeltaF - baselineFirst;
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


%Filter out cells not responding to either chemical
subgroup_mask = resp2 > duration_threshold | resp3 > duration_threshold;
subgroup_idx = find(subgroup_mask);

idx_high = subgroup_idx(resp2(subgroup_idx) >= resp3(subgroup_idx));
idx_low  = subgroup_idx(resp2(subgroup_idx) <  resp3(subgroup_idx));

% If not apply the chemical filter

% idx_high = find(resp2 >= resp3);
% idx_low = find(resp2 < resp3);

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

%Final plot for selected stim after filtering out non-chemically responsive cells
stimulation_labels = {'Pinch','Saline','AITC','Capsaicin'};
stim_to_plot = [1 2 3 4];
gap_size = 20;   % number of white-gap timepoints between stimuli

selected_data = [];

boundaries = cumsum(stim_lengths);
starts = [1, boundaries(1:end-1) + 1];
ends = boundaries;

block_starts = zeros(1, numel(stim_to_plot));
block_ends   = zeros(1, numel(stim_to_plot));

current = 1;

for i = 1:numel(stim_to_plot)

    si = stim_to_plot(i);

    block = sorted_data(starts(si):ends(si), :);

    block_starts(i) = current;
    block_ends(i)   = current + size(block, 1) - 1;

    selected_data = [selected_data; block];

    current = block_ends(i) + 1;

    if i < numel(stim_to_plot)
        gap = nan(gap_size, size(block, 2));
        selected_data = [selected_data; gap];
        current = current + gap_size;
    end
end
fig_finalselectStim = figure('Name','dF/F Heatmap selected stimuli','NumberTitle', 'off');
set(fig_finalselectStim, 'Units', 'pixels', 'Position', [100, 100, 1600, 800]);

nCells = size(selected_data, 2);
nTime = size(selected_data, 1);

h = imagesc(1:nTime, 1:nCells, selected_data');
colormap turbo;
colorbar;
caxis([0 Limit]);

labels = stimulation_labels(stim_to_plot);


xticks((block_starts + block_ends) / 2);
xticklabels(labels);
yticks(5:5:nCells);
xlabel('Timepoints');
ylabel('Cell');
title(sprintf('ΔF/F Heatmap: selected stims [%s]', num2str(stim_to_plot)));
axis tight;

hold on;

for i = 1:numel(stim_to_plot)

    % Stimulus onset at 100 frames after each block starts
    xline(block_starts(i) + 100 - 1, 'w--', 'LineWidth', 1.2);

    % White line at the end of each stimulus block
    % if i < numel(stim_to_plot)
    %     xline(block_ends(i) + 0.5, 'w--', 'LineWidth', 1.2);
    % end

end

hold off;

set(h, 'AlphaData', ~isnan(selected_data'));
set(gca, 'Color', 'w');

heatmap_name2 = 'Heatmap Plot of cell responses_UpdatedFilterSel.pdf';
heatmap_path2 = fullfile(pathName,heatmap_name2);
exportgraphics(fig_finalselectStim, heatmap_path2, 'ContentType', 'vector');
%% Use the baseline from the first file
Sorting_stim = [3,4]; %first sort with stim 2, then stim 3  YOU MAY WANT TO CHANGE THIS!

nstd = 5; % Set for defining response thresholds
duration_threshold = 5; %in sec, for plotting response duration difference
all_data = vertcat(datatable(:).dataABC_first);
min_consecutive_frames = 25;

numStim = numel(datatable);
numCells =  size(datatable(1).dataABC_first, 2);  
response_duration = zeros(numCells, numStim);
%response_duration_mean = zeros(numCells, numStim);%Put the duration and mean response into consideration

for i = 1:numStim
    stim_lengths(i) = size(datatable(i).dataABC_first, 1);  % time length of each
    eachstim_data = datatable(i).dataABC_first;

    baseline_std = std(eachstim_data(1:100, :), 0, 1); %The first 100 frames are the baseline
    baseline_mean = mean(eachstim_data(1:100,:), 1); 
    stim_mean = mean(eachstim_data(101:end,:),1);

    isAbove = eachstim_data(101:end,:) >= (baseline_mean + nstd*baseline_std);
    response_duration(:, i) = sum(isAbove, 1)'/datatable(i).framerate .* stim_mean';

    %response_duration_mean(:,i) = sum(isAbove, 1)'/datatable(i).framerate .* stim_mean';
end

resp2 = response_duration(:,Sorting_stim(1));
resp3 = response_duration(:,Sorting_stim(2));

%Filter out cells not responding to either chemical
subgroup_mask = resp2 > duration_threshold | resp3 > duration_threshold;
subgroup_idx = find(subgroup_mask);

%Filter out cells not responding to the first pinch stimulus
% stim1_data = datatable(1).dataABC_first;
% base = stim1_data(1:100, :);
% stim = stim1_data(101:end, :);
% 
% baseline_mean = mean(base, 1);
% baseline_std  = std(base, 0, 1);
% 
% thresh = baseline_mean + nstd .* baseline_std;
% isAboveStim1 = stim >= thresh;
% 
% stim1_is_responsive = false(numCells, 1);
% 
% for c = 1:numCells
%     x = isAboveStim1(:, c);
% 
%     d = diff([0; x; 0]);
%     runStarts = find(d == 1);
%     runEnds = find(d == -1) - 1;
%     runLengths = runEnds - runStarts + 1;
% 
%     if ~isempty(runLengths)
%         stim1_is_responsive(c) = max(runLengths) >= min_consecutive_frames;
%     end
% end
% final_mask = subgroup_mask & stim1_is_responsive;
% 
% subgroup_idx = find(final_mask);

% idx_high = find(resp2 >= resp3);
% idx_low = find(resp2 < resp3);
idx_high = subgroup_idx(resp2(subgroup_idx) >= resp3(subgroup_idx));
idx_low  = subgroup_idx(resp2(subgroup_idx) <  resp3(subgroup_idx));

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

% Plot selected stim
stim_to_plot = [1 2 3 4];
gap_size = 20;   % number of white-gap timepoints between stimuli

selected_data = [];

boundaries = cumsum(stim_lengths);
starts = [1, boundaries(1:end-1) + 1];
ends = boundaries;

block_starts = zeros(1, numel(stim_to_plot));
block_ends   = zeros(1, numel(stim_to_plot));

current = 1;

for i = 1:numel(stim_to_plot)

    si = stim_to_plot(i);

    block = sorted_data(starts(si):ends(si), :);

    block_starts(i) = current;
    block_ends(i)   = current + size(block, 1) - 1;

    selected_data = [selected_data; block];

    current = block_ends(i) + 1;

    if i < numel(stim_to_plot)
        gap = nan(gap_size, size(block, 2));
        selected_data = [selected_data; gap];
        current = current + gap_size;
    end
end
fig_firstbaseline_heatmap = figure('Name','dF/F Heatmap selected stimuli','NumberTitle', 'off');
set(fig_firstbaseline_heatmap, 'Units', 'pixels', 'Position', [100, 100, 1600, 800]);

nCells = size(selected_data, 2);
nTime = size(selected_data, 1);

h = imagesc(1:nTime, 1:nCells, selected_data');
colormap turbo;
colorbar;
caxis([0 Limit]);

labels = {datatable(stim_to_plot).name};
labels_new = erase(labels, '.csv');

xticks((block_starts + block_ends) / 2);
xticklabels(string(labels_new));

yticks(5:5:nCells);
xlabel('Timepoints');
ylabel('Cell');
title(sprintf('ΔF/F Heatmap: selected stims [%s]', num2str(stim_to_plot)));
axis tight;

hold on;

for i = 1:numel(stim_to_plot)

    % Stimulus onset at 100 frames after each block starts
    xline(block_starts(i) + 100 - 1, 'r--', 'LineWidth', 1.2);

    % White line at the end of each stimulus block
    if i < numel(stim_to_plot)
        xline(block_ends(i) + 0.5, 'w--', 'LineWidth', 1.2);
    end

end

hold off;

set(h, 'AlphaData', ~isnan(selected_data'));
set(gca, 'Color', 'w');




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

fig3 = figure('Name','Barplot','NumberTitle', 'off');
set(fig3, 'Units', 'pixels', 'Position', [100, 100, 800, 1200]);

subplot(1,2,1);
hold on;

x = [1, 2];

for i = 1:size(group1_data, 1)
    plot(x, group1_data(i, :), 'o:', ...
        'Color', [0.9 0.6 0.6], ...
        'MarkerFaceColor', [0.6 0.6 0.6]);
end

% Plot mean as bar
bar(x, mean(group1_data, 1), ...
    'FaceColor', [0.9,0,0.1], ...
    'FaceAlpha', 0.3, ...
    'EdgeColor', 'none');

title(sprintf('Group 1 (%s resp dur > 1), n=%d', xlabels{1}, size(group1_data,1)));
ylabel('Response (Duration*Mean)');
xticks(x);
xticklabels(xlabels);
ylim([0, max(response_duration(:)) + 2]);

subplot(1,2,2);
hold on;

for i = 1:size(group2_data, 1)
    plot(x, group2_data(i, :), 'o:', ...
        'Color', [0.6 0.9 0.6], ...
        'MarkerFaceColor', [0.6 0.6 0.6]);
end

bar(x, mean(group2_data, 1), ...
    'FaceColor', [0.1,0.9,0], ...
    'FaceAlpha', 0.5, ...
    'EdgeColor', 'none');

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
    final_sorted_data = [final_sorted_data; datatable(Sorting_stim(i)).dataABC_first(:, final_sorted_idx)];
end

fig4 = figure('Name','dF/F Heatmap of chemicals only','NumberTitle', 'off');
set(fig4, 'Units', 'pixels', 'Position', [100, 100, 1600, 800]);

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
stim_boundaries_2 = cumsum(stim_lengths(Sorting_stim)) + 100;

for i = 1:numel(Sorting_stim)-1
    %xline(i * timelength + 0.5, 'w--', 'LineWidth', 1.2);
    xline(stim_boundaries(i), 'w--', 'LineWidth', 1.2);
    xline(stim_boundaries_2(i), 'r--', 'LineWidth', 1.2);
end

xline(100, 'r--','LineWidth', 1.2);

hold off;

heatmap_name3 = 'Heatmap Plot of cell responses_FirstBaselineFilterSel.pdf';
heatmap_path3 = fullfile(pathName,heatmap_name3);
exportgraphics(fig_firstbaseline_heatmap, heatmap_path3, 'ContentType', 'vector');

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
%[sorted, sorted_path] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\ratResultsForSally_26.3.2\All combined_rat\*final_sorted_data*.mat', 'Select one or more MAT files', 'MultiSelect', 'on');
%[dur_files, dur_path] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\ratResultsForSally_26.3.2\All combined_rat\*resp_dur_output*.mat', 'Select one or more MAT files', 'MultiSelect', 'on');
[data_files, data_path] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Xiao\mouseResultsForSally_26.1.20\All combined\*datatable*.mat', 'Select one or more MAT files', 'MultiSelect', 'on');

% sorted_all = [];
% dur_all = [];
% data_all = [];
% data_all_concatenated = [];
% for k = 1:length(sorted)
%     filePath_sorted = fullfile(sorted_path, sorted{k});
%     loadedSorted = load(filePath_sorted, 'final_sorted_data'); 
%     currentSorted = loadedSorted.final_sorted_data;
%     sorted_all = [sorted_all, currentSorted];
% end
% 
% for j = 1:length(dur_files)
%     filePath_dur = fullfile(dur_path, dur_files{j});
%     loadedDur = load(filePath_dur, 'resp_dur_output'); 
%     currentDur = loadedDur.resp_dur_output;
%     dur_all = [dur_all, currentDur];
% end
% 
% for i = 1:length(data_files)
%     filePath_data = fullfile(data_path, data_files{i});
%     loadedData = load(filePath_data, 'datatable'); 
%     currentdata = loadedData.datatable;
%     data_all = [data_all, currentdata];
% end

%% Combined heatmap sorting based on 3,4
Sorting_stim = [3 4];     % the two used for sorting
Plot_stim    = 1:4;       % the ones you want to display in the heatmap
duration_threshold = 20;   %in sec, for plotting response duration difference and filtering out cells not responsive to chemicals
min_consecutive_frames = 100;

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
pooled_resp_dur = [];
pooled_is_responsive = [];
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
    exp_resp_duration = zeros(nCells, numel(Sorting_stim));
    exp_is_responsive = false(nCells, numel(Sorting_stim));

    for k = 1:numel(Sorting_stim)
        si = Sorting_stim(k);

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

        durSec = zeros(nCells,1);
        isResp = false(nCells,1);

        for c = 1:nCells
            x = isAboveStim(:,c);

            d = diff([0; x; 0]);
            runStarts = find(d == 1);
            runEnds = find(d == -1) - 1;
            runLengths = runEnds - runStarts + 1;

            if ~isempty(runLengths)
                maxRun = max(runLengths);
                durSec(c) = maxRun / fr;   % longest consecutive run in seconds
                isResp(c) = maxRun >= min_consecutive_frames;
            end
        end

        switch metricMode
            case "dur"
                exp_resp(:,k) = durSec;
            case "durXmean"
                exp_resp(:,k) = durSec .* smu';
        end

        exp_resp_duration(:,k) = durSec;
        exp_is_responsive(:,k) = isResp;
    end

    % ---- append pooled
    pooled_traces_all = [pooled_traces_all, exp_concat_all]; %#ok<AGROW>
    pooled_resp = [pooled_resp; exp_resp]; %#ok<AGROW>
    pooled_exp_id = [pooled_exp_id; e*ones(nCells,1)]; %#ok<AGROW>
    pooled_cell_id = [pooled_cell_id; (1:nCells)']; %#ok<AGROW>
    pooled_resp_dur = [pooled_resp_dur; exp_resp_duration];
    pooled_is_responsive = [pooled_is_responsive; exp_is_responsive];
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
fi1 = figure('Name','POOLED Heatmap (all stimuli)','NumberTitle','off','Position',[100 100 1600 800]);
imagesc(sorted_traces_all');  % cells x time
colormap turbo; colorbar;caxis([0 2])
xlabel('Timepoints'); ylabel('Pooled cells');
title(sprintf('Sorted by stim %d vs %d, plotted stims %d-%d, nCell = %d', Sorting_stim(1), Sorting_stim(2), Plot_stim(1), Plot_stim(end),size(sorted_traces_all,2)));

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
%% filter out the cells not responsive to chemicals
% responsive_mask = pooled_resp_dur(:,1) > duration_threshold | ...
%                   pooled_resp_dur(:,2) > duration_threshold;
responsive_mask = pooled_is_responsive(:,1) | pooled_is_responsive(:,2);

pooled_traces_all_filt = pooled_traces_all(:, responsive_mask);
pooled_resp_filt       = pooled_resp(responsive_mask, :);
pooled_resp_dur_filt   = pooled_resp_dur(responsive_mask, :);
pooled_exp_id_filt     = pooled_exp_id(responsive_mask);
pooled_cell_id_filt    = pooled_cell_id(responsive_mask);
pooled_is_responsive_filt = pooled_is_responsive(responsive_mask, :);

resp2 = pooled_resp_filt(:,1);
resp3 = pooled_resp_filt(:,2);

idx_high = find(resp2 >= resp3);
idx_low  = find(resp2 <  resp3);

[~, subIdx_high] = sort(resp2(idx_high), 'descend');
sorted_high = idx_high(subIdx_high);

[~, subIdx_low]  = sort(resp3(idx_low), 'descend');
sorted_low = idx_low(subIdx_low);

sortIdx = [sorted_high; sorted_low];

sorted_traces_all_filt = pooled_traces_all_filt(:, sortIdx);

fi2 = figure('Name','POOLED Heatmap (all stimuli)','NumberTitle','off','Position',[100 100 1600 800]);
imagesc(sorted_traces_all_filt');  % cells x time
colormap turbo; colorbar;caxis([0 2])
xlabel('Timepoints'); ylabel('Pooled cells');
title(sprintf('Sorted by stim %d vs %d, plotted stims %d-%d, nCell = %d', Sorting_stim(1), Sorting_stim(2), Plot_stim(1), Plot_stim(end),size(sorted_traces_all_filt,2)));

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
%% Selected stim
stim_to_plot = [1 3 4];
gap_size = 20;   % number of white-gap timepoints between stimuli

selected_traces = [];

boundaries = cumsum(commonLenPlot);
starts = [1, boundaries(1:end-1)+1];
ends = boundaries;

block_starts = zeros(1, numel(stim_to_plot));
block_ends   = zeros(1, numel(stim_to_plot));

current = 1;

for i = 1:numel(stim_to_plot)

    si = stim_to_plot(i);

    block = sorted_traces_all_filt(starts(si):ends(si), :);

    block_starts(i) = current;
    block_ends(i)   = current + size(block,1) - 1;

    selected_traces = [selected_traces; block];

    current = block_ends(i) + 1;

    if i < numel(stim_to_plot)
        gap = nan(gap_size, size(block,2));
        selected_traces = [selected_traces; gap];
        current = current + gap_size;
    end
end

fi_heatmap_sel = figure('Name','Heatmap (selected stims)','NumberTitle','off', ...
       'Position',[100 100 1600 800]);

h = imagesc(selected_traces');

set(h, 'AlphaData', ~isnan(selected_traces'));
set(gca, 'Color', 'w');

colormap turbo;
colorbar;
caxis([0 2]);

xlabel('Timepoints');
ylabel('Cell');
title('Heatmap (Stim 1, 3, 4)');

centers = (block_starts + block_ends) / 2;

xticks(centers);

labels = {D{1}(Plot_stim(stim_to_plot)).name};
labels = erase(labels, '.csv');
xticklabels(labels);
hold off;

%% Filter out cells not responsive to pinch then plot selected stim
min_consecutive_frames = 25;
stim1_is_responsive_filt = false(size(pooled_exp_id_filt));
gap_size = 20;   % number of blank frames between stimuli (adjust)
stimulation_labels = {'Pinch','Saline','AITC','Capsaicin'};
for e = 1:numel(D)
    datatable = D{e};
    stim1_data = datatable(1).dataABC;
    fr = datatable(1).framerate;

    exp_cells = find(pooled_exp_id_filt == e);
    cell_ids = pooled_cell_id_filt(exp_cells);

    if isempty(cell_ids)
        continue
    end

    base = stim1_data(1:100, cell_ids);
    stim = stim1_data(101:end, cell_ids);

    baseline_mean = mean(base, 1);
    baseline_std  = std(base, 0, 1);

    thresh = baseline_mean + nstd .* baseline_std;
    isAboveStim = stim >= thresh;

    isResp = false(numel(cell_ids),1);

    for c = 1:numel(cell_ids)
        x = isAboveStim(:,c);

        d = diff([0; x; 0]);
        runStarts = find(d == 1);
        runEnds = find(d == -1) - 1;
        runLengths = runEnds - runStarts + 1;

        if ~isempty(runLengths)
            isResp(c) = max(runLengths) >= min_consecutive_frames;
        end
    end

    stim1_is_responsive_filt(exp_cells) = isResp;
end

combined_mask_filt = stim1_is_responsive_filt;
pooled_traces_all_bothfilt = pooled_traces_all_filt(:, combined_mask_filt);
pooled_resp_bothfilt       = pooled_resp_filt(combined_mask_filt, :);
pooled_exp_id_bothfilt     = pooled_exp_id_filt(combined_mask_filt);
pooled_cell_id_bothfilt    = pooled_cell_id_filt(combined_mask_filt);
pooled_is_responsive_bothfilt = pooled_is_responsive_filt(combined_mask_filt, :);

Sort_stim = 1;
baselineFrames = 100;
win1 = [100 320];
win2 = [321 500];

metric1_all = zeros(numel(pooled_exp_id_bothfilt), 1);
metric2_all = zeros(numel(pooled_exp_id_bothfilt), 1);

for e = 1:numel(D)
    datatable = D{e};
    Xsort = datatable(Sort_stim).dataABC;

    % crop same way as pooled plot
    plotIndex = find(Plot_stim == Sort_stim, 1);
    if ~isempty(plotIndex)
        Xsort = Xsort(1:commonLenPlot(plotIndex), :);
    end

    % baseline subtract
    baseEnd = min(baselineFrames, size(Xsort,1));
    bmu = mean(Xsort(1:baseEnd,:), 1);
    Xsort = Xsort - bmu;

    % cells from this experiment that passed both filters
    exp_cells = find(pooled_exp_id_bothfilt == e);
    cell_ids = pooled_cell_id_bothfilt(exp_cells);

    if isempty(cell_ids)
        continue
    end

    metric1_all(exp_cells) = max(Xsort(win1(1):win1(2), cell_ids), [], 1)';
    metric2_all(exp_cells) = max(Xsort(win2(1):win2(2), cell_ids), [], 1)';
end

idx_win1 = find(metric1_all >= metric2_all);
idx_win2 = find(metric1_all <  metric2_all);

%Further sort by chemical response
resp2 = pooled_resp_bothfilt(:,1);
resp3 = pooled_resp_bothfilt(:,2);
idx_high_w1 = idx_win1(resp2(idx_win1) >= resp3(idx_win1));
idx_low_w1  = idx_win1(resp2(idx_win1) <  resp3(idx_win1));

[~, s1] = sort(resp2(idx_high_w1), 'descend');
sorted_high_w1 = idx_high_w1(s1);

[~, s2] = sort(resp3(idx_low_w1), 'descend');
sorted_low_w1 = idx_low_w1(s2);

sorted_win1 = [sorted_high_w1; sorted_low_w1];

idx_high_w2 = idx_win2(resp2(idx_win2) >= resp3(idx_win2));
idx_low_w2  = idx_win2(resp2(idx_win2) <  resp3(idx_win2));

[~, s3] = sort(resp2(idx_high_w2), 'descend');
sorted_high_w2 = idx_high_w2(s3);

[~, s4] = sort(resp3(idx_low_w2), 'descend');
sorted_low_w2 = idx_low_w2(s4);

sorted_win2 = [sorted_high_w2; sorted_low_w2];

sortIdx_final = [sorted_win1; sorted_win2];
sorted_traces_final = pooled_traces_all_bothfilt(:, sortIdx_final);

stim_to_plot = [1 3 4];
selected_traces = [];
boundaries = cumsum(commonLenPlot);
starts = [1, boundaries(1:end-1)+1];
ends = boundaries;

block_starts = zeros(1, numel(stim_to_plot));
block_ends   = zeros(1, numel(stim_to_plot));
baseline_x   = zeros(1, numel(stim_to_plot));
current = 1;
for i = 1:numel(stim_to_plot)
    si = stim_to_plot(i);
    % selected_traces = [selected_traces; ...
    %     sorted_traces_final(starts(si):ends(si), :)];
    block = sorted_traces_final(starts(si):ends(si), :);

    block_starts(i) = current;
    block_ends(i)   = current + size(block,1) - 1;
    baseline_x(i)   = block_starts(i) + baselineFrames - 1;

    selected_traces = [selected_traces; block];

    current = block_ends(i) + 1;
    if i < numel(stim_to_plot)
        gap = nan(gap_size, size(block,2));
        selected_traces = [selected_traces; gap];
        current = current + gap_size;
    end
end


fi_split_filter = figure('Name','POOLED Heatmap sorted by stim1 then stim 3 and stim 4', ...
    'NumberTitle','off','Position',[100 100 1600 800]);

h = imagesc(selected_traces');
set(h, 'AlphaData', ~isnan(selected_traces')); 
colormap turbo;set(gca, 'Color', 'w') 
colorbar;
caxis([0 2]);

%xlabel('Timepoints');
ylabel('Pooled cells');
title(sprintf('Sorted by pinch stim and then sort by chemical stim, nCell = %d',size(selected_traces,2)));

% boundaries = cumsum(commonLenPlot);
% xticks(commonLenPlot/2 + [0 cumsum(commonLenPlot(1:end-1))]);
centers = (block_starts + block_ends) / 2;

labels = stimulation_labels(stim_to_plot);
xticklabels(labels);
len_selected = commonLenPlot(stim_to_plot);

% centers = [];
% current = 0;
% 
% for i = 1:numel(len_selected)
%     centers(i) = current + len_selected(i)/2;
%     current = current + len_selected(i);
% 
%     if i < numel(len_selected)
%         current = current + gap_size;
%     end
% end

xticks(centers);
% xticklabels(labels(stim_to_plot));

hold on;
% for k = 1:numel(boundaries)-1
%     xline(boundaries(k), 'w--', 'LineWidth', 1.2);
%     %xline([baselineFrames,boundaries(k)+baselineFrames], 'w--', 'LineWidth', 1.2)
% end
for i = 1:numel(baseline_x)
    xline(baseline_x(i), 'w--', 'LineWidth', 1.2);
end
% mark the two windows inside stim 1
%xline(win1(1), 'r--', 'LineWidth', 1.2);
%xline(win1(2), 'r--', 'LineWidth', 1.2);
% xline(win2(1), 'm--', 'LineWidth', 1.2);
%xline(win2(2), 'c--', 'LineWidth', 1.2);

% mark the boundary between the two cell groups
% xline_group = []; % not xline; see yline below
% yline(numel(sorted_win1) + 0.5, 'w--', 'LineWidth', 1.0);
% yline(numel(sorted_high_w1) + 0.5, 'g--', 'LineWidth', 1.0);
% yline(numel(sorted_win1) + numel(sorted_high_w2) + 0.5, 'g--', 'LineWidth', 1.0);

hold off;

pdf_name_split_filter = 'POOLED Heatmap_FilteredbyPinchAndChemical(selected stim).pdf';
exportgraphics(fi_split_filter, fullfile(data_path,pdf_name_split_filter), 'ContentType', 'vector');
%% Percentage of chemical response in pinch + chemical response filtered group
resp3 = pooled_is_responsive_bothfilt(:,1);
resp4 = pooled_is_responsive_bothfilt(:,2);

n_total = size(pooled_is_responsive_bothfilt,1);
n_stim3_only = sum(resp3 & ~resp4);
n_stim4_only = sum(~resp3 & resp4);
n_both       = sum(resp3 & resp4);
perc_stim3_only = 100 * n_stim3_only / n_total;
perc_stim4_only = 100 * n_stim4_only / n_total;
perc_both       = 100 * n_both       / n_total;


capsacicin_color  = [235 120 125] / 255; 
AITC_color   = [255, 230, 181]/255;%[240, 227, 107] / 255; 
both_color = (capsacicin_color + AITC_color)/2;

fig_pie3 = figure('Name','Stim3 vs Stim4 responsive fractions in pinch responsive units', ...
    'NumberTitle','off', ...
    'Position',[100 100 800 600], ...
    'Color','w');
labels1 = {
    sprintf('AITC only\n%.1f%%', perc_stim3_only)
    sprintf('Both\n%.1f%%', perc_both)
    sprintf('Capsaicin only\n%.1f%%', perc_stim4_only)
};

p1 = pie([n_stim3_only, n_both, n_stim4_only]);
delete(findobj(p1, 'Type', 'text'));
legend(labels1, 'Location','bestoutside');
p1(1).FaceColor = AITC_color;
p1(3).FaceColor = both_color;
p1(5).FaceColor = capsacicin_color;
title(sprintf('Percentage of response to chemicals (n=%d)', n_total));

pdf_name_pie3 = 'PieCharts of response to chemicals in pinch_chemical responsive cells.pdf';
exportgraphics(fig_pie3, fullfile(data_path, pdf_name_pie3), ...
    'ContentType', 'vector');
%% Sort by thigh and paw [not used]
win1 = [100 320];
win2 = [320 500];

metric1_all = [];
metric2_all = [];

for e = 1:numel(D)
    datatable = D{e};
    Xsort = datatable(Sort_stim).dataABC;

    % crop same way as in pooled plot
    plotIndex = find(Plot_stim == Sort_stim, 1);
    if ~isempty(plotIndex)
        Xsort = Xsort(1:commonLenPlot(plotIndex), :);
    end

    % baseline subtract
    baseEnd = min(baselineFrames, size(Xsort,1));
    bmu = mean(Xsort(1:baseEnd,:), 1);
    Xsort = Xsort - bmu;

    % compute max in each sub-window
    metric1 = max(Xsort(win1(1):win1(2), :), [], 1)';
    metric2 = max(Xsort(win2(1):win2(2), :), [], 1)';

    metric1_all = [metric1_all; metric1];
    metric2_all = [metric2_all; metric2];
end

% Split into two groups
idx_first = find(metric1_all >= metric2_all);
idx_second = find(metric1_all < metric2_all);

% Sort first-window-dominant cells by window 1 response
[~, subIdx_first] = sort(metric1_all(idx_first), 'descend');
sorted_first = idx_first(subIdx_first);

% Sort second-window-dominant cells by window 2 response
[~, subIdx_second] = sort(metric2_all(idx_second), 'descend');
sorted_second = idx_second(subIdx_second);

% Final order
sortIdx_split = [sorted_first; sorted_second];

% Apply to pooled matrix
sorted_traces_all_split = pooled_traces_all(:, sortIdx_split);


fi_split = figure('Name','POOLED Heatmap sorted by stim1 early/late peak', ...
    'NumberTitle','off','Position',[100 100 1600 800]);

imagesc(sorted_traces_all_split');
colormap turbo;
colorbar;
caxis([0 2]);

xlabel('Timepoints');
ylabel('Pooled cells');
title('Sorted by stim1: first-window group then second-window group');

boundaries = cumsum(commonLenPlot);
xticks(commonLenPlot/2 + [0 cumsum(commonLenPlot(1:end-1))]);

labels = {D{1}(Plot_stim).name};
labels = erase(labels, '.csv');
xticklabels(labels);

hold on;
for k = 1:numel(boundaries)-1
    xline(boundaries(k), 'w--', 'LineWidth', 1.2);
end

% mark the two windows inside stim 1
xline(win1(1), 'r--', 'LineWidth', 1.2);
xline(win1(2), 'r--', 'LineWidth', 1.2);
xline(win2(1), 'c--', 'LineWidth', 1.2);
xline(win2(2), 'c--', 'LineWidth', 1.2);

% mark the boundary between the two cell groups
xline_group = []; % not xline; see yline below
yline(numel(sorted_first) + 0.5, 'w-', 'LineWidth', 2);

hold off;
%% Find out the percentage of the stimulation pattern using chemical response [not used]
idx_resp1_stim1resp = find(pooled_is_responsive_filt(:,1) & stim1_is_responsive_filt);

late_higher_all_filt = false(size(pooled_exp_id_filt));

for e = 1:numel(D)
    stim1_data = D{e}(1).dataABC;

    exp_cells = find(pooled_exp_id_filt == e);
    cell_ids = pooled_cell_id_filt(exp_cells);

    if isempty(cell_ids)
        continue
    end

    max_100_300 = max(stim1_data(100:320, cell_ids), [], 1);
    max_300_500 = max(stim1_data(321:500, cell_ids), [], 1);

    late_higher_all_filt(exp_cells) = (max_300_500 > max_100_300)';
end

percentage = 100 * sum(late_higher_all_filt(idx_resp1_stim1resp)) / numel(idx_resp1_stim1resp);

fprintf('%.2f%% of stim3>stim4 cells with stim1 response also have stim1 max(300:500) > max(100:300).\n', percentage);

n_late = sum(late_higher_all_filt(idx_resp1_stim1resp));
n_not  = numel(idx_resp1_stim1resp) - n_late;

perc_late = 100 * n_late / numel(idx_resp1_stim1resp);
perc_not  = 100 * n_not  / numel(idx_resp1_stim1resp);

labels = {
    sprintf('Paw (%.1f%%)', perc_late)
    sprintf('Thigh (%.1f%%)', perc_not)
};

fig_pie = figure;
p = pie([n_late, n_not], labels);
p(1).FaceColor = [0, 48, 130] / 255;
p(3).FaceColor = [255, 201, 23] / 255;

title(sprintf('AITC responsive cells (n=%d)', numel(idx_resp1_stim1resp)));

%% Look in each pinch stimuli and see the percentage of chemical response
% win1 group
% ---- win1 group
resp3_win1 = pooled_is_responsive_bothfilt(idx_win1, 1);   % AITC
resp4_win1 = pooled_is_responsive_bothfilt(idx_win1, 2);   % Capsaicin

n_win1 = numel(idx_win1);
n_win1_stim3only = sum(resp3_win1 & ~resp4_win1);
n_win1_stim4only = sum(~resp3_win1 & resp4_win1);
n_win1_both      = sum(resp3_win1 & resp4_win1);

perc_win1_stim3only = 100 * n_win1_stim3only / n_win1;
perc_win1_stim4only = 100 * n_win1_stim4only / n_win1;
perc_win1_both      = 100 * n_win1_both / n_win1;

% ---- win2 group
resp3_win2 = pooled_is_responsive_bothfilt(idx_win2, 1);   % AITC
resp4_win2 = pooled_is_responsive_bothfilt(idx_win2, 2);   % Capsaicin

n_win2 = numel(idx_win2);
n_win2_stim3only = sum(resp3_win2 & ~resp4_win2);
n_win2_stim4only = sum(~resp3_win2 & resp4_win2);
n_win2_both      = sum(resp3_win2 & resp4_win2);

perc_win2_stim3only = 100 * n_win2_stim3only / n_win2;
perc_win2_stim4only = 100 * n_win2_stim4only / n_win2;
perc_win2_both      = 100 * n_win2_both / n_win2;


capsacicin_color  = [235 120 125] / 255; 
AITC_color   = [255, 230, 181]/255;%[240, 227, 107] / 255; 
both_color = (capsacicin_color + AITC_color)/2;

fig_pie2 = figure('Name','Stim3 vs Stim4 responsive fractions', ...
    'NumberTitle','off', ...
    'Position',[100 100 1600 600], ...
    'Color','w');

% ---- pie for idx_win1
subplot(1,2,1)

labels1 = {
    sprintf('AITC only\n%.1f%%', perc_win1_stim3only)
    sprintf('Both\n%.1f%%', perc_win1_both)
    sprintf('Capsaicin only\n%.1f%%', perc_win1_stim4only)
};

p1 = pie([n_win1_stim3only, n_win1_both, n_win1_stim4only]);
delete(findobj(p1, 'Type', 'text'));
legend(labels1, 'Location','bestoutside');
p1(1).FaceColor = AITC_color;
p1(3).FaceColor = both_color;
p1(5).FaceColor = capsacicin_color;

% p1(1).FaceAlpha = 1;
% p1(3).FaceAlpha = 0.8;
% p1(5).FaceAlpha = 1;


t1 = title(sprintf('Thigh (n=%d)', n_win1));
t1.Units = 'normalized';
t1.Position(2) = 1.08;   % move up (try 1.1–1.2)

% ---- pie for idx_win2
subplot(1,2,2)

labels2 = {
    sprintf('AITC only\n%.1f%%', perc_win2_stim3only)
    sprintf('Both\n%.1f%%', perc_win2_both)
    sprintf('Capsaicin only\n%.1f%%', perc_win2_stim4only)
};

p2 = pie([n_win2_stim3only, n_win2_both,n_win2_stim4only]);
legend(labels2, 'Location','bestoutside');
delete(findobj(p2, 'Type', 'text'));
p2(1).FaceColor = AITC_color;
p2(3).FaceColor = both_color;
p2(5).FaceColor = capsacicin_color;

% p2(1).FaceAlpha = 1;
% p2(3).FaceAlpha = 0.5;
% p2(5).FaceAlpha = 1;

t2 = title(sprintf('Paw (n=%d)', n_win2));
t2.Units = 'normalized';
t2.Position(2) = 1.08;   % move up (try 1.1–1.2)

pdf_name_pie2 = 'PieCharts of paw and thigh response to chemicals.pdf';
exportgraphics(fig_pie2, fullfile(data_path, pdf_name_pie2), ...
    'ContentType', 'vector');
%% Normalize the response across stimulation (only filter with chemical response)
nCells_filt = numel(pooled_exp_id_filt);
nStim = numel(Plot_stim);

max_matrix = zeros(nCells_filt, nStim);
for e = 1:numel(D)
    datatable = D{e};

    exp_cells = find(pooled_exp_id_filt == e);
    cell_ids = pooled_cell_id_filt(exp_cells);

    if isempty(cell_ids)
        continue
    end

    for k = 1:nStim
        si = Plot_stim(k);
        X = datatable(si).dataABC;

        % optional: crop same as heatmap
        X = X(1:commonLenPlot(k), :);

        % optional: baseline subtract (recommended for consistency)
        baseEnd = min(baselineFrames, size(X,1));
        bmu = mean(X(1:baseEnd,:), 1);
        X = X - bmu;

        % compute max per cell
        max_vals = max(X(:, cell_ids), [], 1);

        % store
        max_matrix(exp_cells, k) = max_vals';
    end
end

max_per_cell = max(max_matrix, [], 2);   % nCells x 1

% avoid divide-by-zero
max_per_cell(max_per_cell == 0) = 1;

norm_matrix = max_matrix ./ max_per_cell;

nStim = size(norm_matrix, 2);
colors = [
    140 190 170   % teal
    185 200 160   % green
    225 185 155   % beige
    235 120 125   % red
    245 225 150   % yellow
] / 255;

colors = colors(1:nStim, :);

fi3 = figure('Name','Normalized responses by stimulus','NumberTitle','off', ...
       'Position',[100 100 900 600]);
hold on;

% scatter each cell with slight horizontal jitter
for k = 1:nStim
    xj = k + 0.12 * (rand(size(norm_matrix,1),1) - 0.5);
    scatter(xj, norm_matrix(:,k), 18, ...
        'MarkerFaceColor', colors(k,:), ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.5);
end

% mean bar
b = bar(1:nStim, mean(norm_matrix,1));
b.FaceColor = 'flat';   % IMPORTANT
b.CData = colors;       % apply turbo colors
b.FaceAlpha = 0.35;
b.EdgeColor = 'flat';
b.CData = colors;
% optional: mean line on top

xticks(1:nStim);
labels = {D{1}(Plot_stim).name};
labels = erase(labels, '.csv');
xticklabels(labels);

ylabel('Normalized response');
xlabel('Stimulus');
title('Normalized max response across stimuli');
ylim([0 1.05]);
box off;
hold off;

%% Select stim to plot bar plot
stim_to_plot = [1 3 4];

norm_matrix_sub = norm_matrix(:, stim_to_plot);
mean_resp = mean(norm_matrix_sub, 1);
std_resp  = std(norm_matrix_sub, 0, 1);
sem_resp = std(norm_matrix_sub, 0, 1) / sqrt(size(data_files,2));

labels_sub = {D{1}(Plot_stim(stim_to_plot)).name};
labels_sub = erase(labels_sub, '.csv');

nStim = numel(stim_to_plot);

colors_sub = colors(stim_to_plot, :);

fi4 = figure('Name','Selected stimuli','NumberTitle','off', ...
       'Position',[100 100 800 600]);
hold on;

% scatter
for k = 1:nStim
    xj = k + 0.8 * (rand(size(norm_matrix_sub,1),1) - 0.5);

    scatter(xj, norm_matrix_sub(:,k), 20, ...
        'MarkerFaceColor', colors_sub(k,:), ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.7);
end

% bar
b = bar(1:nStim, mean(norm_matrix_sub,1));
b.FaceColor = 'flat';
b.CData = colors_sub;
b.FaceAlpha = 0.35;
b.EdgeColor = 'none';

errorbar(1:nStim, mean_resp, sem_resp, ...
    'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 10);

% labels
xticks(1:nStim);
xticklabels(labels_sub);

ylabel('Normalized response');
xlabel('Stimulus');
title('Stim 1, 3, 4 only');
ylim([0 1.05]);

box off;
hold off;
%% Normalize the response across stimulation (filter both chemical response and pinch response)
nCells_filt = numel(pooled_exp_id_bothfilt);
stim_to_plot = [1 3 4];
nStim = numel(stim_to_plot);
max_matrix = zeros(nCells_filt, nStim);
for e = 1:numel(D)
    datatable = D{e};

    exp_cells = find(pooled_exp_id_bothfilt == e);
    cell_ids = pooled_cell_id_bothfilt(exp_cells);

    if isempty(cell_ids)
        continue
    end

    for k = 1:nStim
        si = stim_to_plot(k);
        X = datatable(si).dataABC;

        % optional: crop same as heatmap
        X = X(1:commonLenPlot(k), :);

        % optional: baseline subtract (recommended for consistency)
        baseEnd = min(baselineFrames, size(X,1));
        bmu = mean(X(1:baseEnd,:), 1);
        X = X - bmu;

        % compute max per cell
        max_vals = max(X(:, cell_ids), [], 1);

        % store
        max_matrix(exp_cells, k) = max_vals';
    end
end

max_per_cell = max(max_matrix, [], 2);   % nCells x 1

% avoid divide-by-zero
max_per_cell(max_per_cell == 0) = 1;

norm_matrix = max_matrix ./ max_per_cell;

mean_resp = mean(norm_matrix, 1);
std_resp  = std(norm_matrix, 0, 1);
sem_resp = std(norm_matrix, 0, 1) / sqrt(size(data_files,2));

colors = [
    191 172 211 %140 190 170   % teal
    185 200 160   % green
    255 230 181 %225 185 155   % beige
    235 120 125   % red
    245 225 150   % yellow
] / 255;

colors = colors(stim_to_plot, :);

fi5 = figure('Name','Selected stimuli filtered both','NumberTitle','off', ...
       'Position',[100 100 800 600]);
hold on;

for k = 1:nStim
    xj = k + 0.6 * (rand(size(norm_matrix,1),1) - 0.5);

    scatter(xj, norm_matrix(:,k), 35, ...
        'MarkerFaceColor', colors(k,:), ...
        'MarkerEdgeColor', [0.7 0.7 0.7], ...
        'MarkerFaceAlpha', 0.35);
end
% bar
b = bar(1:nStim, mean(norm_matrix,1));
b.FaceColor = 'flat';
b.CData = colors;
b.FaceAlpha = 0.5;
b.EdgeColor = 'flat';
b.LineWidth = 1.8;

errorbar(1:nStim, mean_resp, sem_resp, ...
    'Color',[0.6 0.6 0.6], 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 10);

xticks(1:nStim);
xticklabels(stimulation_labels(stim_to_plot));
ylabel('Normalized response');
xlabel('Stimulus');
title('Normalized response to pinch and chemical stimulation (filtered with both)');
ylim([0 1.05]);
box off;
hold off;

%save
pdf_name5 = 'Normalized response across stimuli(filtered both pinch and chemical).pdf';
exportgraphics(fi5, fullfile(data_path,pdf_name5), 'ContentType', 'vector');
%% Histogram [not used]
fi_hist = figure('Name','Histogram of normalized responses', ...
    'NumberTitle','off','Position',[100 100 800 600]);
hold on;

edges = linspace(0,1,30);   % bins from 0 to 1

for k = 1:nStim
    histogram(norm_matrix(:,k), edges, ...
        'Normalization','probability', ...
        'FaceColor', colors(k,:), ...
        'FaceAlpha', 0.4, ...
        'EdgeColor','none');
end

xlabel('Normalized response');
ylabel('Fraction of cells');
title('Distribution of normalized responses');
legend(stimulation_labels(stim_to_plot), 'Location','best');

box off;
hold off;
%% Violin plot [not used]
figure('Name','Violin plot','NumberTitle','off', ...
       'Position',[100 100 800 600]);
hold on;

v = violinplot(norm_matrix_sub);

for k = 1:numel(v)
    v(k).ViolinColor = colors_sub(k,:);
    v(k).BoxColor = [0 0 0];
    v(k).MedianColor = [0 0 0];
    v(k).ViolinAlpha = 0.5;
end

ylabel('Normalized response');
xlabel('Stimulus');
title('Normalized max response across selected stimuli');
ylim([0 1.05]);
box off;
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


pdf_name1 = 'POOLED Heatmap (all stimuli).pdf';
pdf_name2 = 'POOLED Heatmap_Filteredbychemicalresp.pdf';
pdf_name3 = 'POOLED Heatmap_Filteredbychemicalresp(selected stim).pdf';
pdf_name4 = 'Normalized response across stimuli(selected).pdf';

exportgraphics(fi1, fullfile(data_path, pdf_name1), 'ContentType', 'vector');
exportgraphics(fi2, fullfile(data_path,pdf_name2), 'ContentType', 'vector');
exportgraphics(fig_pie, fullfile(data_path, 'PieChart.pdf'), ...
    'ContentType', 'vector');
exportgraphics(fi_heatmap_sel, fullfile(data_path, pdf_name3), 'ContentType', 'vector');
exportgraphics(fi4, fullfile(data_path,pdf_name4), 'ContentType', 'vector');