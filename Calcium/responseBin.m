function [spikeNum, edgeTime] = responseBin(nSweep, nStep, cameraTrigger, force, spike, fps, Fs, binMethod)
%RESPONSEBIN Summary of this function goes here
%   Detailed explanation goes here

%%  Reconstruct the time sequence of indentation
nChange = nStep * 2 * nSweep;
% "auto" an safe way to avoid human error, but it's sometimes tricky
% for the algorithm to work. If so, "manual" will be used)
    
if strcmp(binMethod, 'auto')
    % edgeForce is the change points in the force trace, downsample the force
    % is easier for the findchangepts function to work
    downSampleIndex  = 10;
    edgeForce = findchangepts(downsample(force, downSampleIndex), 'MaxNumChanges',nChange) .*downSampleIndex;
    % edgeGap is an array that contains the indentation time step and intervals in seconds
    edgeGap = round(diff(edgeForce)/1000) * 1000 / Fs;
    
    % nbins is the non-repeating elements in edgeGap. nbin should
    % contain 3 elements
    [nRepeats, bins] = hist(edgeGap, unique(edgeGap)); %#ok<HIST>
    [bins, binOrder] = sort(bins);
    nRepeats = nRepeats(binOrder);
    
    if nRepeats(1) ~= nStep* nSweep || nRepeats(3) ~= nSweep-1
        error('something wrong with the automatic edge finding');
    end
    
    % find the indentation time point
    figure,plot(force)
    hold on
    for i = 1:nChange
        y = -0.1:0.1:max(force);
        x = zeros(1,length(y));
        x (:) = edgeForce(i);
        plot(x,y,'g')
    end
    
    indentStep = bins(1);
    indentInterval = bins(2);
    indentSweepInterval = bins(3) - 2 * indentInterval;
    
    % now reconstruct time edges consistent with calcium imaging data, as
    % data between the sweep was not collected. edgeGapCam is the time relative to the
    % camera
    edgeGapCam = [];
    
    for i = 1:length(edgeGap)
        if edgeGap(i) == bins(3)
            % between sweeps, two indentIntervels are mixed with indentSweepIntervals
            edgeGapCam = [edgeGapCam, indentInterval, indentInterval];
        else
            edgeGapCam = [edgeGapCam, edgeGap(i)];
        end
    end
    
    edgeGapCam = [indentInterval, edgeGapCam, indentInterval];
    % the orginal window for indent is 0.5s, calcium signals might not be so
    % accurate, so increase the window to 1s
    windowExtra = 2;
    for i = 1:length(edgeGapCam)-1
        if edgeGapCam (i) == bins(1) % bins(1) is the time for indent step
            edgeGapCam(i) = edgeGapCam(i) + windowExtra;
            edgeGapCam(i+1) = edgeGapCam(i+1) - windowExtra;
        end
    end
    
elseif strcmp(binMethod, 'manual')
    indentTime = 0.5; % in sec
    indentInterval = 6 ; % in sec
    baseline = 2; % in sec
    edgeGapCamTemp = repmat([baseline, indentTime, indentInterval],1, nStep);
    edgeGapCam = repmat(edgeGapCamTemp, 1, nSweep);
    % the orginal window for indent is 0.5s, calcium signals might not be so
    % accurate, so increase the window to 1s
    windowExtra = 2;
    for i = 1:length(edgeGapCam)-1
        if edgeGapCam (i) == indentTime % bins(1) is the time for indent step
            edgeGapCam(i) = edgeGapCam(i) + windowExtra;
            edgeGapCam(i+1) = edgeGapCam(i+1) - windowExtra;
        end
    end    
end

% camera trigger started later than recording of force or length, so use "triggerExtra" to extract that part
triggerExtra = find(cameraTrigger==1);
triggerExtra = triggerExtra(1) / Fs;

edgeGapCam(1:length(edgeGapCam)/3:end) = edgeGapCam(1:length(edgeGapCam)/3:end) - triggerExtra;
edgeGapCam(end:-length(edgeGapCam)/3:1) = edgeGapCam(end:-length(edgeGapCam)/3:1) - triggerExtra;

% edgeTime can be used as bins for indentation response
edgeTime = [0.1, cumsum(edgeGapCam)];

%% bin it
spikeTime = spike(:, :, 2) / fps;

% spikeNum = zeros(length(responseROI), length(edgeGap));
spikeNum = [];
for i = 1: size(spike,2) % size(spike,2) is the number of crude ROIs
    spikeNum(i, :) = histcounts(spikeTime(:,i), edgeTime);
end

% spikeNum = [zeros(size(spike,2), 1), spikeNum];
spikeNum = reshape(spikeNum, [size(spike,2), (length(edgeTime)-1)/nSweep, nSweep]);

end

