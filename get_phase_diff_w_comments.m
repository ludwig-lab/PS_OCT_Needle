%This code was developed to open pre-stored OCT phase data from a needle 
%probe and calculate the phase difference between subsequent A-lines. 
%Smoothing is applied. 

%V1.0, Danielle J. Harper, Yongjoo Kim, Alejandra Gómez-Ramírez and Benjamin J. Vakoc, 2023
%Further information can be found in this paper:
   % https://doi.org/10.48550/arXiv.2305.14390
% Set this to 1 for example data set or 2 for salmon data
% Clear the environment and set up for opening the phase files
clc;
close all;
clear all;

caseFile = 'example'; 

% Switch between cases
switch caseFile
    case 'example' % Example data set       
        % Set directory and filenames for phase files
        Example_Data_files_folder = 'E:\My Drive\4_UW-Madison\2_4_MGH+FDA+UW OCT\needle_code_share\Example_data';
        filename1 = '[p.needle_2][s.salmon][06-16-2021_14-15-13]phase1.mgh'
        filename2 = '[p.needle_2][s.salmon][06-16-2021_14-15-13]phase2.mgh'
        readOpt.nFrames = 1024;
        Machine_ID = 'MGH';
        % Parameters for Region of Interest
        roiStartRow = 220; % Starting row of the region of interest
        roiEndRow = 272;   % Ending row of the region of interest
        
        % Optional: Parameters for Calibration Line (if needed)
        calibrationLineStart = 205; % Start of calibration line (fiber tip)
        calibrationLineEnd = 215;   % End of calibration line (fiber tip)

               
    case 'salmon' % Salmon data
        % Set directory and filenames for phase files
        Example_Data_files_folder = 'H:\OFDIData\user.Ricardo\[p.231220_PS_Needle_Probe]\[p.231220_PS_Needle_Probe][s.Salmon_Probe_04_Test3_Dist1.2cm][12-20-2023_15-52-35]';
        filename1 = '[p.231220_PS_Needle_Probe][s.Salmon_Probe_04_Test3_Dist1.2cm][12-20-2023_15-52-35].phaseXA.mgh';
        filename2 = '[p.231220_PS_Needle_Probe][s.Salmon_Probe_04_Test3_Dist1.2cm][12-20-2023_15-52-35].phaseXB.mgh';
        readOpt.nFrames = 1023;
        Machine_ID = 'SPARC';
        % Parameters for Region of Interest
        roiStartRow = 476; % Starting row of the region of interest
        roiEndRow = 526;   % Ending row of the region of interest
        
        % Optional: Parameters for Calibration Line (if needed)
        calibrationLineStart = 466; % Start of calibration line (fiber tip)
        calibrationLineEnd = 476;   % End of calibration line (fiber tip)

        
    otherwise
        error('Invalid case number. Please specify 1 for example data set or 2 for salmon data.');
end
addpath(Example_Data_files_folder);

% Setting the directory for reading the file
readOpt.dirname = Example_Data_files_folder

% Define initial frame and number of frames to read
readOpt.iFrame = 1;

% Read the MGH file with the specified options
phaseImage8bit1 = readMgh(filename1, readOpt);

%%
% Convert the 8-bit phase images to true phase values in the range of -pi to pi.
% The original data was saved as 8-bit (0-255) and is now being converted back.
number_bits = 8;
ph1 = single(phaseImage8bit1).*(2*pi)./(2^number_bits-1)-pi;

% Retrieve the dimensions of the phase image (rows, columns, frames)
[~, ~, num_frm] = size(ph1); 

% Define column distance based on machine type
col_distance = (strcmp(Machine_ID, 'MGH')) * 2 + (strcmp(Machine_ID, 'SPARC')) * 1;

% Call the function to calculate phase difference
diff_ph1 = calculate_phase_difference(ph1, col_distance);


%% Focusing on a specific region of interest by slicing the phase difference array
% phase difference of only the region of interest (sliced)


