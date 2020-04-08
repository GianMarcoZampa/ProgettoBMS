% Initialization file for example battery model ssc_lithium_cell_2RC.mdl
clear;
%% Time setting

% Durata della simulazione.
test_time               = 20000; % secondi
 
% Decidi lo step temporale con cui verrà eseguita la simulazione.
solver_step             = 0.1;  % secondi

% Decidi ogni quanti secondi effettuare la lettura delle celle.
read_clock              = 1;    % secondi

% Converti lo step del solver nello step di istanti che equivale a 1
% secondo.
one_second_step = round(1/solver_step);

% Converti lo step del solver nello step di istanti in cui verrà eseguito
% il codice e letto le celle.
read_step = round(read_clock/solver_step);
%% Valore iniziale per la carica sulle celle

% Decidi con quali OCV deve lavorare successivamente, i disponibili sono
% 12, 10 e 'discharge 12',  0= celle identiche alla 5.
OCV_selector = 12; 
identical_cell_selector = 0; % 0 celle diverse, 1= celle identiche alla 5.

% Decidi quale prova simulare, i disponibili sono 'charge_12, 10, 15, 6',
% 'discharge', 'parameter_estimation'.
Q_selector = 'test_10';

% Seleziona la carica iniziale Q.
switch Q_selector
    
    case 'test_0'
        Q = [40 40 40 40 40 40];
    case 'test_00'
        Q = [43 45 39 35 41 37]; % celle identiche con OCV della cella 5
    case 'test_10'
        Q = [43 45 39 35 41 37];
    case 'charge_12'
        % PROVA 12
        %Q = [0 0 33 35 20 32]; % excel
        %12a Q = [1 1 36 38 23 35]; % migliore con OCV 12
        Q = [4 3 34 36.4 25.6 33]; % migliore con OCV 12
    case 'charge_10'
        % PROVA 10
        %Q = [41 35 39 51 36 51]; % excel
        %Q = [43 33 46 65 52 59]; % migliore con OCV 12
         Q = [47 37 46 66 58 59]; % migliore con OCV 12 nuovi e v.5
    case 'charge_15'
        % PROVA 15
         Q = [59 58 59 57 55 59]; % excel
    case 'charge_6'
        % PROVA 6
         %Q = [70 60 68 60 30 25]; % excel
         %Q = [62 48 66 63 44 32]; % migliore con OCV 12
         Q = [68 50 66 63 39 28]; % migliore con OCV 12 nuovi e v.5
    case 'discharge'
         Q = [90 90 90 90 90 90];
    case 'discharge_9'
         %Q = [49 43 55.5 54 51 48]; %da REF
         %previous Q = [51.4 45.3 57.8 56 53 50];   
         Q = [57.6 50 59. 56 53 50];     
end
%% Thermal Properties

R_BALANCING = 10;

% Ambient Temperature
T_amb = 20; %°C

% Initial temperature of the cells, which can be different from the
% ambient one
T_init = 25 + 273.15; %°K

% Massa della singola cella
cell_mass = 47.5;   %g

% Area di una cella
Area_laterale = 2*pi*0.004*0.065;
cell_contact_area = Area_laterale/4;
Area_base = 2*pi*(0.004)^2;
Area_totale = Area_laterale + Area_base;
cell_area = Area_totale; %m^2

% Calore specifico di una cella, è stato ricavato da dati sperimentali
% condotti su di un pacco di 12 celle al litio del tipo da noi utilizzato.
cell_Cp_heat = 800; %J/kg/K

% In numerose pubblicazioni viene rappresentato come valore credibile per
% il coefficiente di trasferimento del calore tra ambiente esterno ed una
% batteria al litio, in particolare è utilizzato per le celle esterne del 
% pacco poichè sono le più esposte all'ambiente esterno.
% Le batterie centrali del pacco trasferiscono tra di loro circa la metà
% del calore rispetto a quanto succede tra l'ambiente e le celle.
h_conv = 20; %W/m^2*K 

% Valore sperimentale usato per descrivere i moti convettivi tra resistenze
% ed ambiente, dove c'è la presenza di una ventola che aiuta ad aumentare
% il valore
h_conv_res = 12500;

