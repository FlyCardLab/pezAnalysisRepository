function watchRawHex(comPort)
%WATCHRAWHEX Connects directly to the flyPEZ MCU and logs every incoming
% serial line, unmodified, to the command window and to rawhex_log.txt.
% Used with the temporary RAWHEX: debug line in TeensyPEZ_v1.1.ino's
% processTH() to capture an unambiguous, byte-exact record of what the
% secondary humidity/temperature sensor actually transmits (hex-encoded,
% so whitespace is never lost or misread when reviewed later).
%
% Run this standalone -- do NOT run it at the same time as
% runPezControl_v16.1.m; only one process can hold the serial port open.
%
% Usage: watchRawHex('COM5')   % replace with the actual COM port

delete(instrfindall)
s = serial(comPort);
set(s,'baudrate',250000,'inputbuffersize',100*(128+3),'Terminator','CR/LF');
fopen(s);
disp('Connected. Press Ctrl+C to stop.')
logFile = fopen('rawhex_log.txt','a');
while true
    if s.BytesAvailable > 0
        line = fscanf(s);
        ts = datestr(now,'HH:MM:SS.FFF');
        fprintf('[%s] %s', ts, line);
        fprintf(logFile,'[%s] %s', ts, line);
    end
end
end
