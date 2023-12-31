%% Define General Variables


save_fig = false;
resolution = 1000;               % resolution x points/meter
c = 343;                      % Speed of Sound

%% Define Grid, MIcrophone, Calibration and Sound Positions in the form [X Y]
% 

r1 = [0,0];                     %mic1
r2 = [0.5 0];                  %mic2
r3 = [0 0.8];                  %mic3              
r4 = [0.5,0.8];               %mic4
Cal_pos =  [0.25 0.4];         %Position of calibration sound

%% Generate Lookup Table for Localization

LUT = Generate_LUT(r1,r2,r3,r4,resolution);     % Generate Look up table for TODA WRT mic 1

%%  Step 1 Reading In Audio and setting up time array
%% Define the paths to the audio files
audio_file1 = fullfile(audio_dir, 'RecordingPi1.wav');
audio_file2 = fullfile(audio_dir, 'RecordingPi2.wav');

[audio1, ~] = audioread(audio_file1);
[audio2, Fs] = audioread(audio_file2);


y2 = audio1(:, 1);  % Left channel of first Pi,M2
y1 = audio1(:, 2);  % Right channel of first Pi,M1
y3 = audio2(:, 1);  % Left channel of second Pi,M3
y4 = audio2(:, 2);  % Right channel of second Pi,M3

[reference_sig,Fs_chirp] = audioread("chirp_0_15000_5s.wav");



%%
%Find ideal TOA of calibration signal
t0_mic1 = sqrt((r1(1)-Cal_pos(1))^2+(r1(2)-Cal_pos(2))^2)/c; 
t0_mic2 = sqrt((r2(1)-Cal_pos(1))^2+(r2(2)-Cal_pos(2))^2)/c;
t0_mic3 = sqrt((r3(1)-Cal_pos(1))^2+(r3(2)-Cal_pos(2))^2)/c;
t0_mic4 = sqrt((r4(1)-Cal_pos(1))^2+(r4(2)-Cal_pos(2))^2)/c;

%%
%Find TOAs of calibration signal and signal of interest
[cal1,snd1] = findTOA(y1 , reference_sig);
[cal2,snd2] = findTOA(y2 , reference_sig);
[cal3,snd3] = findTOA(y3 , reference_sig);
[cal4,snd4] = findTOA(y4 , reference_sig);

%Synchronise TOAs based on Calibration TOA
RTOA1 = snd1-cal1+t0_mic1;
RTOA2 = snd2-cal2+t0_mic2;
RTOA3 = snd3-cal3+t0_mic3;
RTOA4 = snd4-cal4+t0_mic4;

%Form TDOAs
TDOA_21 = RTOA2 - RTOA1 ;
TDOA_31 = RTOA3 - RTOA1 ;
TDOA_41 = RTOA4 - RTOA1 ;
TDOA_32 = RTOA3 - RTOA2 ;
TDOA_42 = RTOA4 - RTOA2 ;
TDOA_43 = RTOA4 - RTOA3 ;


%% Step 9 Use LUT to find Estimated position

[Estimated_positionN1, Estimated_positionN2, Estimated_positionN3, Estimated_positionN4, E1 , E2, E3 , E4 ]   = triangulate(TDOA_21,TDOA_31,TDOA_41,TDOA_32,TDOA_42,TDOA_43,LUT);

Estimate_arr = [Estimated_positionN1', Estimated_positionN2', Estimated_positionN3', Estimated_positionN4'];


%Ditirmine if there is a sampling error on a single mic
bad_mic = [0 0 0 0];
possible_solutions = zeros(2,4);
if (Estimated_positionN1(1)~=0 && Estimated_positionN1(2)~=0 && Estimated_positionN1(1)~=r4(1) && Estimated_positionN1(2)~=r4(2))
     display(Estimated_positionN1);
     possible_solutions(:,end+1)=Estimated_positionN1;
     bad_mic(1) = 1;
     
else 
    fprintf("Mic 1 is probably ok\n")
     
