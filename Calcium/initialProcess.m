function [normDeltaF] = initialProcess(path, filename, fps, varargin)
% the function transfer the CVS file that contain raw intensity data into
% change of calcium signal (deltaF/F), and plot a heatmap showing the
% response. 
% Bleach correction is optional. If prefer bleach correction,
% RobustDetrend.m is used
% (https://www.mathworks.com/matlabcentral/fileexchange/69303-robustdetrend).
% varargin{1} should be 'bleach correction'; 
% if there is varargin{2}, it should be the polynome order limit;
% and varargin{3} should be percentage confidence for over the null hypothesis


A1 = table2array(readtable(fullfile(path, filename)));
% A1 = A1(:, 2:end);
%sometimes the table contains the frame number column as the first column,
%but sometimes it doesn't have this column. This is for this two occasions
[~, n] = size(A1);

%A1 = A1(50:end,:);

if mod(n,4) == 0 
    % the csv file has 4 columns, the first column is intensity, the rest are area
    % of ROI and X Y location of the ROI center
    F = A1(:,2:4:end); 
    %X = A1(1,3:4:end);
    %Y = A1(1,4:4:end);
elseif mod(n,4) ==1
    F = A1(:,3:4:end);
    %X = A1(1,4:4:end);
    %Y = A1(1,5:4:end);
else
    error('something wrong with the table');
end

[m, nNeuron] = size(F); % m is number of frames

% sometimes the ROI from one FOV could be outside of another FOV, so NAN
% could appear in the sheet. We change "NAN" to 0.001.
F(isnan(F)) = 0.001;

% the ROIs from the very border could be dirty, find those and fill it with
% 0.001
% a = find(X<5);
% b = find(Y<5);
% c = unique(ceil(find(F==0)/m));
% F(:,unique([find(X<5) find(Y<5) unique(ceil(find(F==0)/m))'])) = 0.001;

% some ROIs might be very dim for some stimuli and have very low
% intensity, so noise will greatly influence the quality, so fill those
% ROIs with 0.001
noiseThreshold = 4; % generally 4 works for most videos without background substraction
F(:, mean(F,1)< noiseThreshold ) = 0.001;
% Fsort = sort(F);
% midF = mean(Fsort(end-100:end,:));
% midF = mean(Fsort(1:100,:));
midF1 = median(F); % either choose the median value
baseF = mean(F(1:100,:)); % or choose the average of the baseline (usually from 1-10s except for indention or vibration)
midF = min([midF1;baseF]); % choose the smaller value from the median or mean of baseline
% midF = baseF;
deltaF = zeros(m,nNeuron);
normDeltaF = zeros(m,nNeuron);
% filter_normDeltaF = zeros(m,nNeuron);

if nargin > 3
    if nargin == 6
        n = varargin{2};
        conflvl = varargin{3};
    elseif nargin == 4
            n = 6;
            conflvl = 0.975;
    end
    if isempty(ver('Wavelet'))
        error('Please install the Wavelet Toolbox first to do the bleach correction')
    end
    
    for i = 1:nNeuron
        deltaF (:,i) = F(:,i) - midF(i);
        temp = deltaF(:,i) / midF(i);
        % bleach correction
        try
            [~,normDeltaF(:,i),~] = RobustDetrend(temp,n,conflvl);
        catch
            warning(['Problem with bleach correction for Cell ',num2str(i)]);
            deltaF (:,i) = F(:,i) - midF(i);
            normDeltaF(:,i) = deltaF(:,i) / midF(i);
        end
        % filter_normDeltaF(:,i) = medfilt1(normDeltaF(:,i));
    end
else
    for i = 1:nNeuron
        deltaF (:,i) = F(:,i) - midF(i);
        normDeltaF(:,i) = deltaF(:,i) / midF(i);
    end
end

% figure,imagesc(normDeltaF(20:end,:)'),colormap(flipud(jet)),
% figure, imagesc(normDeltaF(1:800,:)'),colormap(turbo),
figure, imagesc(normDeltaF(1:end,:)'),colormap(turbo),
% axis off
colorbar
% set(gcf,'Visible','on')
% play with the x axis ticks and labels
if m <3000
    interval = 200; 
else
    interval = ceil(m/800)*100; 
end
xticks(interval:interval:m);
timelabel = strsplit(num2str(interval/fps:interval/fps:m/fps));
xticklabels(timelabel); xlabel("time (s)")
% play with the colorbar scale
Max = sort(max(normDeltaF)); 
if nNeuron>4
    MaxLimit = mean(Max(end-4:end));
else
    MaxLimit = max(Max);
end

if MaxLimit > 1.5 || MaxLimit < 0.2
    Limit = 1.5;
else
    Limit = MaxLimit;
end

% Limit = 1.5;
caxis([0 Limit])

% pathparts = strsplit(path,filesep);
% mouseID = pathparts{end-1};
% name = [filename(1:end-4), '_', mouseID];
% t = title(name);
% set(t,'Interpreter','none')

end

