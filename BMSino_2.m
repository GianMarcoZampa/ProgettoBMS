function [I_out, set_balancing, set_cells_voltages, set_SoC, filter_set_balancing, stop_simulation] = BMSino(read_step, one_second_step, cells_temperatures, BMS_temperature, cells_voltages, SoC_in)
%% DEFINIZIONE VARIABILI

% Seleziona l'algoritmo di bilanciamento con cui vuoi lavorare tra Av, Bv, Ac, Bc, Ah.
bal_algorithm_selector                = 'Ah';

% Seleziona l'algoritmo di corrente con cui vuoi lavorare tra Av, Bv, Ac e Bc.
cur_algorithm_selector                = 'Ac';

% Seleziona se automatizzare lo stop della simulazione quando tutte le
% tensioni raggiungono un certo valore.
enable_auto_stop_simulation 		  = 0;

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
DELTA_SoC                             = 0.0005;%
CELLS_NUMBER                          = 6;	  % Numero di batterie
test_balance_window                   = 100;  %
filter_window_size                    = 8;	  % Lunghezza del filtro applicato alle tesioni ed alla SoC
MAX_SECURITY_CELL_VOLTAGE             = 4.2;  % V  used for security check
MAX_CELL_VOLTAGE                      = 4.1;  % V  used for SetPoint Estimation alghorithm
MIN_CELL_VOLTAGE                      = 2.5;  % V
CELL_VOLTAGE_START_SP_CH_REDUCTION    = 3.9;  % V
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

persistent CellSoCstatus
if isempty(CellSoCstatus)
    CellSoCstatus=zeros(CELLS_NUMBER,test_balance_window);
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

