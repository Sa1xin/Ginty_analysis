% Find out the indenter length at fixed force
clear;
folderNameTemp = strsplit(path,filesep);
folderName = folderNameTemp{end-1};
clear folderNameTemp
[filenameMat,pathMat] = uigetfile('\\research.files.med.harvard.edu\Neurobio\GintyLab\Qi\stimulation\indenter\*.mat',...
   ['select an indentation file for   ', folderName]);

% [filenameMat,pathMat] = uigetfile('C:\Users\Qi_Li\Dropbox (HMS)\LQCalciumImaging\stimulation\indenter\*.mat', ...
%     ['select an indentation file for
load([pathMat,filenameMat])

%break the force
force = reshape(data(:,3), [numel(data(:,3))/length(sineFrequency),length(sineFrequency)]);

%substract baseline
force_baseline = mean(mean(force(1:baseline * Fs, :)));
force = force - force_baseline;
disp('loading completed')

%%
close all
trace_exceeding = [];
force_exceeding = [];
for i = 1: size(force,2)
    % figure, plot(force(1:10:end/2,i)*50);
    % pbaspect([5 1 1]);
    % title(['trace ', num2str(i)])
    % ylim([0 25])
    % set(gcf, 'Position', [0, 0, 750, 150]);
    % grid off
    % box off
    if max(force(:,i)*50) > (forceRange(2)+1)
        trace_exceeding(end+1) = i;
        force_exceeding(end+1) = max(force(:,i)*50) - forceRange(2);
    end

end
% find the nBadTrace based on this
[frequency, ~, Findex] = unique(sineFrequency);
trace_exceeding_freq = [trace_exceeding',frequency(Findex(trace_exceeding)),force_exceeding']

all_freq_force = zeros(length(frequency),repetitions);
all_freq_Traceindex = zeros(length(frequency),repetitions);
all_freq_combined = zeros(length(frequency), repetitions*2);
all_freq_slope_ramp = zeros(length(frequency),repetitions);
all_freq_slope_deduced = zeros(length(frequency),repetitions);
for j = 1:length(frequency)
    % Find the trial (column) indices corresponding to frequency j
    idx = find(Findex == j);

    % For each repetition
    for k = 1:repetitions
        col = idx(k);                     % trial column in force matrix
        forceTemp = force(:, col);        % force waveform for this trial
        all_freq_force(j, k) = max(forceTemp)*50 - forceRange(2);
        all_freq_Traceindex(j,k) = idx(k);
        % Interleaved column positions
        col_force = 2*k - 1;
        col_idx   = 2*k;

        all_freq_combined(j, col_force) = all_freq_force(j, k);
        all_freq_combined(j, col_idx)   = col;
        % Calculate the slope by using the force
        y = forceTemp(Fs*baseline+1 : Fs*(baseline+vibTime))*50;
        t = (0:length(y)-1) / Fs;
        yUpper = movmax(y, round(Fs / frequency(j)));
        p = polyfit(t, yUpper, 1);
        s = p(1);
        all_freq_slope_ramp(j,k) = s;
        %Calculate the slope by using the maximum force and baseline
        s2 = (max(forceTemp) - mean(forceTemp(1:Fs*baseline)))*50/vibTime;
        all_freq_slope_deduced(j,k) = s2;
        
    end
end

threshold_all_freq_force = abs(all_freq_force - mean(all_freq_force,2))- std(all_freq_force,[],2); 
bad_trace_suggestion = all_freq_Traceindex; 
bad_trace_suggestion((~(threshold_all_freq_force>0))|(abs(all_freq_force)<1)) = 0; 
all_freq_force = [frequency, all_freq_force]; 
all_freq_Traceindex = [frequency, all_freq_Traceindex]; 
all_freq_combined = [frequency, all_freq_combined];
%disp(all_freq_combined);
fprintf('%d %8.4f %d %8.4f %d %8.4f %d\n', all_freq_combined.');
disp(nonzeros(bad_trace_suggestion));


force_ori = data(:,3);
down = 10;
figure,
tick = floor(numel(force_ori)/Fs/5/10)*10;
% subplot(311),plot(cameraTrigger(1:10:end)),title('Trigger'),
subplot(211),plot(data(1:down:end,2)),title("length");
xticks(tick*Fs/down:tick*Fs/down:numel(force_ori)/down)
xticklabels(strsplit(num2str(tick: tick: floor(numel(force)/Fs))));
subplot(212),plot(data(1:down:end,3)*50),title("force (in mN)");
xticks(tick*Fs/down:tick*Fs/down:numel(force_ori)/down)
xticklabels(strsplit(num2str(tick: tick: floor(numel(force_ori)/Fs))));
xlabel('time(s)')

%%
lengthTrace = reshape(data(:,2), ...
    [numel(data(:,2))/length(sineFrequency), length(sineFrequency)]);
[frequency, ~, Findex] = unique(sineFrequency);

plotDown = 20;

t = (0:size(force,1)-1) / Fs;
tPlot = t(1:plotDown:end);

nFreq = numel(frequency);
nCols = 2;
nFreqRows = ceil(nFreq / nCols);
nRows = nFreqRows * 2;
%%
figure;
set(gcf, 'Position', [100, 50, 1400, 900]);

for j = 1:nFreq

    idx = find(Findex == j);   % trials for this frequency
    thisFreq = frequency(j);

    freqRow = ceil(j / nCols);
    freqCol = mod(j-1, nCols) + 1;

    forceRow = (freqRow - 1) * 2 + 1;
    lengthRow = forceRow + 1;

    forceSubplotIdx = (forceRow - 1) * nCols + freqCol;
    lengthSubplotIdx = (lengthRow - 1) * nCols + freqCol;

    %% -------------------------
    % Force plot
    % -------------------------
    subplot(nRows, nCols, forceSubplotIdx)

    plot(tPlot, force(1:plotDown:end, idx) * 50, 'LineWidth', 0.5)
    hold on

    xline(baseline, 'r--', 'LineWidth', 1)
    xline(baseline + vibTime, 'g--', 'LineWidth', 1)

    title(sprintf('%d Hz force', thisFreq))
    ylabel('Force (mN)')
    xlim([0 baseline + vibTime + decayTime])
    box off
    set(gca, 'XTickLabel', [])

    %% -------------------------
    % Length peak-to-peak per sine cycle
    % -------------------------
    subplot(nRows, nCols, lengthSubplotIdx)
    hold on

    vibStartSample = round(baseline * Fs) + 1;
    vibEndSample = round((baseline + vibTime) * Fs);

    samplesPerCycle = round(Fs / thisFreq);

    for k = 1:numel(idx)

        trialIdx = idx(k);
        thisLength = lengthTrace(:, trialIdx);

        cycleStart = vibStartSample;
        p2pVals = [];
        p2pTimes = [];

        while cycleStart + samplesPerCycle - 1 <= vibEndSample

            cycleEnd = cycleStart + samplesPerCycle - 1;

            oneCycleLength = thisLength(cycleStart:cycleEnd);

            thisP2P = max(oneCycleLength) - min(oneCycleLength);

            cycleCenter = round((cycleStart + cycleEnd) / 2);
            cycleCenterTime = (cycleCenter - 1) / Fs;

            p2pVals(end+1,1) = thisP2P;
            p2pTimes(end+1,1) = cycleCenterTime;

            cycleStart = cycleStart + samplesPerCycle;
        end

        plot(p2pTimes, p2pVals, '-o', 'LineWidth', 0.8, 'MarkerSize', 3)
    end

    xline(baseline, 'r--', 'LineWidth', 1)
    xline(baseline + vibTime, 'g--', 'LineWidth', 1)

    title(sprintf('%d Hz length peak-to-peak', thisFreq))
    ylabel('Length P-P')
    xlim([0 baseline + vibTime + decayTime])
    box off

    if freqRow == nFreqRows
        xlabel('Time (s)')
    else
        set(gca, 'XTickLabel', [])
    end
end
%% Find length peak-to-peak when force reaches 10 mN

force_mN = force * 50;   % convert V to mN

targetForce = 10;        % mN

[frequency, ~, Findex] = unique(sineFrequency);

nTrace = length(sineFrequency);

lengthP2P_at10mN = nan(nTrace,1);
time_at10mN = nan(nTrace,1);
force_at10mN = nan(nTrace,1);

for i = 1:nTrace

    thisFreq = sineFrequency(i);

    % Search only during vibration window
    vibStartSample = round(baseline * Fs) + 1;
    vibEndSample = round((baseline + vibTime) * Fs);

    thisForce = force_mN(:,i);
    thisLength = lengthTrace(:,i);

    % Find first time force reaches 10 mN during vibration
    idx10 = find(thisForce(vibStartSample:vibEndSample) >= targetForce, ...
        1, 'first');

    if isempty(idx10)
        continue
    end

    idx10 = vibStartSample + idx10 - 1;

    time_at10mN(i) = (idx10 - 1) / Fs;
    force_at10mN(i) = thisForce(idx10);

    % One sine-wave cycle around that time
    samplesPerCycle = round(Fs / thisFreq);

    halfCycle = round(samplesPerCycle / 2);

    cycleStart = max(vibStartSample, idx10 - halfCycle);
    cycleEnd = min(vibEndSample, idx10 + halfCycle);

    oneCycleLength = thisLength(cycleStart:cycleEnd);

    % Peak-to-peak length around 10 mN force
    lengthP2P_at10mN(i) = max(oneCycleLength) - min(oneCycleLength);
end
% Average length P-P at 10 mN by frequency

lengthP2P_10mN_eachFreq = nan(numel(frequency), repetitions);
lengthP2P_10mN_mean = nan(numel(frequency),1);
lengthP2P_10mN_sem = nan(numel(frequency),1);

for j = 1:numel(frequency)

    idx = find(Findex == j);

    values = lengthP2P_at10mN(idx);

    lengthP2P_10mN_eachFreq(j,1:numel(values)) = values;

    lengthP2P_10mN_mean(j) = mean(values, 'omitnan');
    lengthP2P_10mN_sem(j) = std(values, 'omitnan') / sqrt(sum(~isnan(values)));
end
figure;

errorbar(frequency, lengthP2P_10mN_mean, lengthP2P_10mN_sem, ...
    'o-', 'LineWidth', 1.5, 'MarkerSize', 6);

xlabel('Frequency (Hz)');
ylabel('Length peak-to-peak at 10 mN');
title('Length peak-to-peak when force reaches 10 mN');
xticks(frequency);
box off;
figure;
scatter(sineFrequency, lengthP2P_at10mN, 50, 'filled');
xlabel('Frequency (Hz)');
ylabel('Length peak-to-peak at 10 mN');
title('Individual trials');
xticks(frequency);
box off;
ylim([0 1])
%% Find length peak - baseline mean when force reaches 10 mN

force_mN = force * 50;   % convert V to mN

targetForce = 10;        % mN

[frequency, ~, Findex] = unique(sineFrequency);

nTrace = length(sineFrequency);

lengthPeakMinusBaseline_at10mN = nan(nTrace,1);
time_at10mN = nan(nTrace,1);
force_at10mN = nan(nTrace,1);
lengthPeak_at10mN = nan(nTrace,1);
lengthBaselineMean = nan(nTrace,1);

for i = 1:nTrace

    thisFreq = sineFrequency(i);

    % Define windows
    baselineStartSample = 1;
    baselineEndSample = round(baseline * Fs);

    vibStartSample = round(baseline * Fs) + 1;
    vibEndSample = round((baseline + vibTime) * Fs);

    thisForce = force_mN(:,i);
    thisLength = lengthTrace(:,i);

    % Baseline mean length before vibration
    lengthBaselineMean(i) = mean(thisLength(baselineStartSample:baselineEndSample), ...
        'omitnan');

    % Find first time force reaches 10 mN during vibration
    idx10 = find(thisForce(vibStartSample:vibEndSample) >= targetForce, ...
        1, 'first');

    if isempty(idx10)
        continue
    end

    idx10 = vibStartSample + idx10 - 1;

    time_at10mN(i) = (idx10 - 1) / Fs;
    force_at10mN(i) = thisForce(idx10);

    % One sine-wave cycle around the 10 mN crossing
    samplesPerCycle = round(Fs / thisFreq);
    halfCycle = round(samplesPerCycle / 2);

    cycleStart = max(vibStartSample, idx10 - halfCycle);
    cycleEnd = min(vibEndSample, idx10 + halfCycle);

    oneCycleLength = thisLength(cycleStart:cycleEnd);

    % Peak length near 10 mN
    lengthPeak_at10mN(i) = max(oneCycleLength);

    % Peak - baseline mean
    lengthPeakMinusBaseline_at10mN(i) = ...
        lengthPeak_at10mN(i) - lengthBaselineMean(i);
end
% Average peak - baseline length at 10 mN by frequency

lengthPeakBase_10mN_eachFreq = nan(numel(frequency), repetitions);
lengthPeakBase_10mN_mean = nan(numel(frequency),1);
lengthPeakBase_10mN_sem = nan(numel(frequency),1);

for j = 1:numel(frequency)

    idx = find(Findex == j);

    values = lengthPeakMinusBaseline_at10mN(idx);

    lengthPeakBase_10mN_eachFreq(j,1:numel(values)) = values;

    lengthPeakBase_10mN_mean(j) = mean(values, 'omitnan');
    lengthPeakBase_10mN_sem(j) = std(values, 'omitnan') / sqrt(sum(~isnan(values)));
end
%
figure;

errorbar(frequency, lengthPeakBase_10mN_mean, lengthPeakBase_10mN_sem, ...
    'o-', 'LineWidth', 1.5, 'MarkerSize', 6);

xlabel('Frequency (Hz)');
ylabel('Length peak - baseline mean at 10 mN');
title('Length peak above baseline when force reaches 10 mN');
xticks(frequency);
box off;
figure;

scatter(sineFrequency, lengthPeakMinusBaseline_at10mN, 50, 'filled');

xlabel('Frequency (Hz)');
ylabel('Length peak - baseline mean at 10 mN');
title('Individual trials');
xticks(frequency);
box off;

%%
force = reshape(data(:,3), ...
    [numel(data(:,3))/length(sineFrequency), length(sineFrequency)]);

lengthTrace = reshape(data(:,2), ...
    [numel(data(:,2))/length(sineFrequency), length(sineFrequency)]);

[frequency, ~, Findex] = unique(sineFrequency);

plotDown = 20;

t = (0:size(force,1)-1) / Fs;
tPlot = t(1:plotDown:end);

nFreq = numel(frequency);
nCols = 2;
nFreqRows = ceil(nFreq / nCols);
nRows = nFreqRows * 2;

figure;
set(gcf, 'Position', [100, 50, 1400, 900]);

vibStartSample = round(baseline * Fs) + 1;
vibEndSample = round((baseline + vibTime) * Fs);

baselineStartSample = 1;
baselineEndSample = round(baseline * Fs);

for j = 1:nFreq

    idx = find(Findex == j);   % trials for this frequency
    thisFreq = frequency(j);

    freqRow = ceil(j / nCols);
    freqCol = mod(j-1, nCols) + 1;

    forceRow = (freqRow - 1) * 2 + 1;
    lengthRow = forceRow + 1;

    forceSubplotIdx = (forceRow - 1) * nCols + freqCol;
    lengthSubplotIdx = (lengthRow - 1) * nCols + freqCol;

    %% -------------------------
    % Force plot
    % -------------------------
    subplot(nRows, nCols, forceSubplotIdx)

    plot(tPlot, force(1:plotDown:end, idx) * 50, 'LineWidth', 0.5)
    hold on

    xline(baseline, 'r--', 'LineWidth', 1)
    xline(baseline + vibTime, 'g--', 'LineWidth', 1)

    title(sprintf('%d Hz force', thisFreq))
    ylabel('Force (mN)')
    xlim([0 baseline + vibTime + decayTime])
    box off
    set(gca, 'XTickLabel', [])

    %% -------------------------
    % Length Peak - BaselineMean per sine cycle
    % -------------------------
    subplot(nRows, nCols, lengthSubplotIdx)
    hold on

    samplesPerCycle = round(Fs / thisFreq);

    for k = 1:numel(idx)

        trialIdx = idx(k);
        thisLength = lengthTrace(:, trialIdx);

        % Baseline mean for this trial
        baselineMean = mean(thisLength(baselineStartSample:baselineEndSample), ...
            'omitnan');

        cycleStart = vibStartSample;

        peakMinusBaseVals = [];
        peakMinusBaseTimes = [];

        while cycleStart + samplesPerCycle - 1 <= vibEndSample

            cycleEnd = cycleStart + samplesPerCycle - 1;

            oneCycleLength = thisLength(cycleStart:cycleEnd);

            % Peak - baseline mean
            thisPeakMinusBase = max(oneCycleLength) - baselineMean;

            cycleCenter = round((cycleStart + cycleEnd) / 2);
            cycleCenterTime = (cycleCenter - 1) / Fs;

            peakMinusBaseVals(end+1,1) = thisPeakMinusBase;
            peakMinusBaseTimes(end+1,1) = cycleCenterTime;

            cycleStart = cycleStart + samplesPerCycle;
        end

        plot(peakMinusBaseTimes, peakMinusBaseVals, ...
            '-o', 'LineWidth', 0.8, 'MarkerSize', 3)
    end

    xline(baseline, 'r--', 'LineWidth', 1)
    xline(baseline + vibTime, 'g--', 'LineWidth', 1)

    title(sprintf('%d Hz length Peak-BaselineMean', thisFreq))
    ylabel('Peak - baseline')
    xlim([0 baseline + vibTime + decayTime])
    box off

    if freqRow == nFreqRows
        xlabel('Time (s)')
    else
        set(gca, 'XTickLabel', [])
    end
end