end
if (Estimated_positionN2(1)~=r1(1) && Estimated_positionN2(2)~=r1(1) && Estimated_positionN2(1)~=r4(1) && Estimated_positionN2(2)~=r4(2))
    display(Estimated_positionN2);
    possible_solutions(:,end+1)=Estimated_positionN2';
    bad_mic(2) = 1;
        
else 
    fprintf("Mic 2 is probably ok\n")
    okay_arr(2)=1;
end

if (Estimated_positionN3(1)~=0 && Estimated_positionN3(2)~=0 && Estimated_positionN3(1)~=r4(1) && Estimated_positionN3(2)~=r4(2))
    display(Estimated_positionN3);
    possible_solutions(:,end+1)=Estimated_positionN3';
    bad_mic(3) = 1;
  
else 
fprintf("Mic 3 is probably ok\n")
okay_arr(3)=1;
end

if (Estimated_positionN4(1)~=0 && Estimated_positionN4(2)~=0 && Estimated_positionN4(1)~=r4(1) && Estimated_positionN4(2)~=r4(2))
    display(Estimated_positionN4);
    possible_solutions(:,end+1)=Estimated_positionN4';
    bad_mic(4) = 1;
  
else 
fprintf("Mic 4 is probably ok\n")
okay_arr(4)=1;
end

%Output mean estimation if more than 1 possible solution
possible_solutions( :, all(~possible_solutions,1) ) = [];
if isempty(possible_solutions)
    disp("Bad Read, estimated position will be incorrect")
    Estimated_position = Estimated_positionN1;
else
    Estimated_position(1) = mean(possible_solutions(1,:));   
    Estimated_position(2) = mean(possible_solutions(2,:));

end

%% Write to csv file
% Full path to the CSV file
filePath = 'C:\Users\User\OneDrive - University of Cape Town\Desktop\EEE3097S\AcoTriangulator\Milestone3\estimated_position.csv';

% Write the matrix to the file
writematrix(Estimated_position,filePath);


%% Functions

function [LUT] = Generate_LUT(R1, R2, R3, R4,res)
    
    max_x = max(max(max(R1(1),R2(1)),R3(1)),R4(1));
    max_y = max(max(max(R1(2),R2(2)),R3(2)),R4(2));
    count = 1;
    display(max_x*res)
    display(max_y*res)
    LUT = zeros(round(max_x*res*max_y*res),8);

    for i = 0:max_x*res
        for j=0:max_y*res
            S = [i/res j/res];
            
            TOA_R1=  sqrt((R1(1)-S(1))^2+(R1(2)-S(2))^2)/343;
            TOA_R2=  sqrt((R2(1)-S(1))^2+(R2(2)-S(2))^2)/343;
            TOA_R3=  sqrt((R3(1)-S(1))^2+(R3(2)-S(2))^2)/343;
            TOA_R4=  sqrt((R4(1)-S(1))^2+(R4(2)-S(2))^2)/343;
          
            
            td21 = TOA_R2 - TOA_R1;
            td31 = TOA_R3 - TOA_R1;
            td41 = TOA_R4 - TOA_R1;
            td32 = TOA_R3 - TOA_R2;
            td42 = TOA_R4 - TOA_R2;
            td43 = TOA_R4 - TOA_R3;

            LUT(count,1) = td21;
            LUT(count,2) = td31;
            LUT(count,3) = td41;
            LUT(count,4) = td32;
            LUT(count,5) = td42;
            LUT(count,6) = td43;
            LUT(count,7) = S(1);
            LUT(count,8) = S(2);
            count = count+1;
        end
    end
end


function [Correlation_arr, lag_arr, index_of_lag, shift] = correlate(y2,y1)
    [Correlation_arr,lag_arr] = xcorr(y2,y1);
    [~,index_of_lag] = max(abs((Correlation_arr)));
    shift = lag_arr(index_of_lag);

end 