% CONTROLLA GLI ERRORI: se non ci sono allora esegui il test.
if(isnan(error_high_cell_voltage) &&...
        isnan(error_low_cell_voltage) &&...
        isnan(error_high_cell_SoC) &&...
        isnan(error_low_cell_SoC) &&...
        isnan(error_high_cell_temperature) &&...
        isnan(error_low_cell_temperature) &&...
        isnan(error_high_BMS_temperature))
    %% BILANCIAMENTO
    
    CellVoltage_filtered = filter(b, a, CellVoltageStatus, [], 2);
    LowestCellVoltage = min(CellVoltage_filtered(:, filter_window_size));
    
    CellSoC_filtered = filter(b, a, CellSoCstatus, [], 2);
    LowestCellSoC = min(CellSoC_filtered(:, filter_window_size));
    
    DeltaVoltage = (LowestCellVoltage - CELL_VOLTAGE_START_SP_CH_REDUCTION);
    DeltaVoltageMax = (MAX_CELL_VOLTAGE - CELL_VOLTAGE_START_SP_CH_REDUCTION);
    
    DeltaSoC = (LowestCellSoC - CELL_SoC_START_SP_CH_REDUCTION);
    DeltaSoCMax = (MAX_SoC - CELL_SoC_START_SP_CH_REDUCTION);
    
    % Per avere delle misure di tensione più precise, spegni il
    % bilanciamento prima di ogni lettura, cioè negli istanti X.0.
    if counter == 0 || current_phase == 3
        set_balancing = [0; 0; 0; 0; 0; 0];
        filter_set_balancing = CellBalancingStatus(:, test_balance_window);
    else
        % Applica il bilanciamento verificando che le due condizioni siano
        % soddisfatte:
        % 1. tensione di una cella è vicina a quella più carica di un
        % valore inferiore a DELTA_VOLTAGE_EOB
        % 2. tensione di una cella supera la soglia di bilanciamento.
        if (balancing == 1)
            toWriteCellBalancingStatus = zeros(CELLS_NUMBER, 1);
            for i=1:CELLS_NUMBER
                switch bal_algorithm_selector
                    
                    case 'Ac'
                        
                        if set_SoC(i) < (SoCmax - DELTA_SoC)
                            % non bilanciare!
                            toWriteCellBalancingStatus(i, 1) = 0;
                        else
                            if set_SoC(i) >= CELL_SoC_START_BALANCING
                                % bilancia!
                                toWriteCellBalancingStatus(i, 1) = 1;
                            else
                                % non bilanciare!
                                toWriteCellBalancingStatus(i, 1) = 0;
                            end
                        end
                        
                    case 'Bc'
                        
                        if ((set_SoC(i) > CELL_SoC_START_BALANCING) &  ...
                                (SoCmax < CELL_SoC_START_SP_CH_REDUCTION) &  ...
                                (set_SoC(i) > SoCmin + (set_SoC(i)*((CELL_SoC_START_SP_CH_REDUCTION-SoCmin)*dSoC_dOCV)/(R_BAL*STD_DH_CURRENT))) & ...
                                (set_SoC(i) > SoCmin + DELTA_SoC))
                            
                            toWriteCellBalancingStatus(i, 1) = 1; % bilancia!
                        else
                            if ((set_SoC(i) > CELL_SoC_START_BALANCING) &  ...
                                    (SoCmax >= CELL_SoC_START_SP_CH_REDUCTION) & ...
                                    (set_SoC(i) > SoCmin + DELTA_SoC))
                                
                                toWriteCellBalancingStatus(i, 1) = 1; % bilancia!
                            else
                                toWriteCellBalancingStatus(i, 1) = 0;  % non bilanciare!
                            end
                        end
                        
                    case 'Av'
                        
                        if set_cells_voltages(i) < (Vmax - DELTA_VOLTAGE_EOB)
                            % non bilanciare!
                            toWriteCellBalancingStatus(i, 1) = 0;
                        else
                            if set_cells_voltages(i) >= CELL_VOLTAGE_START_BALANCING
                                % bilancia!
                                toWriteCellBalancingStatus(i, 1) = 1;
                            else
                                % non bilanciare!
                                toWriteCellBalancingStatus(i, 1) = 0;
                            end
                        end
                        
                    case 'Bv'
                        
                        if ((set_cells_voltages(i) > CELL_VOLTAGE_START_BALANCING) &&  ...
                                (Vmax < CELL_VOLTAGE_START_SP_CH_REDUCTION) &&  ...
                                (set_cells_voltages(i) > Vmin + (set_cells_voltages(i)*((CELL_VOLTAGE_START_SP_CH_REDUCTION-Vmin)*dSoC_dOCV)/(R_BAL*STD_DH_CURRENT))) && ...
                                (set_cells_voltages(i) > Vmin + DELTA_VOLTAGE_EOB))
                            
                            toWriteCellBalancingStatus(i, 1) = 1; % bilancia!
                        else
                            if ((set_cells_voltages(i) > CELL_VOLTAGE_START_BALANCING) &&  ...
                                    (Vmax >= CELL_VOLTAGE_START_SP_CH_REDUCTION) && ...
                                    (set_cells_voltages(i) > Vmin + DELTA_VOLTAGE_EOB))
                                
                                toWriteCellBalancingStatus(i, 1) = 1; % bilancia!
                            else
                                toWriteCellBalancingStatus(i, 1) = 0;  % non bilanciare!
                            end
                        end
                        
                    case 'Ah'
                        % Bilancia Av se è iniziata la riduzione di corrente
                        if (Vmax > CELL_VOLTAGE_START_SP_CH_REDUCTION)
                            if set_cells_voltages(i) < (Vmax - DELTA_VOLTAGE_EOB)
                                % non bilanciare!
                                toWriteCellBalancingStatus(i, 1) = 0;
                            else
                                if set_cells_voltages(i) >= CELL_VOLTAGE_START_BALANCING
                                    % bilancia!
                                    toWriteCellBalancingStatus(i, 1) = 1;
                                else
                                    % non bilanciare!
                                    toWriteCellBalancingStatus(i, 1) = 0;
                                end
                            end
                            % Bilancia Ac se la riduzione di corrente non è iniziata
                        else
                            if set_SoC(i) < (SoCmax - DELTA_SoC)
                                % non bilanciare!
                                toWriteCellBalancingStatus(i, 1) = 0;
                            else
                                if set_SoC(i) >= CELL_SoC_START_BALANCING
                                    % bilancia!
                                    toWriteCellBalancingStatus(i, 1) = 1;
                                else
                                    % non bilanciare!
                                    toWriteCellBalancingStatus(i, 1) = 0;
                                end
                            end
                        end
                        
                end
                
            end
            
            % Non bilanciare se è stato già fatto in tutte le celle nei
            % "test_balance_window" secondi precedenti.
            test_all_status = zeros(CELLS_NUMBER, 1);
            test_all_status = logical(test_all_status); % converti da
            % double a logico
            if (clock/one_second_step > test_balance_window)
                for k=0:(test_balance_window - 1)
                    test_all_status = test_all_status | CellBalancingStatus(:, test_balance_window - k);
                end
            end
            if (test_all_status == [1; 1; 1; 1; 1; 1])
                toWriteCellBalancingStatus = [0; 0; 0; 0; 0; 0];
            end
        else
            % Quando non bilancia, lo stato di bilanciamento da fornire
            % alle celle è pari all'ultimo salvato.
            toWriteCellBalancingStatus = CellBalancingStatus(:, test_balance_window);
        end
        % Salva lo stato di bilanciamento nella sua matrice di memoria
        % shiftata verso sinistra.
        CellBalancingStatus = circshift(CellBalancingStatus, [0 -1]);
        CellBalancingStatus(:, test_balance_window) =  toWriteCellBalancingStatus;
        % Manda lo stato di bilanciamento da applicare in uscita.
        set_balancing = toWriteCellBalancingStatus;
        filter_set_balancing = toWriteCellBalancingStatus;
    end
    
    %% STIMA DELLA CORRENTE
    
    switch current_profile
        
        case 'charge'
            
            if  (current_phase ~= 3)
                if (counter == 1)
                    
                    switch cur_algorithm_selector
                        
                        case 'Ac'
                            
                            if (DeltaSoC > 0)
                                if (DeltaSoC <= DeltaSoCMax)
                                    I_out = (1 - (DeltaSoC / DeltaSoCMax)^2) * STD_CH_CURRENT;
                                    if I_out < (CUTOFF_CURRENT / 1000)
                                        I_out = 0;
                                    end
                                else
                                    I_out = 0;
                                end
                            else
                                I_out = STD_CH_CURRENT;
                            end
                            
                        case'Bc'
                            
                            if (DeltaSoC > 0) || (current_phase ~= 0)
                                if (DeltaSoC <= DeltaSoCMax)
                                    if (current_phase ~= 2)
                                        I_out = min(STD_CH_CURRENT,(1-((DeltaSoC-Rint*ChSetPoint)/DeltaSoCMax)^2)*STD_CH_CURRENT);
                                        current_phase = 1;
                                    else
                                        I_out = max((1-(DeltaSoC/DeltaSoCMax)^2)*(MAX_SoC/R_BAL), ChSetPoint*(1-1/tau));
                                    end
                                    if (LowestCellSoC >= CELL_SoC_STOP)
                                        I_out = max( (1 - (DeltaSoC/DeltaSoCMax)^2)*(MAX_SoC/R_BAL), ChSetPoint*(1-1/tau));
                                        current_phase = 2;
                                    end
                                else
                                    I_out = 0;
                                end
                            else
                                I_out = STD_CH_CURRENT;
                            end
                            
                        case 'Av'
                            
                            if (DeltaVoltage > 0)
                                if (DeltaVoltage <= DeltaVoltageMax)
                                    I_out = (1-(DeltaVoltage/DeltaVoltageMax)^2)*STD_CH_CURRENT;
                                    if I_out < (CUTOFF_CURRENT/1000)
                                        I_out = 0;
                                    end
                                else
                                    I_out = 0;
                                end
                            else
                                I_out = STD_CH_CURRENT;
                            end
                            
                        case 'Bv'
                            
                            if (DeltaVoltage > 0) || (current_phase ~= 0)
                                if (DeltaVoltage <= DeltaVoltageMax)
                                    if (current_phase ~= 2)
                                        I_out = min(STD_CH_CURRENT,(1-((DeltaVoltage-Rint*ChSetPoint)/DeltaVoltageMax)^2)*STD_CH_CURRENT);
                                        current_phase = 1;
                                    else
                                        I_out = max((1-(DeltaVoltage/DeltaVoltageMax)^2)*(MAX_CELL_VOLTAGE/R_BAL),ChSetPoint*(1-1/tau));
                                    end
                                    if (LowestCellVoltage >= CELL_VOLTAGE_STOP)
                                        I_out = max((1-(DeltaVoltage/DeltaVoltageMax)^2)*(MAX_CELL_VOLTAGE/R_BAL),ChSetPoint*(1-1/tau));
                                        current_phase = 2;
                                    end
                                else
                                    I_out = 0;
                                end
                            else
                                I_out = STD_CH_CURRENT;
                            end
                            
                    end
                    
                else
                    I_out = ChSetPoint;
                end
                ChSetPoint = I_out;
            else
                transient_time = transient_time + 1;
                I_out = 0;
            end
            
        case 'discharge_9'
            
            I_out = -I0;
            if (clock > 632*one_second_step && clock < 787*one_second_step) || (clock > 1649*one_second_step)
                I_out = 0;
            elseif (clock <= 632*one_second_step)
                I_out = -I1;
                
            elseif (clock >= 787*one_second_step && clock <= 1649*one_second_step)
                I_out = -I2;
            end
            
        case 'full_discharge'
            
            I_out = STD_DH_CURRENT;
            
    end