% Area del resistore di bilanciamento
res_area = 4e-6; %m^2

% Massa del resistore di bilanciamento
res_mas = 0.010; %Kg

% Calore specifico del resistore 
res_Cp_heat = 1000; 

% Dissipazione di energia dai resistori
Dissipation_factor = 1;
%% Excel export

% Decidi se attivare o meno l'esportazione su file excel dei risultati della simulazione. Si = 1, No = 0
% N.B. i dati saranno disposti in colonne, dove il primo segnale è nella prima porta del multiplexer nel blocco "To workspace".
% I dati non possono essere sovrascritti su un foglio o file excel già esistente.
enable_excel_export = 0; 

% Decidi nome del file excel da generare
filename = 'export_data_new.xlsx';

% Decidi nome del foglio in cui scrivere
sheet = 't_10_neq_BilaA_CurA_Ch4_B3.7';
%% Lookup Table Breakpoints

SOC_LUT = [0 0.05 0.1 0.15 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 0.995 1.0 1.005 1.02]';
Temperature_LUT = [0 25 40] + 273.15;%% Initial Conditions
%% Em n.1 Branch Properties

% Battery capacity
Capacity_LUT_1 = [3.0  3.250  3.35]; %Ampere*hours
if (T_init - 273.15) == 0
   Capacity = Capacity_LUT_1(1,1);
elseif (T_init - 273.15) == 25
       Capacity = Capacity_LUT_1(1,2); 
       elseif (T_init - 273.15) == 40
              Capacity = Capacity_LUT_1(1,3);
else 
    disp('Errore inserimento valore di temperatura');
end

% Charge deficit at start of data set.
% Assumption based on preparation of test.
Qe_init_1 = (1 - Q(1,1)*0.01)*Capacity; %A*hr
switch OCV_selector
  case 12
    tmp=[3.42 3.469 3.508 3.528 3.558 3.62 3.69 3.78 3.865 3.945 4.024 4.103 4.219 4.253 4.3 4.5]';
  case 10
    tmp=[3.394 3.438 3.482 3.526 3.57 3.659 3.747 3.835 3.923 4.012 4.10 4.188 4.272 4.276 4.281 4.294]';
  case 'discharge_12'
    tmp=[2.50 2.90 3.258 3.548 3.588 3.66 3.74 3.826 3.905 3.985 4.064 4.143 4.219 4.223 4.227 4.238]';
end
Em_LUT_1 = [tmp tmp tmp]; 
%% Em n.2 Branch Properties

% Battery capacity
Capacity_LUT_2 = [ 3.0  3.250  3.35 ]; %Ampere*hours
if (T_init - 273.15) == 0
   Capacity = Capacity_LUT_2(1,1);
elseif (T_init - 273.15) == 25
       Capacity = Capacity_LUT_2(1,2); 
       elseif (T_init - 273.15) == 40
              Capacity = Capacity_LUT_2(1,3);
else 
    disp('Errore inserimento valore di temperatura');
end

% Charge deficit at start of data set.
% Assumption based on preparation of test.
Qe_init_2 = (1 - Q(1,2)*0.01)*Capacity; %A*hr
switch OCV_selector
  case 12
    tmp=[3.4 3.480 3.521 3.546 3.583 3.640 3.722 3.824 3.906 3.998 4.090 4.173 4.253 4.293 4.34 4.54]';
  case 10
    tmp=[3.364 3.412 3.46 3.508 3.556 3.652 3.748 3.844 3.94 4.036 4.132 4.228 4.319 4.324 4.328 4.343]';
  case 'discharge_12'
    tmp=[2.50 2.90 3.258 3.562 3.603 3.685 3.766 3.848 3.930 4.012 4.093 4.175 4.253 4.257 4.261 4.273]';
end
Em_LUT_2 = [tmp tmp tmp]; 
%% Em n.3 Branch Properties

% Battery capacity
Capacity_LUT_3 = [ 3.0  3.25  3.35]; %Ampere*hours
% REF Capacity_LUT_3 = [3.0 3.25 3.35];
          
