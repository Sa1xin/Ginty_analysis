function Cell_freq_forceThreshold = Align_forceSine_calcium(Cellnum, Calcium_freq,cfg,vibFolder,nStd,minConsec,freqTop)
% ---------- SETTINGS ----------
if nargin < 5 || isempty(nStd)
    nStd = 5;
end

if nargin < 6 || isempty(minConsec)
    minConsec = 10;
end

if nargin < 7 || isempty(freqTop)
    freqTop = 10;
end                      % force panel frequency

Fs = cfg.Fs;
cameraTriggerRate = cfg.cameraTriggerRate;
baseline = cfg.baseline;
sweepDuration = cfg.sweepDuration;
decayTime = cfg.decayTime;
voltageConversion = cfg.voltageConversion;
sineAmplitude = cfg.sineAmplitude(:)';   % mN levels
sineFrequency = cfg.sineFrequency(:);    % Hz
sineBoth = cfg.sineBoth;                 % [amp(V) freq(Hz)] per sweep
recForceMat = cfg.recForceMat;           % samplesPerSweep × numSweeps

baseForceFrames = round(Fs * baseline);

% Compute baseline mean for each sweep (1 × numSweeps)
baselineMeanForce = mean(recForceMat(1:baseForceFrames, :), 1, 'omitnan');

% Subtract column-wise
recForceMat = recForceMat - baselineMeanForce;

triggerDuration = baseline + sweepDuration + decayTime;
numF   = numel(sineAmplitude);
numFreq = numel(sineFrequency);

% Convert force levels to the same units used in sineBoth(:,1) (Volts)
forceLevelsV = (sineAmplitude/ voltageConversion);  % column vector

% Per-segment sample counts (NO interSweepInterval)
nForceSeg = round(Fs * triggerDuration);
nCaSeg    = round(cameraTriggerRate * triggerDuration);

% time within one force segment
tFseg = (0:nForceSeg-1)/Fs;
tCseg = (0:nCaSeg-1)/cameraTriggerRate;

% Useful markers (within each segment)
stimOn  = baseline;
stimOff = baseline + sweepDuration;

% ---------- RESHAPE YOUR DATA INTO SWEEPS ----------
% NOTE: your recForceMat includes ISI in each sweep (samplesPerSweep),
% so we'll cut only the first nForceSeg samples from each sweep.
% For calcium, you already have Calcium_freq columns concatenated;
% we reshape to [framesPerSweep × sweepsPerFreq] then take first nCaSeg.

% Force: continuous -> sweeps
% recordedForce is your continuous force vector (V)
% recForceMat is [samplesPerSweep × numSweeps]
% (you already computed these earlier)
% recForceMat = reshape(recordedForce, samplesPerSweep, numSweeps);

% Calcium: you have Calcium_freq = [NframesConcatenated × numFreq]
% where each column stacks sweeps for that frequency.
% Need sweepsPerFreq:
sweepsPerFreq = numel(find(sineBoth(:,2) == sineFrequency(1))); % should be nRepeat*numF

framesPerSweep = size(Calcium_freq,1) / sweepsPerFreq;
framesPerSweep = round(framesPerSweep);

baseFrames = round(cameraTriggerRate * baseline);
stimStartFrame = baseFrames + 1;
stimEndFrame   = round((baseline + sweepDuration) * cameraTriggerRate);

globalMax = max(Calcium_freq,[],'all');
Cell_freq_forceThreshold = NaN(numel(sineFrequency),1);

% ---------- FIGURE ----------
fi1 = figure();
tl = tiledlayout(numFreq+1, 1, 'TileSpacing','compact', 'Padding','compact');

% ===== TOP: FORCE traces for freqTop, all forces, repeats overlaid =====
topIdx = find(sineFrequency == freqTop, 1);
if isempty(topIdx), error('freqTop not in sineFrequency'); end

nexttile
hold on

