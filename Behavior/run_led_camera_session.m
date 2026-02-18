% MATLAB Script: Launch Bonsai, configure LED pulse durations, and record LED log
% Requirements:
% - Arduino on COM4
% - Bonsai installed and .bonsai workflow ready

% === CONFIGURATION ===
useLED = true;
onDurations = [3, 5, 7];   % LED ON times (seconds)
offDurations = [4, 6, 8];  % LED OFF times (seconds)
sessionDuration = 60;      % Total session duration in seconds
%bonsaiWorkflow = 'C:/path/to/dual_camera_led_logger.bonsai';  % <-- adjust this
logFile = 'led_log.csv';

% === Generate randomized LED config ===
rng('shuffle');
onTime = onDurations(randi(length(onDurations)));
offTime = offDurations(randi(length(offDurations)));

% === Launch Bonsai ===
system(sprintf('"C:/Program Files/Bonsai/Bonsai.exe" "%s" &', bonsaiWorkflow));
pause(3);  % wait for Bonsai to initialize

% === Open Serial Port to Arduino ===
s = serialport("COM3", 115200);
configureTerminator(s, "LF");
pause(2);
flush(s);
%% 

% === Send LED config (if used) ===
if useLED
    cmd = sprintf("CONFIG %.2f %.2f", onTime, offTime);
    writeline(s, cmd);
    pause(0.5);
end

% === Start Arduino ===
writeline(s, "START");

% === Log Arduino serial output ===
fprintf("Logging LED events to %s...\n", logFile);
fid = fopen(logFile, 'w');
fprintf(fid, 'Event,Timestamp_us\n');

t0 = tic;
while toc(t0) < sessionDuration
    if s.NumBytesAvailable > 0
        line = readline(s);
        fprintf(fid, '%s\n', strtrim(line));
        disp(line);
    end
end

fclose(fid);
clear s;
fprintf("Session complete. Log saved to %s\n", logFile);