% Calculate the number of rows and columns based on the region of interest
num_rows = roiEndRow - roiStartRow + 1; % Number of rows
num_rows_cal = calibrationLineEnd - calibrationLineStart; % Number of rows for calibration

% Slice the phase difference array to focus on the specified region of interest
diff_ph1_sliced = diff_ph1(roiStartRow:roiEndRow,:,:); % Slicing


%% Concatenating two frames together, handling cases with an odd number of frames
diff_ph_con = concatenate_frames(diff_ph1_sliced);

% Calculating the number of frames after concatenation
num_frm_con = ceil(num_frm/2);
%% Filtering
% Parameters for Filtering
thresholdValue = 2.5; % Threshold value for filtering
maxColumns = concatenationWidth; % Maximum number of columns to iterate through

% Initialize counters
i = 0; j = 0; k = 0; z = 0;

% Iterate through the frames, rows, and columns for filtering
for k = 1:num_frm_con
    for j = 1:maxColumns
        for i = 1:num_rows
            v = diff_ph_con(i, j, k);
            if v > thresholdValue
                diff_ph_con(i, j, k) = 0;
                z = z + 1; % Counter for the number of modifications made
            end  
        end
    end
end

%% Moving median values every 73 columns

% Parameters
medianFilterSize = 73; % Size of the window for the moving median e.g. 73
edgeExtensionSize = 36; % Edge extension size for concatenation e.g. 36
columnSize = concatenationWidth; % Defined elsewhere in your script

% Initialize arrays with the parameterized sizes
movm = zeros(num_rows, columnSize);
movma = zeros(num_rows, columnSize + edgeExtensionSize);
movmb = zeros(num_rows, columnSize + 2 * edgeExtensionSize);
diffphconM = zeros(num_rows, columnSize, num_frm_con);
diffphconMa = zeros(num_rows, columnSize + edgeExtensionSize, num_frm_con);
diffphconMb = zeros(num_rows, columnSize + 2 * edgeExtensionSize, num_frm_con);

% Processing loop
for k = 1:num_frm_con
    if num_frm_con == 1
        movm = movmedian(diff_ph_con(:,:,k), medianFilterSize, 2);
        diffphconM(:,:,k) = movm;
        break;
    end
    if k + 1 > num_frm_con
        diffphconMa(:,:,k) = horzcat(diff_ph_con(:,columnSize-edgeExtensionSize+1:columnSize,k-1), diff_ph_con(:,:,k));
        movma = movmedian(diffphconMa(:,:,k), medianFilterSize, 2);
        diffphconM(:,:,k) = movma(:,edgeExtensionSize+1:end);
        break;
    end
    if k ~= 1
        diffphconMb(:,:,k) = horzcat(diff_ph_con(:,columnSize-edgeExtensionSize+1:columnSize,k-1), diff_ph_con(:,:,k), diff_ph_con(:,1:edgeExtensionSize,k+1));
        movmb = movmedian(diffphconMb(:,:,k), medianFilterSize, 2);
        diffphconM(:,:,k) = movmb(:,edgeExtensionSize+1:columnSize+edgeExtensionSize);
        continue;
    end
    diffphconMa(:,:,k) = horzcat(diff_ph_con(:,:,k), diff_ph_con(:,1:edgeExtensionSize,k+1));
    movma = movmedian(diffphconMa(:,:,k), medianFilterSize, 2);
    diffphconM(:,:,k) = movma(:,1:columnSize);
end

% Add pi to the filtered phase difference and display
diffphconM1 = diffphconM + pi;
figure('Name','movmedian+2pi'), imshow3D(diffphconM1, [0 2*pi]);
colormap(redblue);



%%
%Average of each A-scan in region of interest
block=zeros(1,columnSize,num_frm_con);
block2=zeros(1,columnSize*num_frm_con);
for i=1:num_frm_con
    block(:,:,i)=mean(diffphconM(:,:,i),1);
    a=columnSize*(i-1)+1;
    b=columnSize*(i);
    block2(:,a:b)=block(:,:,i);
end
block2=block2-mean(block2(:,1:end));
figure('Name','Block'),plot(unwrap(block2(:,:)));
 