for fIdx = 1:numF
    aV = forceLevelsV(fIdx);

    % Find sweep indices in the GLOBAL order for this (freq, force)
    sweepIdx = find(sineBoth(:,2)==freqTop & sineBoth(:,1)==aV); % length should be nRepeat

    % For each repeat, plot the segment placed in this force-slot
    x0 = (fIdx-1)*triggerDuration;

    for r = 1:numel(sweepIdx)
        y = recForceMat(1:nForceSeg, sweepIdx(r))*voltageConversion;   % take only triggerDuration (no ISI)

        % baseline correct (optional, comment out if you don't want it)
        % baseN = round(Fs*baseline);
        % y = y - mean(y(1:baseN), 'omitnan');

        p = plot(x0 + tFseg, y, 'LineWidth', 1);
        p.Color(4) = 0.25;
    end

    % Force-segment boundary
    xline(x0, ':', 'Color', [0 0 0 0.2]);

    xCenter = x0 + triggerDuration/2;

    % Place mini title slightly above the data
    yTop = max(sineAmplitude)*1.05;   % after you compute forceMax

    text(xCenter, yTop, sprintf('%d mN', sineAmplitude(fIdx)), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontSize',10, ...
        'FontWeight','bold');
    %
    % % Shade stim window in this segment
    % yl = ylim;
    % patch([x0+stimOn x0+stimOff x0+stimOff x0+stimOn], [yl(1) yl(1) yl(2) yl(2)], ...
    %     [1 1 0], 'FaceAlpha', 0.10, 'EdgeColor','none');
end

xlim([0, numF*triggerDuration])
ylim([0, max(sineAmplitude)*1.05])
ylabel('Force (mN)')  % or (mN) if you multiply by voltageConversion

%hTitle = title(sprintf('Force traces (all forces) at %d Hz', freqTop));
% hTitle.Units = 'normalized';
% hTitle.Position(2) = 1.2;

hold off


% ===== BELOW: CALCIUM per frequency, all forces, repeats overlaid =====
for fi = 1:numFreq
    fHz = sineFrequency(fi);

    % Reshape calcium sweeps for this frequency
    Cmat = reshape(Calcium_freq(:,fi), framesPerSweep, sweepsPerFreq);

    % Map from sweeps within this frequency column to global sweep indices:
    idxThisFreqGlobal = find(sineBoth(:,2) == fHz);   % length = sweepsPerFreq

    nexttile
    hold on

    for fIdx = 1:numF

        aV = forceLevelsV(fIdx);

        % Which columns of Cmat correspond to this force?
        cols = find(sineBoth(idxThisFreqGlobal,1) == aV);  % length should be nRepeat

        meanTrace = mean(Cmat(:, cols), 2);
        baselineMean = mean(meanTrace(1:baseFrames));
        baselineStd  = std(meanTrace(1:baseFrames));
        threshold = baselineMean + nStd*baselineStd;

        above = meanTrace(stimStartFrame:stimEndFrame) > threshold;
        win = ones(minConsec,1);
        c = conv(double(above(:)), win, 'valid');   % length = L-minConsec+1
        k = find(c >= minConsec, 1, 'first');       % index in 'valid' conv output

        if ~isempty(k)
            crossIdx = k;   % conv 'valid' index corresponds to start position in seg
            sweepIdxGlobal = idxThisFreqGlobal(cols);
            stimStartSamp = round(Fs*baseline) + 1;
            stimEndSamp   = round(Fs*(baseline + sweepDuration));
            Fstim = recForceMat(stimStartSamp:stimEndSamp, sweepIdxGlobal) * voltageConversion;
            peakPerRepeat = max(Fstim, [], 1);
            ActualForce = mean(peakPerRepeat);
            if isnan(Cell_freq_forceThreshold(fi))
                Cell_freq_forceThreshold(fi) = round(ActualForce);
            else
                Cell_freq_forceThreshold(fi) = min(Cell_freq_forceThreshold(fi), round(ActualForce));
            end
            if Cell_freq_forceThreshold(fi) > max(sineAmplitude)
                Cell_freq_forceThreshold(fi) = NaN;
            end
        else
            crossIdx = NaN;
        end

        if ~isempty(crossIdx)
            crossFrame = stimStartFrame + crossIdx - 1;
            crossTime = (crossFrame - 1) / cameraTriggerRate;  % seconds
        else
            crossTime = NaN;
        end

        x0 = (fIdx-1)*triggerDuration;
        for r = 1:numel(cols)
            y = Cmat(1:nCaSeg, cols(r));  % take only triggerDuration portion

            % baseline correct
            baseN = round(cameraTriggerRate*baseline);
            y = y - mean(y(1:baseN), 'omitnan');

            p = plot(x0 + tCseg, y, 'LineWidth', 1);
            p.Color(4) = 0.25;
        end

        % Force-segment boundary
        xline(x0, ':', 'Color', [0 0 0 0.15]);
        % Indicator of activity
        if ~isnan(crossTime)
            xline(x0 + crossTime, '--k', 'LineWidth', 1.5);
        end

        % Shade stim window
        % yl = ylim;
        % patch([x0+stimOn x0+stimOff x0+stimOff x0+stimOn], [yl(1) yl(1) yl(2) yl(2)], ...
        %     [1 1 0], 'FaceAlpha', 0.10, 'EdgeColor','none');
        ylim([0, globalMax*1.05]);
    end


    xlim([0, numF*triggerDuration])
    ylabel('\DeltaF/F')
    title(sprintf('%d Hz', fHz))
    hold off
end
ax = findall(gcf, 'Type', 'axes');
set(ax, 'XColor', 'none')
set(gcf,'Units','pixels','Position',[100 100 1000 1000])
%title(tl, 'All forces concatenated (low→high); repeats overlaid within each force & frequency')
figurename = fullfile(vibFolder,[sprintf('Neuron%d', Cellnum),'_ForceAligned.pdf']);
exportgraphics(fi1, figurename,"Resolution",300);


fi2 = figure();
hold on;
NR_value = max(sineAmplitude) + 5;
y_ticks = [sineAmplitude, NR_value];
x_ticks = sineFrequency;
dataNR = Cell_freq_forceThreshold;
dataNR(isnan(dataNR)) = NR_value;
scatter(sineFrequency, dataNR, 60, 'blue', 'filled');
plot(sineFrequency, dataNR, '-', 'Color', 'blue','HandleVisibility', 'off');
yticks(y_ticks)
yticklabels([string(sineAmplitude),'NR']) 
xticks(x_ticks)
xticklabels(string(x_ticks)) 
ylim([0,NR_value])
ylabel('Force (mN)')
xlabel('Frequency (Hz)')
title('force frequency curve')
hold off;
figurename2 = fullfile(vibFolder,[sprintf('Neuron%d', Cellnum),'_ForceFrequencyCurve.pdf']);
exportgraphics(fi2, figurename2,"Resolution",300);
end