function [Estimated_positionN1, Estimated_positionN2, Estimated_positionN3, Estimated_positionN4, E1, E2, E3 , E4 ] = triangulate(t21,t31,t41,t32,t42,t43,LUT)

    td_simN1 = LUT(1:end,4:6);
    td_simN2 = [LUT(1:end,2), LUT(1:end,3), LUT(1:end,6)];
    td_simN3 = [LUT(1:end,1), LUT(1:end,3), LUT(1:end,5)];
    td_simN4 = [LUT(1:end,1), LUT(1:end,2), LUT(1:end,4)];

   
    td_arrN1 = [t32 t42 t43];
    td_arrN2 = [t31 t41 t43];
    td_arrN3 = [t21 t41 t42];
    td_arrN4 = [t21 t31 t32];
    
    
    
  

    diff_arrN1 = td_simN1 - td_arrN1;
    diff_arrN2 = td_simN2 - td_arrN2;
    diff_arrN3 = td_simN3 - td_arrN3;
    diff_arrN4 = td_simN4 - td_arrN4;
    
    


    [~,IN1] = min(sum(abs(diff_arrN1).*2,2));
    [~,IN2] = min(sum(abs(diff_arrN2).*2,2));
    [~,IN3] = min(sum(abs(diff_arrN3).*2,2));
    [~,IN4] = min(sum(abs(diff_arrN4).*2,2));
  
    PaccN1 = abs(diff_arrN1(IN1,1:end));
    PaccN2 = abs(diff_arrN2(IN2,1:end));
    PaccN3 = abs(diff_arrN3(IN3,1:end));
    PaccN4 = abs(diff_arrN4(IN4,1:end));
    
    E1 = mean([PaccN2(1) PaccN2(2) PaccN3(1) PaccN3(2) PaccN4(1) PaccN4(2)]) ;
    E2 = mean([PaccN1(1) PaccN1(2) PaccN3(1) PaccN3(3) PaccN3(1) PaccN4(3)]);
    E3 = mean([PaccN1(1) PaccN1(3) PaccN2(1) PaccN2(3) PaccN4(2) PaccN4(3)]);
    E4 = mean([PaccN1(2) PaccN1(3) PaccN2(2) PaccN2(3) PaccN3(2) PaccN3(3)]);
    

    Estimated_positionN1 = flip(LUT(IN1,7:8),1);
    Estimated_positionN2 = flip(LUT(IN2,7:8),1);
    Estimated_positionN3 = flip(LUT(IN3,7:8),1);
    Estimated_positionN4 = flip(LUT(IN4,7:8),1);

   
end


function [I, Q, scale] = loadfersHDF5(name) %#ok<*DEFNU>
  hinfo = hdf5info(name); %#ok<HDFI>
  count = round(size(hinfo.GroupHierarchy.Datasets,2)/2);
  numelements = hinfo.GroupHierarchy.Datasets(1).Dims;

  I = zeros(numelements*count,1);
  Q = zeros(numelements*count,1);

  scale = hinfo.GroupHierarchy.Datasets(1).Attributes(3).Value;

  for k = 1:count
      Itemp = hdf5read(hinfo.GroupHierarchy.Datasets(2*k-1));
      Qtemp = hdf5read(hinfo.GroupHierarchy.Datasets(2*k));
       
      I(1+(k-1)*numelements:k*numelements,1) = Itemp;
      Q(1+(k-1)*numelements:k*numelements,1) = Qtemp;
  end
end

function [toa_cal ,toa_snd ] = findTOA(y , sound)
    Fs = 48000;
    [~, ~,~, peak1] = correlate(y,sound);
    flattern = zeros(1,3*Fs);
    y_temp = y;
    flat = length(flattern);
    y_temp(peak1:peak1+flat-1) = flattern;
    [~,~,~, peak2] = correlate(y_temp,sound);
    peaks = [peak1 peak2];
    toa_cal = min(peaks)/Fs;
    toa_snd = max(peaks)/Fs;

end