%Distance
w_length=0.0013; %mm %1.3um 
n=1.39; %refractive index of tissue
dis=(block2.*w_length)./(4*pi*n);
%correct for drift with line below if needed. Region where needle is not touching tissue should be
%zero
dis=dis-1.6e-7;
time=(1:columnSize*num_frm_con)*40*(10^-6);
figure('Name','Relative distance'),plot(time,dis(:,:));
title('Relative Distance')
xlabel('time [s]') 
ylabel('Distance []')
sum=0;
totaldisr=zeros(1,columnSize*num_frm_con);
% for u=1:1022*fr
%     sum=sum+dis(1,u);
%     totaldisr(:,u)=sum;
% end
dis2 = movmedian(dis,5000);
for u=1:columnSize*num_frm_con
    sum=sum+dis2(1,u);
    totaldisr(:,u)=sum;
end
figure('Name','Absolute Distance'),plot(time,totaldisr(:,:));
hold on

title('Absolute Distance')
xlabel('time [s]') 
ylabel('Distance [mm]')

%save to .mat file
save totaldisr_salmon.mat totaldisr
%%

figure(11)
% Create axes
axes1 = axes('Parent',figure(11),...
    'Position',[0.623353293413173 0.167330677290833 0.449101796407186 0.697211155378486]);
hold(axes1,'on');
alpha 0.2

plot(time,totaldisr(:,:),'--o','Color',[0.77,0.72,0.97],'LineWidth',4,'MarkerSize',10,'MarkerFaceColor',[0.47,0.36,0.94],'MarkerEdgeColor',[0.47,0.36,0.94]);
%figure(11), legend({'Observed','Predicted'},'LineWidth',2);
figure(11), title('Doppler-tracked Absolute Distance','FontSize',40);
figure(11), xlabel('time [s]','FontSize',36);
figure(11), ylabel('Distance [mm]','FontSize',36);
xlim([0,25])
% ylim([-5,55])
set(gca,'FontSize',36);
set(gcf, 'Units', 'normalized', 'outerposition', [0, 0, 1, 0.7],'Color',[1 1 1],'OuterPosition',[0 0 1 1])
set(get(gca,'YLabel'),'Rotation',0)
ylh = get(gca,'ylabel');
gyl = get(ylh);                
ylp = get(ylh, 'Position');
ylp(1) = -5;
set(ylh, 'Rotation',90, 'Position',ylp, 'VerticalAlignment','middle', 'HorizontalAlignment','center')
ax = gca;
fig_loc = ax.Position;
ax.Position(1) = 0.1802;
pbaspect([1 1 1]);
% set(axes1,'LineWidth',6,'TickLength',[0.025 0.04],'XTick',...
%     [0 5 10 15 20 25],'FontSize',36);
%%
%Distance calibration line
w_length=0.0013; %mm %1.3um
n=1.3;
disc=(diffphconM(num_rows_cal,:,:).*w_length)./(4*pi*n);
disc=disc-mean(disc(:,1:10000));
time=(1:columnSize*num_frm_con)*40*(10^-6);
figure('Name','Relative distance c'),plot(time,disc(:,:));
title('Relative Distance')
xlabel('time [s]') 
ylabel('Distance [mm]')
sum=0;
totaldisc=zeros(1,columnSize*num_frm_con);
for u=1:columnSize*num_frm_con
    sum=sum+disc(1,u);
    totaldisc(:,u)=sum;
end
figure('Name','Absolute Distance c'),plot(time,totaldisc(:,:));
title('Absolute Distance')
xlabel('time [s]') 
ylabel('Distance [mm]')


% %Tiff file
% filename = 'phasedifference.tiff';
% for k=1:fr
%     B=diffphconM1(:, :, k);
%     %figure,mesh(B)
%     B=uint8(B.*(255/(2*pi)));
%     B=ind2rgb(B,redblue);
%     if k==1
%         imwrite(B,filename);
%     else
%         imwrite(B,filename,'WriteMode','append');
%     end
%     
% end

