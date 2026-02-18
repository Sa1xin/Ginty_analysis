% To get to Deepethogram label format
Behaviors = {'Nosepoking', 'LowerBodyGroom', 'FacialGroom','TailMovement','GenitalGrooming'};
Behaviors_output = [{'background'} Behaviors];
Labels = unique(labeledData.Label);
nFrames = height(fullLabelTable);
matrix_output = zeros(nFrames, length(Behaviors));
for i = 1:length(Behaviors)
    Behavior_idx = find(strcmp(fullLabelTable.Label,Labels(i)));
    matrix_output(Behavior_idx,i) = 1;
end
backgrd_idx = find(strcmp(fullLabelTable.Label, "NA"));
matrix_output = [zeros(nFrames,1) matrix_output];
matrix_output(backgrd_idx,1) = 1;
matrix_output = [(1:nFrames)' matrix_output];

T = array2table(matrix_output, 'VariableNames', [' ', Behaviors_output]);
writetable(T, 'BehaviorOutputDeepEthogram.csv');