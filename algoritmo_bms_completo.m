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
        
end