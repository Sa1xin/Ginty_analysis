function fileList = remainFile(spikeStructName,fileList)
%NEWFILE Summary of this function goes here
%   Detailed explanation goes here
    load(spikeStructName);
    field  = strings(1,length(fileList));
    for i = 1:length(fileList)
        field(i) = fileList(i).name ((1:end-4));
    end
    
    for i = 1:length(field)
        if contains(field(i),"frey")  % the fieldname can't start with number
            field(i) = erase(field(i), "von_frey");
            field(i) = strcat('von_frey_',field(i));
        end
    end
    
    spikeField = fieldnames(spikeStruct);
    spikeFieldnew = strings(1,length(spikeField));
    for i = 1:length(spikeField)
        spikeFieldnew(i) = spikeField{i};
    end
    clear spikeField
    
    [~,ia] = setdiff(field,spikeFieldnew);
    
    fileList = fileList(ia);
end