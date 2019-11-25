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