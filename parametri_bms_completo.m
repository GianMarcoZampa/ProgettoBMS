% Corrente di CARICA.
STD_CH_CURRENT                        = 1.50; % A

% Correnti del profilo A TRATTI di SCARICA.
I0                                    = 2.65; % A
I1                                    = 1.36; % A
I2                                    = 1.33; % A

% Corrente COSTANTE di SCARICA.
STD_DH_CURRENT                        = 1.6;  % A

% DELTA_VOLTAGE del bilanciamento.
DELTA_VOLTAGE_EOB                     = 0.01; % V

% Costante di tempo dei condensatori, tempo che si attende una volta
% attivato il transitorio.
tau 								  = 500;  % secondi

% Parametri BMS in termini di Soc e Voltage
current_stop						  = 0.4;
MAX_SoC								  = 0.9;  % SoC massima della batteria
CELL_SoC_START_BALANCING			  = 0.8;  % SoC a cui iniziare il bilanciamento
CELL_SoC_STOP 						  = 0.895;% SoC in cui interrompere la carica
DELTA_SoC_STOP						  = 0.005;
CELL_SoC_START_SP_CH_REDUCTION		  = 0.8;
MAX_SECURITY_CELL_SoC				  = 1;
MIN_CELL_SoC						  = 0;	  % SoC minima della battera
DELTA_SoC                             = 0.005;% 
CELLS_NUMBER                          = 6;	  % Numero di batterie
test_balance_window                   = 100;  %  
filter_window_size                    = 8;	  % Lunghezza del filtro applicato alle tesioni ed alla SoC
MAX_SECURITY_CELL_VOLTAGE             = 4.2;  % V  used for security check
MAX_CELL_VOLTAGE                      = 4.1;  % V  used for SetPoint Estimation alghorithm
MIN_CELL_VOLTAGE                      = 2.5;  % V
CELL_VOLTAGE_START_SP_CH_REDUCTION    = 4;    % V
CELL_VOLTAGE_START_BALANCING          = 3.7;  % V
CELL_VOLTAGE_STOP                     = 4.07; % V  used for stop simulation
DELTA_VOLTAGE_STOP                    = 0.01; % V
R_BAL                                 = 10;   % ohm
Rint                                  = 0.03; % ohm
dSoC_dOCV                             = 1;
CUTOFF_CURRENT                        = 65;   % mA
MAX_CELL_TEMPERATURE                  = 40;   % °C
MIN_CELL_TEMPERATURE                  = 0;    % °C
MAX_BMS_TEMPERATURE                   = 75;   % °C