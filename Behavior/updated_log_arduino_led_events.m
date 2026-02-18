% MATLAB script: Read and log LED ON/OFF events from Arduino
% Assumes Arduino is connected on COM4 and running at 115200 baud
% Arduino sends lines like: "LED_ON t=12345678"

% === CONFIGURATION ===
serialPort = "COM3";        % Change if your Arduino uses a different port
baudRate = 115200;
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFile = sprintf("multi_trigger_led_log_%s.csv", timestamp);
numTrials = 2;
MaxDuration = 600;  % Max total time to listen (seconds)

% === Open Serial Port ===
s = serialport(serialPort, baudRate);
configureTerminator(s, "LF");
pause(2); flush(s);
%% 

% === Start Logging ===
fid = fopen(logFile, 'w');
fprintf(fid, 'Event,ArduinoTime_us,PC_Time\n');
writeline(s, sprintf("START %d", numTrials));
disp("Trial sequence started.");

% === Read and Log Loop ===
t0 = tic;
blinkEndCount = 0;
while toc(t0) < MaxDuration && blinkEndCount < numTrials
    if s.NumBytesAvailable > 0
        line = strtrim(readline(s));
        pcTime = datetime('now','Format','HH:mm:ss.SSS');

        tokens = split(line, 't=');
        if numel(tokens) == 2
            event = strtrim(tokens{1});
            arduinoTime = str2double(tokens{2});
            fprintf(fid, '%s,%d,%s\n', event, arduinoTime, string(pcTime));
            disp([event ' | ' num2str(arduinoTime) ' | ' char(pcTime)]);
            if strcmp(event, "BLINK_END")
                blinkEndCount = blinkEndCount + 1;
            end
        else
            fprintf(fid, 'UNKNOWN_LINE,,%s\n', string(pcTime));
            disp(['⚠️ Unparsed line: ' line]);
        end
    end
end

fclose(fid); clear s;
fprintf("✅ Done. Log saved to %s\n", logFile);