if (T_init - 273.15) == 0
   Capacity = Capacity_LUT_3(1,1);
    elseif (T_init - 273.15) == 25
         Capacity = Capacity_LUT_3(1,2); 
         elseif (T_init - 273.15) == 40
              Capacity = Capacity_LUT_3(1,3);
else 
    disp('Errore inserimento valore di temperatura');
end

% Charge deficit at start of data set.
% Assumption based on preparation of test.
Qe_init_3 = (1 - Q(1,3)*0.01)*Capacity; %A*hr
switch OCV_selector
  case 12
    tmp=[3.200 3.362 3.407 3.452 3.498 3.594 3.67 3.76 3.846 3.944 4.036 4.128 4.215 4.253  4.24  4.46]';
  case 10
    tmp=[3.379 3.425 3.471 3.516 3.562 3.653 3.745 3.836 3.927 4.019 4.11 4.201 4.288 4.293 4.297 4.311]';
  case 'discharge_12'
    tmp=[2.50 2.90 3.258 3.452 3.49 3.588 3.679 3.77 3.861 3.951 4.042 4.133 4.219 4.223 4.228 4.241]';
end
Em_LUT_3 = [tmp tmp tmp]; 
%% Em n.4 Branch Properties

% Battery capacity
Capacity_LUT_4 = [ 3.0  3.250  3.35]; %Ampere*hours
if (T_init - 273.15) == 0
   Capacity = Capacity_LUT_4(1,1);
elseif (T_init - 273.15) == 25
       Capacity = Capacity_LUT_4(1,2); 
       elseif (T_init - 273.15) == 40
              Capacity = Capacity_LUT_4(1,3);
else 
    disp('Errore inserimento valore di temperatura');
end

% Charge deficit at start of data set.
% Assumption based on preparation of test.
Qe_init_4 = (1 - Q(1,4)*0.01)*Capacity; %A*hr
switch OCV_selector
  case 12
    tmp=[3.000 3.315 3.36 3.406 3.481 3.584 3.636 3.718 3.808  3.901 3.993 4.084 4.174 4.193 4.24 4.46]';
  case 10
    tmp=[3.297 3.349 3.4 3.452 3.503 3.606 3.709 3.812 3.915 4.018 4.121 4.234 4.321 4.326 4.332 4.347]';
  case 'discharge_12'
    tmp=[2.50 2.90 3.258 3.406 3.451 3.543 3.634 3.725 3.816 3.907 3.999 4.09 4.177 4.181 4.186 4.199]';
end
Em_LUT_4 = [tmp tmp tmp]; 
%% Em n.5 Branch Properties

% Battery capacity
Capacity_LUT_5 = [3.0  3.250  3.35]; %Ampere*hours

if (T_init - 273.15) == 0
   Capacity = Capacity_LUT_5(1,1);
elseif (T_init - 273.15) == 25
       Capacity = Capacity_LUT_5(1,2); 
       elseif (T_init - 273.15) == 40
              Capacity = Capacity_LUT_5(1,3);
else 
    disp('Errore inserimento valore di temperatura');
end

% Charge deficit at start of data set.
% Assumption based on preparation of test.
Qe_init_5 = (1 - Q(1,5)*0.01)*Capacity; %A*hr
switch OCV_selector
  case 12
    tmp=[3.000 3.396 3.436 3.475 3.525 3.584 3.633 3.702 3.79 3.8720 3.975 4.064 4.142 4.163 4.2   4.4]';
  case 10
    tmp=[3.474 3.513 3.551 3.590 3.628 3.705 3.782 3.859 3.936 4.013 4.090 4.167 4.241 4.245 4.248 4.26]';
  case 'discharge_12'
    tmp=[2.50 2.90 3.258 3.475 3.515 3.594 3.673 3.752 3.831 3.910 3.989 4.068 4.143 4.147 4.151 4.163]';
end
Em_LUT_5 = [tmp tmp tmp]; 
%% Em n.6 Branch Properties

% Battery capacity
Capacity_LUT_6 = [3.0  3.250  3.35]; %Ampere*hours
if (T_init - 273.15) == 0
   Capacity = Capacity_LUT_6(1,1);
