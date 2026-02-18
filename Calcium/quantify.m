function [digitROI, responseROI] = quantify(normDeltaF,filename,nStd)

% this function is to quantify the calcium signal by standard devivation
% and other criterias to exclude noise

[m, nNeuron] = size(normDeltaF);

if m < 400
    baseline = normDeltaF(1:90,:);
elseif contains(filename, 'peltier')
    baseline = normDeltaF(1:200,:);
else
    baseline = normDeltaF(1:100,:);
end

% get the average std for the less noisy ROI is to get the real noise
% level, because for stimulations like pinch or heat, the response is big, so Std is
% big, and response might be only one or two times larger than std
stdROI_temp = nonzeros(sort(std(baseline)));

if nNeuron>100
    stdROI = mean(stdROI_temp(1:15));
else
    stdROI = mean(stdROI_temp);
end

% stdROI1 = std(normDeltaF);

meanROI = mean(normDeltaF);

diffROI = zeros(m,nNeuron);
% diffROI is to calculate the difference between the normDeltaF and meanROI
% for each ROI seperately

for i = 1:nNeuron
    diffROI(:,i) = normDeltaF(:,i) - meanROI(i);
end

digitROI = zeros(m,nNeuron);
digitROI(diffROI > (stdROI*nStd)) = 1;
% figure,imagesc(~digitROI'),colormap(gray);

if 0
    
    if contains(filename, "pinch") || contains(filename, "heat") || contains(filename, "cool")
        % the stimulation of pinch or temperature could give response at the
        % start or near the end. The code for indentation or brush might
        % recoginze this as baseline drifting. If we still want to exclude the
        % baseline drifting, findpeaks is used.
        responseROI = find(sum(digitROI));
        y = zeros(1,length(responseROI));
        
        for i = 1:length(responseROI)
            y(i) = sum(findpeaks(normDeltaF(:,responseROI(i)),'MinPeakProminence', 0.));
        end
        
        responseROI = responseROI(y);
        
    elseif contains(filename, "brush") || contains(filename, "stroke") || contains(filename, "stoke")
        responseROI = find(sum(digitROI));
        y = zeros(1,length(responseROI));
        
        for i = 1:length(responseROI)
            y(i) = sum(findpeaks(normDeltaF(:,responseROI(i)),'MinPeakProminence', 0.05));
        end
        
        responseROI = responseROI(y);
        
    else
        % this is to exclude the baseline drifting. Each ROI is divided into 5
        % segments, if the "response" is only in first two segement or the last
        % two segments, excluded that.
        nSeg = 5;
        digitSeg = [];
        unitSeg = floor(m/nSeg);
        for i = 1:nSeg
            digitSeg (:,:,i) = digitROI(unitSeg * (i-1) + 1 : unitSeg * i,:);
        end
        
        meanSeg = [];
        for i = 1:nSeg
            meanSeg (:,i) = mean(digitSeg(:,:,i));
        end
        meanSeg (meanSeg > 0) = 1;
        
        for i = 1:nNeuron
            if sum(meanSeg(i,:)) ==1
                if meanSeg(i, 1) == 1 || meanSeg(i,end) ==1
                    meanSeg(i,:) = 0;
                end
            elseif sum(meanSeg(i,:)) == 2
                if meanSeg(i, 1) + meanSeg(i, 2) == 2 || meanSeg(i, end-1) + meanSeg(i, end) == 2
                    meanSeg(i,:) = 0;
                end
            else
                meanSeg(nNeuron,:) = meanSeg(nNeuron,:);
            end
        end
        
        
        responseROI = find(sum(meanSeg'));
    end
    
    newdigitROI = zeros(m,nNeuron);
    newdigitROI(:,responseROI) = digitROI(:,responseROI);
    figure,imagesc(~newdigitROI'),colormap(gray)
else
    responseROI = find(sum(digitROI(size(baseline, 1)+1:end,:)));
    figure,imagesc(~digitROI'),colormap(gray)
end
end