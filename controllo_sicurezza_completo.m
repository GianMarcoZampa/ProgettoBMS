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