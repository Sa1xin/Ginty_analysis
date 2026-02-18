function [threshold,Amp] = threshAndAmp(goodROI,responseROI,spikeNum, spike,forceSweep)
%THRESHANDAMP Summary of this function goes here
%   Detailed explanation goes here

[~, ROIindex] = ismember(goodROI, responseROI);

goodSpike = spikeNum(ROIindex, 2:2:end, :);
% [A, B] = find(goodSpike);
% this is to detect threshold

threshold = zeros(length(goodROI), size(goodSpike,3));
for i = 1:length(goodROI)
    for j = 1:size(goodSpike,3)
        temp  = find(goodSpike(i, :, j));
        if temp
            if forceSweep(1:length(forceSweep)/2) == forceSweep(length(forceSweep)/2+1:end)
                % earlier experiments have two series of forcesteps in one sweep
                temp(temp>length(forceSweep)/2) = temp(temp>length(forceSweep)/2) - length(forceSweep)/2;
                temp = sort(temp);
            end
            threshold(i,j) = forceSweep(temp(1));
        end
    end
end

%% inspect the threshold data
figure, bar(threshold)
title('response threhold for indentation')
ylim([0, max(forceSweep)])
xlabel('cell')
ylabel('force(mN)')


%% Process the Amplitude
spikeAmp = spike(:,:,1);
tempSpikeNum = reshape(spikeNum,[size(spikeNum,1), size(spikeNum,2) * size(spikeNum,3)]);
temp = cumsum(tempSpikeNum, 2);
spikeNumAmp = reshape(temp, size(spikeNum));
goodAmp = spikeNumAmp(ROIindex, 2:2:end,:);
Amp = zeros(size(goodAmp));
for i = 1:size(goodAmp,1)
    for j = 1:size(goodAmp,2)
        for k = 1:size(goodAmp,3)
            if goodSpike(i, j, k) 
               tempIndex =  (goodAmp(i, j, k) - goodSpike(i, j, k) + 1): goodAmp(i,j,k) ;
               % there could be more than one spike for each step
               % indentation, so take the max response
               Amp(i,j,k) = max(spikeAmp((tempIndex),ROIindex(i)));
            end
        end
    end
end

%% inspect the Amplitude data
% Amp2D = reshape(Amp, [size(Amp,1),size(Amp,2)*size(Amp,3)]);
figure,
set(gcf,'Visible','on')
for i = 1:size(Amp,3)
    subplot(size(Amp,3), 1, i),
    bar(Amp(:,:,i));
    xlabel('cell')
    ylabel('deltaF/F')
    title(['Sweep ', num2str(i)])
    set(gcf, 'Position', [50, 50, 1200, 700])
end
end

