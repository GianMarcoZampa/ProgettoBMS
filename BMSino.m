function [I_out, set_balancing, set_cells_voltages, filter_set_balancing, stop_simulation] = BMSino(read_step, one_second_step, cells_temperatures, BMS_temperature, cells_voltages)
%% DEFINIZIONE VARIABILI

% Seleziona l'algoritmo di bilanciamento con cui vuoi lavorare tra Av, Bv, Ac, e Bc.
bal_algorithm_selector                = 'Av';

% Seleziona l'algoritmo di corrente con cui vuoi lavorare tra Av, Bv, Ac e Bc.
cur_algorithm_selector                = 'Bv';

% Seleziona se automatizzare lo stop della simulazione quando tutte le
% tensioni raggiungono un certo valore.
enable_auto_stop_simulation 		  = 1;

% Scegliere se caricare o scaricare la batteria con un certo profilo di
% corrente: 'charge', 'discharge_9' o 'full_discharge'.
% - 'charge': carica con la corrente stimata attraverso l'algoritmo
%   ottimizzato di carica
% - 'discharge_9': scarica con un profilo di corrente specifico presente
%   nella prova 9
% - 'full_discharge': scarica con la corrente costante massima supportata
%   dalle celle.
current_profile                       = 'charge';

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

% Used a filtered version of High Cell Voltage.
% A moving-average filter slides a window of length 8 along the data,
% computing averages of the data contained in each window.
b = (1/filter_window_size) * ones(1, filter_window_size);
a = 1;

% Definisci variabili persistent per salvare gli stati del bilanciamento,
% le tensioni e temperature delle celle, la temperatura del BMS e la
% corrente di alimentazione.
persistent CellBalancingStatus
if isempty(CellBalancingStatus)
    CellBalancingStatus     = zeros(CELLS_NUMBER, test_balance_window);
end

persistent CellVoltageStatus
if isempty(CellVoltageStatus)
    CellVoltageStatus       = zeros(CELLS_NUMBER, filter_window_size);
end

persistent CellTemperatureStatus
if isempty(CellTemperatureStatus)
    CellTemperatureStatus   = zeros(CELLS_NUMBER, 1);
end

persistent BMS_Temperature
if isempty(BMS_Temperature)
    BMS_Temperature         = 0;
end

persistent ChSetPoint
if isempty(ChSetPoint)
    ChSetPoint              = STD_CH_CURRENT;
end

% Definisci variabile counter e clock che si incrementano ogni volta che è
% richiamato il blocco funzione BMSino, ovvero ogni step di esecuzione del
% solver. "counter" gestisce il tempo nell'intervallo tra un istante di
% lettura e un altro. "clock" gestisce il tempo dell'intera simulazione.
persistent counter
if isempty(counter)
    counter = -1;
end
if counter == read_step - 1
    counter = -1;
end
counter = counter + 1;

persistent clock
if isempty(clock)
    clock = 0;
end
clock = clock + 1;

% Definisci variabile transient time che rappresenta la durata del
% transitorio finale con corrente nulla.
persistent transient_time
if isempty(transient_time)
    transient_time = 0;
end

% Definisci variabile current_phase che indica in quale step di corrente
% si trova il sistema.
persistent current_phase
if isempty(current_phase)
    current_phase = 0;
end

%% LETTURA DELLE TENSIONI E TEMPERATURE DELLE CELLE

