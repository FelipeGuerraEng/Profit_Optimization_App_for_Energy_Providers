% Parámetros
int: n; % Número de días en el horizonte de planificación
int: m; % Número de clientes
int: dias_regimen_alto_permitidos; % Número de días consecutivos permitidos en régimen alto
int: porcentaje_regimen_alto; % Porcentaje de la capacidad que se considera régimen alto
set of int: DIAS = 1..n;
set of int: CLIENTES = 1..m; 
set of int: PLANTAS = 1..3; % Conjunto de plantas: 1-Nuclear, 2-Hidroeléctrica, 3-Térmica

array[PLANTAS] of int: capacidad; % Capacidad de producción diaria para cada planta
array[PLANTAS] of int: costo_produccion; % Costo de producción por MW para cada planta
array[CLIENTES,DIAS] of int: demanda; % Demanda diaria para cada cliente
array[CLIENTES] of int: pago_por_mw; % Pago por MW para cada cliente 
int: G; % Porcentaje mínimo de la demanda que debe ser satisfecha

% Variables
array[PLANTAS,DIAS] of var 0..max(capacidad): produccion; % Producción diaria para cada planta
array[CLIENTES,DIAS] of var 0..max([demanda[c,d] | c in CLIENTES, d in DIAS]): entregado; % Energía entregada a cada cliente

% Restricciones

% La producción total diaria no debe exceder la capacidad de las plantas
constraint forall(d in DIAS, p in PLANTAS) (
    produccion[p,d] <= capacidad[p]
);

% La energía entregada a cada cliente debe ser igual a su demanda o al menos G% de la demanda si no es posible satisfacerla completamente
constraint forall(c in CLIENTES, d in DIAS) (
    entregado[c,d] >= G * demanda[c,d] / 100
    /\ 
    entregado[c,d] <= demanda[c,d]
);

% La energía total entregada no debe exceder la producción total
constraint forall(d in DIAS) (
    sum(c in CLIENTES) (entregado[c,d]) <= sum(p in PLANTAS) (produccion[p,d])
);

% La central hidroeléctrica no puede operar en régimen alto por dos días consecutivos
constraint forall(d in 2..n) (
    if produccion[2,d] > porcentaje_regimen_alto * capacidad[2] / 100 then
        produccion[2,d-1] <= porcentaje_regimen_alto * capacidad[2] / 100
    else
        true
    endif
);


% Objetivo: Maximizar la ganancia neta
var int: ganancia_neta = sum(c in CLIENTES, d in DIAS) (entregado[c,d] * pago_por_mw[c]) - 
                         sum(p in PLANTAS, d in DIAS) (produccion[p,d] * costo_produccion[p]);
                    
solve maximize ganancia_neta;

% Mostrar las soluciones
output [ 
    "Ganancia Neta: ", show(ganancia_neta), "\n",
    "Producción:\n"
] 
++ [if d == 1 then "Planta " ++ show(p) ++ ": " else "" endif 
    ++ show(produccion[p,d]) ++ if d == n then "\n" else ", " endif | p in PLANTAS, d in DIAS]
++ [ 
    "Entregado:\n"
]
++ [if d == 1 then "Cliente " ++ show(c) ++ ": " else "" endif 
    ++ show(entregado[c,d]) ++ if d == n then "\n" else ", " endif | c in CLIENTES, d in DIAS];
