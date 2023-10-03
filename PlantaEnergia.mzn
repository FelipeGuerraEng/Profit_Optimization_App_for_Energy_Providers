% Parámetros
int: n; % Número de días en el horizonte de planificación
int: m; % Número de clientes
int: dias_regimen_alto_permitidos; % Número de días consecutivos permitidos en régimen alto
int: porcentaje_regimen_alto; % Porcentaje de la capacidad que se considera régimen alto
set of int: DIAS = 1..n;
set of int: CLIENTES = 1..m; 
set of int: PLANTAS = 1..3; % Conjunto de plantas: 1-Nuclear, 2-Hidroeléctrica, 3-Térmica

array[DIAS] of var 0..n: dias_regimen_alto;
array[PLANTAS] of int: capacidad; % Capacidad de producción diaria para cada planta
array[PLANTAS] of float: costo_produccion; % Costo de producción por MW para cada planta
array[CLIENTES,DIAS] of int: demanda; % Demanda diaria para cada cliente
array[CLIENTES] of float: pago_por_mw; % Pago por MW para cada cliente 
int: G; % Porcentaje mínimo de la demanda que debe ser satisfecha

% Variables
array[PLANTAS,DIAS] of var int: produccion; % Producción diaria para cada planta
array[CLIENTES,DIAS] of var int: entregado; % Energía entregada a cada cliente

% Restricciones

% La producción total diaria no debe exceder la capacidad de las plantas
constraint forall(d in DIAS, p in PLANTAS) (
    produccion[p,d] <= capacidad[p] /\ produccion[p,d] >= 0
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


% Restricciones de regimen alto para la Central Hidroeléctrica

constraint dias_regimen_alto[1] = if produccion[2,1] > porcentaje_regimen_alto * capacidad[2] / 100 then 1 else 0 endif;

constraint forall(d in 2..n) (
    dias_regimen_alto[d] = if produccion[2,d] > porcentaje_regimen_alto * capacidad[2] / 100 then
        dias_regimen_alto[d-1] + 1
    else
        0
    endif
);

constraint forall(d in DIAS) (
    dias_regimen_alto[d] <= dias_regimen_alto_permitidos
);


% Objetivo: Maximizar la ganancia neta
var float: ganancia_neta = sum(c in CLIENTES, d in DIAS) (entregado[c,d] * pago_por_mw[c]) - 
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