% Negli istanti X.1 attiva la lettura della tensione delle celle, le
% temperature e salvale nelle ultime colonne delle rispettive matrici di
% memoria, effettuando uno shift verso sinistra.
if counter == 1
    
    % Aggiorna lo stato delle temperature delle celle e del BMS
    CellTemperatureStatus(:, 1) = cells_temperatures;
    Tcmax = max(CellTemperatureStatus(:, 1));
    Tcmin = min(CellTemperatureStatus(:, 1));
    BMS_Temperature = BMS_temperature;
    
    % Aggiorna lo stato della SoC e della tensione delle celle
    CellSoCstatus = circshift (CellSoCstatus, [0 -1]);
    CellSoCstatus(:, filter_window_size) = SoC_in;
    CellVoltageStatus = circshift (CellVoltageStatus, [0 -1]);
    CellVoltageStatus(:, filter_window_size) = cells_voltages;
    
    balancing = 1; % flag che attiva il bilanciamento delle celle
    set_cells_voltages = cells_voltages;
    set_SoC = SoC_in;
    
    % Determina il massimo ed il minimo di tensione e SoC
    Vmax=max(set_cells_voltages(:));
    Vmin=min(set_cells_voltages(:));
    SoCmax=max(set_SoC(:));
    SoCmin=min(set_SoC(:));
    
    if enable_auto_stop_simulation == 1
        is_time_to_stop_simulation = zeros(CELLS_NUMBER, 1);
        
        for i=1:CELLS_NUMBER
            
            % Controllo delle tensioni
            if  Vmax >= CELL_VOLTAGE_STOP
                if set_cells_voltages(i) > (Vmax - DELTA_VOLTAGE_STOP)
                    is_time_to_stop_simulation(i, 1) = 1;
                end
            else
                is_time_to_stop_simulation(i, 1) = 0;
            end
            % Controllo della SoC
            if  SoCmax >= CELL_SoC_STOP
                if set_SoC(i) > (SoCmax - DELTA_SoC_STOP)
                    is_time_to_stop_simulation(i, 1) = 1;
                end
            else
                is_time_to_stop_simulation(i, 1) = 0;
            end
            
        end
        
        % Stop della simulazione.
        if (is_time_to_stop_simulation == [1; 1; 1; 1; 1; 1]) & (ChSetPoint < current_stop)
            current_phase = 3;
        end
        
        % Non terminare subito la simulazione ma aspetta tau.
        if transient_time/one_second_step >= tau
            stop_simulation = 1;
        else
            stop_simulation = 0;
        end
        
    else
        stop_simulation = 0;
    end
    
else
    
    % In tutti gli altri istanti azzera "balancing" e restituisci in
    % uscita le ultime tensioni misurate.
    balancing = 0; % attiva il bilanciamento solo dopo la nuova lettura
    
    set_cells_voltages = CellVoltageStatus(:, filter_window_size);
    set_SoC = CellSoCstatus(:, filter_window_size);
    
    Vmax=max(set_cells_voltages(:));
    Vmin=min(set_cells_voltages(:));
    
    SoCmax=max(set_SoC(:));
    SoCmin=min(set_SoC(:));
    
    Tcmax = max(CellTemperatureStatus(:, 1));
    Tcmin = min(CellTemperatureStatus(:, 1));
    
    stop_simulation = 0;
    
end
%% CONTROLLO DI SICUREZZA

% Calcola i flag di errore
if Vmax > MAX_SECURITY_CELL_VOLTAGE
    error_high_cell_voltage = Vmax;
else
    error_high_cell_voltage = NaN;
end

if Vmin < MIN_CELL_VOLTAGE
    error_low_cell_voltage = Vmin;
else
    error_low_cell_voltage = NaN;
end

if SoCmax > MAX_SECURITY_CELL_SoC
    error_high_cell_SoC = SoCmax;
else
    error_high_cell_SoC = NaN;
end

if SoCmin < MIN_CELL_SoC
    error_low_cell_SoC = SoCmin;
else
    error_low_cell_SoC = NaN;
end

if Tcmax > MAX_CELL_TEMPERATURE
    error_high_cell_temperature = Tcmax;
else
    error_high_cell_temperature = NaN;
end

if Tcmin < MIN_CELL_TEMPERATURE
    error_low_cell_temperature = Tcmin;
else
    error_low_cell_temperature = NaN;
end

if BMS_Temperature > MAX_BMS_TEMPERATURE
    error_high_BMS_temperature = BMS_Temperature;
else
    error_high_BMS_temperature = NaN;
end

