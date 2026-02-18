function indentAlign(numSweeps, normDeltaF, path, filename, forceSplit)


%% get the interested cell
nCell = input('the neuron you are interesed in?  \n ');

[~,normDeltaFncell,~] = RobustDetrend(normDeltaF(:,nCell),6,0.975);
m = length(normDeltaFncell);
nUnit = floor(m/numSweeps);

%% split the calcium trace by sweeps
Split = zeros(nUnit, numSweeps);

for i = 1:numSweeps
    Start = nUnit * (i-1) + 1;
    End = Start+nUnit-1;
    if End > m
        Split(1:m-Start+1,i) = normDeltaFncell(Start:end);
    else
        Split(:,i) = normDeltaFncell(Start:Start+nUnit-1);
    end
end

gap = 0.8 ;
for i = 1:numSweeps
    Split(:,i) = Split(:,i) + max(normDeltaFncell) * gap * (numSweeps-i);
end


%% Do the plotting
fh = figure;
set(gcf,'Visible','on')

sfh1 = subplot(211); p = plot(forceSplit(:,1));  set(p,'Color','black');
%set(p,'LineWidth',1) %set(gca,'xtick',[]);
set(sfh1,'xcolor',[1 1 1]); xlim([0 size(forceSplit,1)])
if max(forceSplit(:)) > 1.4 && max(forceSplit(:)) <1.6 % that is for the normal 75 mN
    ylim([-0.2 2])
    yticks([0.5:0.5:2]);
    yticklabels(["25" "50" "75" "100"]);
elseif  max(forceSplit(:)) > 1.6
    ylim([-0.2 3.2])
    yticks([0.5:0.5:3]);
    yticklabels(["25" "50" "75" "100" "125" "150"]);
else
    ymax = (ceil( max(forceSplit(:)) *10 ))/10 + 0.1;
    ylim([-0.1 0.9])
    yticks([0.2:0.2:ymax])
    yticklabels(["10" "20" "30" "40"]);
end

%axis off
ylabel("indentation (mN)"); set(gcf,'color','w');

sfh2 = subplot(212);

if 1
    plot(Split,'LineWidth',1);
else
    for i = 1: numSweeps
        findpeaks(Split(:,i), 'MinPeakProminence',0.1);
    end
end

maxy = max(Split(:)); xlim([0,nUnit]);
ylim([min(normDeltaFncell(:))-0.15, maxy + 0.1]); set(gca,'ycolor',[1 1 1]);
% yticks([0 gap gap*2])
% yticklabels(["trial3" 'trial2' "trial1"]); % set(gca,'YTick',[])
set(sfh2,'XTick',[200:200:700]); set(sfh2,'xticklabels',["20" "40" "60"]);
xlabel("time (s)") % axis off
sfh2.Position = sfh2.Position + [0 0 0 0.13];

hold on
if max(normDeltaFncell)/4 > 0.1
    scaleLength = floor(max(normDeltaFncell)/4 * 10) /10;
else
    scaleLength = 0.1;
end

x = [0.1 0.1]; y = [maxy-scaleLength maxy];
plot(x, y, 'b', 'linewidth',1);
textStr = [' ', num2str(scaleLength), ' \DeltaF/F'];
text(x+1,[maxy-scaleLength/2 maxy-scaleLength/2], textStr)

sgtitle(strcat("Neuron ",num2str(nCell)));


%% Then save the figure in a sub-directory
indentFolder = strcat(path,filename(1:end-4), "_aligned") ;
if ~exist(indentFolder, 'dir')
    mkdir(indentFolder);
end
indentFigure = strcat(indentFolder,"\Neuron",num2str(nCell),".jpg");
saveas(fh,indentFigure);

end