else
    %% FUNZIONE DI SICUREZZA ATTIVA
    
    if counter == 1
        % Applica i parametri di sicurezza: ferma tutto!
        % Controlla solo se è presente un overvoltage.
        if(~isnan(error_high_cell_voltage) &&...
                isnan(error_low_cell_voltage)  &&...
                isnan(error_high_cell_SoC) &&...
                isnan(error_low_cell_SoC) &&...
                isnan(error_high_cell_temperature) &&...
                isnan(error_low_cell_temperature) &&...
                isnan(error_high_BMS_temperature))
            
            % Azzera la corrente e bilancia solo le celle con overvoltage
            I_out = 0;
            ChSetPoint = I_out;
            toWriteCellBalancingStatus = zeros(CELLS_NUMBER, 1);
            for i=1:CELLS_NUMBER
                
                if CellVoltageStatus(i, filter_window_size) >= MAX_SECURITY_CELL_VOLTAGE
                    % bilancia!
                    toWriteCellBalancingStatus(i, 1) = 1;
                else
                    % non bilanciare!
                    toWriteCellBalancingStatus(i, 1) = 0;
                end
                
                if CellSoCstatus(i, filter_window_size) >= MAX_SECURITY_CELL_SoC
                    % bilancia!
                    toWriteCellBalancingStatus(i, 1) = 1;
                else
                    % non bilanciare!
                    toWriteCellBalancingStatus(i, 1) = 0;
                end
                
            end
            % Manda lo stato di bilanciamento da applicare in uscita
            % e salvalo nella sua matrice shiftata verso sinistra.
            set_balancing = toWriteCellBalancingStatus;
            filter_set_balancing = toWriteCellBalancingStatus;
            CellBalancingStatus = circshift(CellBalancingStatus, [0 -1]);
            CellBalancingStatus(:, test_balance_window) = toWriteCellBalancingStatus;
        else
            % Ferma il bilanciamento e la carica in tutti gli altri casi.
            I_out = 0;
            ChSetPoint = I_out;
            set_balancing = [0; 0; 0; 0; 0; 0];
            filter_set_balancing = [0; 0; 0; 0; 0; 0];
            CellBalancingStatus = circshift(CellBalancingStatus, [0 -1]);
            CellBalancingStatus(:, test_balance_window) = set_balancing;
        end
    else
        % Quando non si esegue una nuova lettura, manda in uscita gli
        % ultimi valori di corrente e stato di bilanciamento salvati.
        I_out = ChSetPoint;
        set_balancing = CellBalancingStatus(:, test_balance_window);
        filter_set_balancing = CellBalancingStatus(:, test_balance_window);
    end
    
    
end
