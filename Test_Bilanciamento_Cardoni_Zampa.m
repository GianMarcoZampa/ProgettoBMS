close all
clear all
clc

%% INIZIALIZZAZIONE VARIABILI E BMSINO

delete(instrfindall);
global test_info
test_info = test_setup();

% Durata della simulazione. Ogni ciclo dura due secondi:
% 1 sec per le misurazioni e 1 sec per la determinazione
% della corrente e l'applicazione del bilanciamento
n_cycles                              = 150; % Cicli

% Scelta algoritmo di bilanciamento
% Tensioni: 'Av' e 'Bv'
% SoC: 'Ac' e 'Bc'
bal_algorithm_selector                = 'Av';

% Scelta algoritmo di stima della corrente
% Tensioni: 'Av'
% SoC: 'Ac'
cur_algorithm_selector                = 'Av';

% Numero di celle utilizzate
CELLS_NUMBER                          = 6;

% Resistenza di bilanciamento
R_BAL                                 = 10;   % ohm

% Parametri bilanciamento SoC
MAX_SECURITY_CELL_SoC				  = 1;
MAX_CELL_SoC						  = 0.9;  % SoC massima della batteria
MIN_CELL_SoC						  = 0;	  % SoC minima della battera
CELL_SoC_START_SP_CH_REDUCTION		  = 0.8;
CELL_SoC_START_BALANCING			  = 0.8;  % SoC a cui iniziare il bilanciamento
CELL_SoC_STOP 						  = 0.895;% SoC in cui interrompere la carica
DELTA_SoC_STOP						  = 0.005;

% Parametri bilanciamento Tensione (V)
MAX_SECURITY_CELL_VOLTAGE             = 4.2;  % V  used for security check
MAX_CELL_VOLTAGE                      = 4.1;  % V  used for SetPoint Estimation alghorithm
MIN_CELL_VOLTAGE                      = 2.5;  % V
CELL_VOLTAGE_START_SP_CH_REDUCTION    = 3.9;  % V  inizialmente a 4 V
CELL_VOLTAGE_START_BALANCING          = 3.9;  % V  inizialmente era 3.7 V
CELL_VOLTAGE_STOP                     = 4.07; % V  used for stop simulation
DELTA_VOLTAGE_STOP                    = 0.01; % V

% Parametri Temnperatura (°C)
MAX_CELL_TEMPERATURE                  = 40;   % °C
MIN_CELL_TEMPERATURE                  = 0;    % °C
MAX_BMS_TEMPERATURE                   = 75;   % °C


% Filtro applicato alla tensione ed alla temperatura
test_balance_window                   = 100;
filter_window_size                    = 8;

b = (1/filter_window_size) * ones(1, filter_window_size);
a = 1;

% Altri parametri
Rint                                  = 0.03; % ohm
dSoC_dOCV                             = 1;
CUTOFF_CURRENT                        = 65;   % mA
STD_CH_CURRENT                        = 1.50;  % A
STD_DH_CURRENT                        = 1.6;   % A
DELTA_VOLTAGE_EOB                     = 0.05;  % V

% Variabili di stato del sistema
CellBalancingStatus     = zeros(CELLS_NUMBER, test_balance_window);
CellBalancingTotal      = zeros(CELLS_NUMBER, n_cycles);
CellVoltageStatus       = zeros(CELLS_NUMBER, filter_window_size);
CellVoltageTotal        = zeros(CELLS_NUMBER, n_cycles);
CellTemperatureStatus   = zeros(CELLS_NUMBER, 1);
CellTemperatureTotal    = zeros(CELLS_NUMBER, n_cycles);
BMSTemperatureStatus    = 0;
BMSTemperatureTotal     = zeros(1, n_cycles);
CellCurrentStatus       = 0;
CellSoCTotal            = zeros(CELLS_NUMBER, n_cycles);
I_DCDC_Total            = zeros(1, n_cycles);

% Inizio comunicazione BMSino
test_info.B3603.setOutput(1);
pause(0.5);

%% CICLO DI BILANCIAMENTO

