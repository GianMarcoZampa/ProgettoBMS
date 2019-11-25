switch current_profile
    
    case 'charge'
        
        if  (current_phase ~= 3)
            if (counter == 1)
                
                CellVoltage_filtered = filter(b, a, CellVoltageStatus, [], 2);
                LowestCellVoltage = min(CellVoltage_filtered(:, filter_window_size));
                
                CellSoC_filtered = filter(b, a, CellSoCstatus, [], 2);
                LowestCellSoC = min(CellSoC_filtered(:, filter_window_size));
                
                DeltaVoltage = (LowestCellVoltage - CELL_VOLTAGE_START_SP_CH_REDUCTION);
                DeltaVoltageMax = (MAX_CELL_VOLTAGE - CELL_VOLTAGE_START_SP_CH_REDUCTION);
                
                DeltaSoC = (LowestCellSoC - CELL_SoC_START_SP_CH_REDUCTION);
                DeltaSoCMax = (MAX_SoC - CELL_SoC_START_SP_CH_REDUCTION);
                
                switch cur_algorithm_selector
                    
                    case 'Ac'
                        
                        if (DeltaSoC > 0)
                            if (DeltaSoC <= DeltaSoCMax)
                                I_out = (1 - (DeltaSoC / DeltaSoCMax)) * STD_CH_CURRENT;
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
                                    I_out = min(STD_CH_CURRENT,(1 - ((DeltaSoC-Rint*ChSetPoint) / DeltaSoCMax)) * STD_CH_CURRENT);
                                    current_phase = 1;
                                else
                                    I_out = max( (1 - (DeltaSoC/DeltaSoCMax)) *(MAX_SoC/R_BAL), ChSetPoint *(1-1/tau));
                                end
                                if (LowestCellSoC >= CELL_SoC_STOP)
                                    I_out = max( (1 - (DeltaSoC/DeltaSoCMax)) *(MAX_SoC/R_BAL), ChSetPoint *(1-1/tau));
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
                                I_out = (1 - (DeltaVoltage / DeltaVoltageMax)) * STD_CH_CURRENT;
                                if I_out < (CUTOFF_CURRENT / 1000)
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
                                    I_out = min(STD_CH_CURRENT,(1 - ((DeltaVoltage-Rint*ChSetPoint) / DeltaVoltageMax)) * STD_CH_CURRENT);
                                    current_phase = 1;
                                else
                                    I_out = max( (1 - (DeltaVoltage/DeltaVoltageMax)) *(MAX_CELL_VOLTAGE/R_BAL), ChSetPoint *(1-1/tau));
                                end
                                if (LowestCellVoltage >= CELL_VOLTAGE_STOP)
                                    I_out = max( (1 - (DeltaVoltage/DeltaVoltageMax)) *(MAX_CELL_VOLTAGE/R_BAL), ChSetPoint *(1-1/tau));
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