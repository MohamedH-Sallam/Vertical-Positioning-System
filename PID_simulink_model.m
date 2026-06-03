%% Mechatronics Script: Transmission-Explicit Model Builder
clear all; close all; clc;

% --- Parameters ---
R = 2.5; Kt = 0.1; Kb = 0.1; 
m_payload = 0.8; g = 9.81; r = 0.02;

% Explicit Friction/Damping Breakdown (SI Units)
B_motor = 0.0005;    % Motor internal
B_bearings = 0.001;  % Total for all 4 sprockets
B_chains = 0.002;    % Friction of chain links
B_total = B_motor + B_bearings + B_chains;

% Explicit Inertia Breakdown
J_motor = 0.0001;
J_sprockets = 4 * (0.5 * 0.05 * r^2); % 4 sprockets, ~50 grams each
J_chain_links = 0.0002;               % Mass of the chain itself
J_load = m_payload * r^2;             % The weight we are lifting
J_total = J_motor + J_sprockets + J_chain_links + J_load;

mdl = 'Transmission_Detailed_Model2';
if exist(mdl, 'file') == 4, close_system(mdl, 0); end
new_system(mdl); open_system(mdl);

% --- BUILD THE BLOCKS ---
add_block('simulink/Sources/Step', [mdl, '/Target_m'], 'Position', [20, 100, 50, 130]);
add_block('simulink/Commonly Used Blocks/Sum', [mdl, '/Sum_Error'], 'Position', [80, 105, 100, 125]);
set_param([mdl, '/Sum_Error'], 'Inputs', '+-');
add_block('simulink/Continuous/PID Controller', [mdl, '/Arduino_PID'], 'Position', [130, 92, 180, 138]);

% ELECTRICAL STAGE
add_block('simulink/Commonly Used Blocks/Sum', [mdl, '/V_Net'], 'Position', [220, 105, 240, 125]);
set_param([mdl, '/V_Net'], 'Inputs', '+-'); 
add_block('simulink/Commonly Used Blocks/Gain', [mdl, '/Ohm_Law'], 'Position', [270, 100, 310, 130]);
set_param([mdl, '/Ohm_Law'], 'Gain', '1/R'); 
add_block('simulink/Commonly Used Blocks/Gain', [mdl, '/Torque_Const'], 'Position', [340, 100, 380, 130]);
set_param([mdl, '/Torque_Const'], 'Gain', 'Kt');

% MECHANICAL STAGE (Torque Balance)
add_block('simulink/Commonly Used Blocks/Sum', [mdl, '/Torque_Sum'], 'Position', [420, 105, 440, 125]);
set_param([mdl, '/Torque_Sum'], 'Inputs', '+---'); % Tau_m - Friction - Gravity - Cogging
add_block('simulink/Commonly Used Blocks/Gain', [mdl, '/Newton_2nd'], 'Position', [470, 100, 510, 130]);
set_param([mdl, '/Newton_2nd'], 'Gain', '1/J_total');

% Integration Chain
add_block('simulink/Continuous/Integrator', [mdl, '/Int_Omega'], 'Position', [540, 100, 570, 130]);
add_block('simulink/Commonly Used Blocks/Gain', [mdl, '/Radius'], 'Position', [600, 100, 640, 130]);
set_param([mdl, '/Radius'], 'Gain', 'r'); % rad/s to m/s
add_block('simulink/Continuous/Integrator', [mdl, '/Int_Pos'], 'Position', [670, 100, 700, 130]);

% FEEDBACKS
add_block('simulink/Commonly Used Blocks/Gain', [mdl, '/B_Total_Gain'], 'Position', [470, 170, 510, 200]);
set_param([mdl, '/B_Total_Gain'], 'Gain', 'B_total', 'Orientation', 'left'); 
add_block('simulink/Commonly Used Blocks/Gain', [mdl, '/Back_EMF'], 'Position', [540, 220, 580, 250]);
set_param([mdl, '/Back_EMF'], 'Gain', 'Kb', 'Orientation', 'left');
add_block('simulink/Commonly Used Blocks/Constant', [mdl, '/Gravity_Dist'], 'Position', [370, 160, 400, 180]);
set_param([mdl, '/Gravity_Dist'], 'Value', 'm_payload*g*r');

% Final Output & Encoder Feedback
add_block('simulink/Sinks/Scope', [mdl, '/Scope'], 'Position', [750, 100, 780, 130]);

% --- CONNECT ---
add_line(mdl, 'Target_m/1', 'Sum_Error/1');
add_line(mdl, 'Sum_Error/1', 'Arduino_PID/1');
add_line(mdl, 'Arduino_PID/1', 'V_Net/1');
add_line(mdl, 'V_Net/1', 'Ohm_Law/1');
add_line(mdl, 'Ohm_Law/1', 'Torque_Const/1');
add_line(mdl, 'Torque_Const/1', 'Torque_Sum/1');
add_line(mdl, 'Gravity_Dist/1', 'Torque_Sum/2');
add_line(mdl, 'Torque_Sum/1', 'Newton_2nd/1');
add_line(mdl, 'Newton_2nd/1', 'Int_Omega/1');
add_line(mdl, 'Int_Omega/1', 'Radius/1');
add_line(mdl, 'Radius/1', 'Int_Pos/1');
add_line(mdl, 'Int_Pos/1', 'Scope/1');
add_line(mdl, 'Int_Omega/1', 'B_Total_Gain/1', 'autorouting', 'on');
add_line(mdl, 'B_Total_Gain/1', 'Torque_Sum/3', 'autorouting', 'on');
add_line(mdl, 'Int_Omega/1', 'Back_EMF/1', 'autorouting', 'on');
add_line(mdl, 'Back_EMF/1', 'V_Net/2', 'autorouting', 'on');
add_line(mdl, 'Int_Pos/1', 'Sum_Error/2', 'autorouting', 'on');

save_system(mdl);