elseif (T_init - 273.15) == 25
       Capacity = Capacity_LUT_6(1,2); 
       elseif (T_init - 273.15) == 40
              Capacity = Capacity_LUT_6(1,3);
else 
    disp('Errore inserimento valore di temperatura');
end

% Charge deficit at start of data set.
% Assumption based on preparation of test.
Qe_init_6 = (1 - Q(1,6)*0.01)*Capacity; %A*hr
switch OCV_selector
    case 12
    tmp=[3.0 3.375 3.42 3.464 3.509 3.618 3.688 3.784 3.869 3.95 4.04 4.13 4.218 4.253 4.3 4.5]';
  case 10
    tmp=[3.328 3.376 3.424 3.473 3.521 3.618 3.714 3.811 3.907 4.004 4.101 4.197 4.289 4.294 4.299 4.313]';
  case 'discharge_12'
    tmp=[2.50 2.90 3.258 3.464 3.509 3.598 3.688 3.777 3.867 3.956 4.046 4.135 4.22 4.224 4.229 4.242]';
end
Em_LUT_6 = [tmp tmp tmp]; 
%% RC Branch 1 vs SOC rows and T columns

% Imposta i valori dei parametri della cella 1
R0 = 0.065; %Ohms
R1 = 0.018; %Ohms
R2 = 0.021; %Ohms
C1 = 2000;   %Farads
C2 = 20000 ; %Farads
  tmpR0=[R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0]';
  R0_LUT_1 = [tmpR0 tmpR0 tmpR0]; 
  tmpR1=[R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1]';
  R1_LUT_1 = [tmpR1 tmpR1 tmpR1]; 
  tmpC1=[C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1]';
  C1_LUT_1 = [tmpC1 tmpC1 tmpC1]; 
  tmpR2=[R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2]';
  R2_LUT_1 = [tmpR2 tmpR2 tmpR2]; 
  tmpC2=[C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2]';
  C2_LUT_1 = [tmpC2 tmpC2 tmpC2]; 
%% RC Branch 2 vs SOC rows and T columns

% Imposta i valori dei parametri della cella 2
R0 = 0.0770; %Ohms
R1 = 0.0190; %Ohms
R2 = 0.0180; %Ohms
C1 = 2000;   %Farads
C2 = 20000;  %Farads
  tmpR0=[R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0]';
  R0_LUT_2 = [tmpR0 tmpR0 tmpR0]; 
  tmpR1=[R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1]';
  R1_LUT_2 = [tmpR1 tmpR1 tmpR1]; 
  tmpC1=[C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1]';
  C1_LUT_2 = [tmpC1 tmpC1 tmpC1]; 
  tmpR2=[R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2]';
  R2_LUT_2 = [tmpR2 tmpR2 tmpR2]; 
  tmpC2=[C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2]';
  C2_LUT_2 = [tmpC2 tmpC2 tmpC2]; 
%% RC Branch 3 vs SOC rows and T columns

% Imposta i valori dei parametri della cella 3
R0 = 0.0715; %Ohms
R1 = 0.021; %Ohms
R2 = 0.018; %Ohms
C1 = 2000;   %Farads
C2 = 20000;  %Farads
  tmpR0=[R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0]';
  R0_LUT_3 = [tmpR0 tmpR0 tmpR0]; 
  tmpR1=[R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1]';
  R1_LUT_3 = [tmpR1 tmpR1 tmpR1]; 
  tmpC1=[C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1]';
  C1_LUT_3 = [tmpC1 tmpC1 tmpC1]; 
  tmpR2=[R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2]';
  R2_LUT_3 = [tmpR2 tmpR2 tmpR2]; 
  tmpC2=[C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2]';
  C2_LUT_3 = [tmpC2 tmpC2 tmpC2]; 
%% RC Branch 4 vs SOC rows and T columns