for k=1:n_cycles
    
    set_balancing =[0; 0; 0; 0; 0; 0];
    test_info.BMSino.setBalancingStatus(set_balancing); %%%Spengo il bilanciamento prima della lettura
    
    % Lettura della temperatura delle celle
    %     CellTemperatureTotal = circshift (CellTemperatureTotal, [0 -1]);
    %
    %     test_info.BMSino.getTemperatures();
    %     pause(0.5);
    %
    %     CellTemperatureStatus(:,1) = test_info.BMSino.CellsTemperatures(:,1);
    %     CellTemperatureTotal(:,test_time/10) = CellTemperatureStatus(:,1);
    %     Tcmax = max(CellTemperatureStatus(:, 1));
    %     Tcmin = min(CellTemperatureStatus(:, 1));
    %
    %     Temperature = sprintf('TEMPERATURE CELLE: 1) %.2f 2) %.2f 3) %.2f 4) %.2f 5) %.2f 6) %.2f\n',CellTemperatureStatus(:,filter_window_size));
    %     disp(Temperature);
    
    % Lettura della temperatura del BMSino
    %     BMSTemperatureTotal = circshift (BMSTemperatureTotal, [0 -1]);
    %
    %     test_info.BMSino.getBMSTemperature;
    %     pause(0.1);
    %
    %     BMSTemperatureStatus = test_info.BMSino.BMSTemperature;
    %     BMSTemperatureTotal(1,test_time) = BMSTemperatureStatus;
    %
    %     Temp_BMS_CELLS = sprintf('BMS TEMP: %i \n',BMS_Temperature);
    %     disp(Temp_BMS_CELLS);
    
    % Lettura delle tensioni delle celle
    CellVoltageStatus = circshift (CellVoltageStatus, [0 -1]);
    CellVoltageTotal = circshift (CellVoltageTotal, [0 -1]);
    
    test_info.BMSino.getVoltages();
    pause(0.1);
    
    CellVoltageStatus(:, filter_window_size) = test_info.BMSino.CellsVoltages;
    CellVoltageStatus(:, filter_window_size) = CellVoltageStatus(:, filter_window_size)/1000; %ottengo le tensioni in mV per confrontarle con le tensioni di riferimento
    CellVoltageTotal(:,test_time) = CellVoltageStatus(:, filter_window_size);
    
    set_cells_voltages = CellVoltageStatus(:, filter_window_size);
    Vmax = max(set_cells_voltages(:));
    Vmin = min(set_cells_voltages(:));
    
    Tensioni = sprintf('TENSIONI CELLE: 1) %.2f 2) %.2f 3) %.2f 4) %.2f 5) %.2f 6) %.2f\n',CellVoltageStatus(:,filter_window_size));
    disp(Tensioni);
    
    % Calcolo della SoC tramite ukf
    I_DCDC = I_DCDC_Total(1,n_cycles);
    stato_ini = [0;0;0.13;0.13;0.13;0.13;0.13;0.13;I_out_cells(1);I_out_cells(2);I_out_cells(3);I_out_cells(4);I_out_cells(5);I_out_cells(6)];
    mis=2.5;
    z=mis;
    f=@predict_vector;
    h=@correct;
    cov_ini=diag([1,1,0.01,0.01,0.01,0.01,0.01,0.01,0.01,0.01,0.01,0.01,0.01,0.01]);
    cov_proc=diag([ 3e-9,3e-9,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6,2e-6]);
    cov_mis=1e-3;
    
    if k==1
        x = stato_ini;
    else
        x = x_out;
    end
    
    CellSoCTotal = circshift (CellSoCTotal, [0 -1]);
    [x_out,P] = ukf(f,x,cov_ini,h,z,cov_proc,cov_mis);
    
    CellSoCTotal(:,n_cycles) = [x_out(3),x_out(4),x_out(5),x_out(6),x_out(7),x_out(8)];
    set_SoC = CellSoCTotal(:,n_cycles);
    SoCmax = max(set_SoC(:));
    SoCmin = min(set_SoC(:));
    
    Soc=sprintf('SoC stimato: cella1 %f%%  cella2 %f%%  cella3 %f%%  cella4 %f%%  cella5 %f%%  cella6 %f%% ',CellSoCTotal(:,n_cycles));
    disp(Soc);
    
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
    if SoCmax > MAX_SECURITY_CELL_SOC
        error_high_cell_soc = SoCmax;
    else
        error_high_cell_soc = NaN;
    end
    if SoCmin < MIN_CELL_SOC
        error_low_cell_soc = SoCmin;
    else
        error_low_cell_soc = NaN;
    end
    % if Tcmax > MAX_CELL_TEMPERATURE
    %     error_high_cell_temperature = Tcmax;
    % else
    %     error_high_cell_temperature = NaN;
    % end
    % if Tcmin < MIN_CELL_TEMPERATURE
    %     error_low_cell_temperature = Tcmin;
    % else
    %     error_low_cell_temperature = NaN;
    % end
    % if BMSTemperatureStatus > MAX_BMS_TEMPERATURE
    %     error_high_BMS_temperature = BMSTemperatureStatus;
    % else
    %     error_high_BMS_temperature = NaN;
    % end
    
    % Controllo assenza errori per eseguire il bilanciamento (No temperatura)
    if(isnan(error_high_cell_voltage) &&...
            isnan(error_low_cell_voltage) &&...
            isnan(error_high_cell_soc) &&...
            isnan(error_low_cell_soc))
        
        % Azzeramento delle condizioni di bilnciamento
        toWriteCellBalancingStatus = zeros(CELLS_NUMBER, 1);
        
        % Esecuzione del bilanciamento per ogni cella
        for i=1:CELLS_NUMBER
            
            % Scelta algoritmo di bilanciamento da applicare
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
                    
                    if ((set_SoC(i) > CELL_SoC_START_BALANCING) &&  ...
                            (SoCmax < CELL_SoC_START_SP_CH_REDUCTION) &&  ...
                            (set_SoC(i) > SoCmin + (set_SoC(i)*((CELL_SoC_START_SP_CH_REDUCTION-SoCmin)*dSoC_dOCV)/(R_BAL*STD_DH_CURRENT))) && ...
                            (set_SoC(i) > SoCmin + DELTA_SoC))
                        
                        toWriteCellBalancingStatus(i, 1) = 1; % bilancia!
                    else
                        if ((set_SoC(i) > CELL_SoC_START_BALANCING) &&  ...
                                (SoCmax >= CELL_SoC_START_SP_CH_REDUCTION) && ...
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
            end
        end
        
        % Se devono essere tutte bilanciate allora non bilanciare nulla
        all_balancing=[1; 1; 1; 1; 1; 1];
        Null_Vector=[0; 0; 0; 0; 0; 0];
        
        if toWriteCellBalancingStatus == all_balancing
            toWriteCellBalancingStatus = Null_Vector;
        end
        
        % Salva lo stato di bilanciamento
        CellBalancingStatus = circshift(CellBalancingStatus, [0 -1]);
        CellBalancingTotal = circshift(CellBalancingTotal, [0 -1]);
        CellBalancingStatus(:, test_balance_window) =  toWriteCellBalancingStatus;
        CellBalancingTotal(:,test_time)=CellBalancingStatus(:, test_balance_window);
        
        % Manda lo stato di bilanciamento da applicare al BMSino.
        test_info.BMSino.setBalancingStatus(toWriteCellBalancingStatus);
        pause(0.5);
        
        
        % Calcolo della corrente in uscita dalle celle
        I_out_cells=zeros(1,CELLS_NUMBER);
        
        CellCurrentStatus = zeros(CELLS_NUMBER, filter_window_size);
        CellCurrentStatus = circshift (CellCurrentStatus, [0 -1]);
        CellCurrentStatus(:, filter_window_size)=CellVoltageStatus(:, filter_window_size)./R_BAL;
        
        
        if toWriteCellBalancingStatus == Null_Vector
            I_out_cells = Null_Vector;
            I_out_tot=0;
        else
            for i=1:CELLS_NUMBER
                if toWriteCellBalancingStatus(i,1)==1
                    I_out_cells(i)=CellCurrentStatus(i, filter_window_size);
                end
                
            end
            
        end
        
        % Stima della corrente
        CellVoltage_filtered = filter(b, a, CellVoltageStatus, [], 2);
        LowestCellVoltage = min(CellVoltage_filtered(:, filter_window_size));
        CellSoC_filtered = filter(b, a, CellSoCstatus, [], 2);
        LowestCellSoC = min(CellSoC_filtered(:, filter_window_size));
        
        % Stima il SetPoint di carica in termini di corrente
        % leggendo la tensione più alta del pacco batterie.
        % Ritorna in uscita un valore in A, non in mA!!!
        DeltaSoC = (LowestCellSoC - CELL_SoC_START_SP_CH_REDUCTION);
        DeltaSoCMax = (MAX_SoC - CELL_SoC_START_SP_CH_REDUCTION);
        DeltaVoltage = (LowestCellVoltage - CELL_VOLTAGE_START_SP_CH_REDUCTION);
        DeltaVoltageMax = (MAX_CELL_VOLTAGE - CELL_VOLTAGE_START_SP_CH_REDUCTION);
        
        I_DCDC_Total=circshift (I_DCDC_Total, [0 -1]);
        
        switch cur_algorithm_selector
            
            case 'Av'
                if DeltaVoltage > 0
                    
                    if DeltaVoltage <= DeltaVoltageMax
                        I_out = (1 - (DeltaVoltage / DeltaVoltageMax)) * STD_CH_CURRENT;
                        test_info.B3603.setCurrent(I_out);
                        
                        if I_out < (CUTOFF_CURRENT / 1000)
                            % Se la corrente di setpoint è molto piccola la
                            % batteria è carica, quindi impostala a zero.
                            I_out = 0;
                            test_info.B3603.setCurrent(I_out);
                        end
                        
                    else
                        I_out = 0;
                        test_info.B3603.setCurrent(I_out);
                    end
                    
                else
                    I_out = STD_CH_CURRENT;
                    test_info.B3603.setCurrent(I_out);
                end
                pause(1.3);
                I_DCDC_Total(1,test_time)=I_out;
            
            case 'Ac'
                if DeltaSoC > 0
                    
                    if DeltaSoC <= DeltaSoCMax
                        I_out = (1 - (DeltaSoC / DeltaVSoCMax)) * STD_CH_CURRENT;
                        test_info.B3603.setCurrent(I_out);
                        
                        if I_out < (CUTOFF_CURRENT / 1000)
                            % Se la corrente di setpoint è molto piccola la
                            % batteria è carica, quindi impostala a zero.
                            I_out = 0;
                            test_info.B3603.setCurrent(I_out);
                        end
                        
                    else
                        I_out = 0;
                        test_info.B3603.setCurrent(I_out);
                    end
                    
                else
                    I_out = STD_CH_CURRENT;
                    test_info.B3603.setCurrent(I_out);
                end
                pause(1.3);
                I_DCDC_Total(1,test_time)=I_out;
        end
    end
    
end
