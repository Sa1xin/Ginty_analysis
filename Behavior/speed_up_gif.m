[img, map] = imread("C:\Users\sallyx\HMS Dropbox\Jia Yin Xiao\ForDavid_20250714\WT_chemical.gif", 'Frames', 'all');
info = imfinfo("C:\Users\sallyx\HMS Dropbox\Jia Yin Xiao\ForDavid_20250714\WT_chemical.gif");

factor = 2;   % 2× faster

for k = 1:length(info)
    info(k).DelayTime = info(k).DelayTime / factor;
end

imwrite(img, map, "C:\Users\sallyx\HMS Dropbox\Jia Yin Xiao\ForDavid_20250714\WT_chemical_speedup.gif", 'gif',"DelayTime", 0.0011);