% Imposta i valori dei parametri della cella 4
R0 = 0.0640;  %Ohms
R1 = 0.0270;  %Ohms
R2 = 0.0120;  %Ohms
C1 = 1666.7;  %Farads
C2 = 66666.7; %Farads
  tmpR0=[R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0]';
  R0_LUT_4 = [tmpR0 tmpR0 tmpR0]; 
  tmpR1=[R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1]';
  R1_LUT_4 = [tmpR1 tmpR1 tmpR1]; 
  tmpC1=[C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1]';
  C1_LUT_4 = [tmpC1 tmpC1 tmpC1]; 
  tmpR2=[R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2]';
  R2_LUT_4 = [tmpR2 tmpR2 tmpR2]; 
  tmpC2=[C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2]';
  C2_LUT_4 = [tmpC2 tmpC2 tmpC2]; 
%% RC Branch 5 vs SOC rows and T columns

% Imposta i valori dei parametri della cella 5
R0 = 0.110;   %Ohms
R1 = 0.023;   %Ohms
R2 = 0.013;   %Ohms
C1 = 1666.7;  %Farads
C2 = 61538.5; %Farads
  tmpR0=[R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0]';
  R0_LUT_5 = [tmpR0 tmpR0 tmpR0]; 
  tmpR1=[R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1]';
  R1_LUT_5 = [tmpR1 tmpR1 tmpR1]; 
  tmpC1=[C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1]';
  C1_LUT_5 = [tmpC1 tmpC1 tmpC1]; 
  tmpR2=[R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2]';
  R2_LUT_5 = [tmpR2 tmpR2 tmpR2]; 
  tmpC2=[C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2]';
  C2_LUT_5 = [tmpC2 tmpC2 tmpC2]; 
%% RC Branch 6 vs SOC rows and T columns

% Imposta i valori dei parametri della cella 6
R0 = 0.064;   %Ohms
R1 = 0.023;   %Ohms
R2 = 0.013;   %Ohms
C1 = 1956.5;  %Farads
C2 = 61538.5; %Farads
  tmpR0=[R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0 R0]';
  R0_LUT_6 = [tmpR0 tmpR0 tmpR0]; 
  tmpR1=[R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1 R1]';
  R1_LUT_6 = [tmpR1 tmpR1 tmpR1]; 
  tmpC1=[C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1]';
  C1_LUT_6 = [tmpC1 tmpC1 tmpC1]; 
  tmpR2=[R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2 R2]';
  R2_LUT_6 = [tmpR2 tmpR2 tmpR2]; 
  tmpC2=[C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2 C2]';
  C2_LUT_6 = [tmpC2 tmpC2 tmpC2]; 

  
switch identical_cell_selector
  case 0 
    
  case 1
    Em_LUT_1 =Em_LUT_5;
    Em_LUT_2 =Em_LUT_5;
    Em_LUT_3 =Em_LUT_5;    
    Em_LUT_4 =Em_LUT_5;
    Em_LUT_6 =Em_LUT_5;
    
    R0_LUT_1 = R0_LUT_5; 
    R1_LUT_1 = R1_LUT_5; 
    R2_LUT_1 = R2_LUT_5;
    C1_LUT_1 = C1_LUT_5;
    C2_LUT_1 = C2_LUT_5;
    
    R0_LUT_2 = R0_LUT_5; 
    R1_LUT_2 = R1_LUT_5; 
    R2_LUT_2 = R2_LUT_5;
    C1_LUT_2 = C1_LUT_5;
    C2_LUT_2 = C2_LUT_5;
    
    R0_LUT_3 = R0_LUT_5; 
    R1_LUT_3 = R1_LUT_5; 
    R2_LUT_3 = R2_LUT_5;
    C1_LUT_3 = C1_LUT_5;
    C2_LUT_3 = C2_LUT_5;
    
    R0_LUT_4 = R0_LUT_5; 
    R1_LUT_4 = R1_LUT_5; 
    R2_LUT_4 = R2_LUT_5;
    C1_LUT_4 = C1_LUT_5;
    C2_LUT_4 = C2_LUT_5;
    
    R0_LUT_6 = R0_LUT_5; 
    R1_LUT_6 = R1_LUT_5; 
    R2_LUT_6 = R2_LUT_5;
    C1_LUT_6 = C1_LUT_5;
    C2_LUT_6 = C2_LUT_5;
end
