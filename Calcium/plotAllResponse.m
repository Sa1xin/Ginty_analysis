function spike = plotAllResponse(responseROI,normDeltaF, path, filename, thresh,fps, varargin)
% responseROI, normDeltaF, filename, thresh are the same with variable names
% varagin {1} = "peakLabel"; varagin{2} = true or false. These two are
% dispensable. If not defined, peak won't be labeled.
% varagin {3} = "NumFig"; varagin{4} = number of figures; If there are more than 100 cells,
% plotting them all might take too long, so set the number of figures below
% 100; varagin{5} = "save", varargin{6} = true or false, whether to save the figure or not.

responseROI = nonzeros(responseROI);
[m, ~] = size(normDeltaF);
spike = zeros(m,length(responseROI),2);
% the spike contains the amplitude and timing of the peaks

% if contains(filename, "pinch") || contains(filename, "heat") || contains(filename, "press")
%     peakProminence = 0.4;
% else
%     peakProminence = thresh;
% end

peakProminence = thresh;

% determine the number of figures
if nargin == 12
    nPlot = min(varargin{4}, numel(responseROI));
else
    nPlot = min(31, responseROI);
end

if varargin{6}
    foldername = fullfile(path,filename(1:end-4));
    if isfolder(foldername)
        delete([foldername,'\*'])
    else
        mkdir(foldername);
    end        
end

for i = 1:nPlot
    figure,
    if varargin{1} == 'peakLabel' && varargin{2}
        % if you want to find peaks
        [y1, y2] = findpeaks(normDeltaF(:,responseROI(i)),'MinPeakProminence',peakProminence);
        % for indentation stimuli, the number calcium spike is usually
        % fewer than 30. Otherwise, the findpeaks functions might analyze a noisy
        % trace and give many spikes
        if ~ (contains(filename,"indent") && length(y1) > 600)
            spike(1:length(y1),i,1) = y1; % y1 is the amplitude
            spike(1:length(y1),i,2) = y2; % y2 is the corresponding frame number
            plot(normDeltaF (:,responseROI(i)));
            hold on
            plot(y2, y1*1.3,"v");
            % findpeaks(normDeltaF(:,responseROI(i)),'MinPeakProminence',peakProminence);
            % this is for ploting
            title(['cell ',num2str(responseROI(i))]);
            ax = gca; ax.FontSize = 8;
            pbaspect([5 1 1]);
            set(gcf, 'Position', [0, 0, 750, 150]);
            grid off
            box off
        end
    else
        p = plot(normDeltaF (:,responseROI(i)));
        if m<1000
            set(p, 'LineWidth',1);
            % if number of frames is smaller than 1000, then make the line thicker
        end
        title(['cell ',num2str(responseROI(i))]);
        ax = gca; ax.FontSize = 8; pbaspect([5 1 1])
        if m <3000
            interval = 200;
        else
            interval = ceil(m/800)*100;
        end
        xticks(interval:interval:m);
        timelabel = strsplit(num2str(interval/fps:interval/fps:m/fps));
        xticklabels(timelabel); xlabel("time (s)")
        set(gcf, 'Position', [0, 0, 750, 150])
        grid off
        box off
    end
    if varargin{6} % if trying to save the figures
        figname = ['neuron_', num2str(responseROI(i)), '_', filename(1:end-4), '.png'];
        saveas(gcf,fullfile(foldername, figname));
    end
end
end

