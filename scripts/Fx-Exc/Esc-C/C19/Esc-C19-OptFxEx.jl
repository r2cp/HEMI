# Script con optimización y evaluación, con datos y configuración de simulación hasta 2019
"""
Escenario C: Evaluación de criterios básicos con cambio de parámetro de evaluación

Es requerido llevar a cabo la optimización de la medida, para ambos períodos de evaluación. 
Se debe nombrar cada escenario como C19 y C20.

Este escenario pretende evaluar las medidas de inflación cambiando la trayectoria de inflación paramétrica por una con cambio 
de base sintético cada cinco años, respecto a la configuración del escenario A.

Los parámetros de configuración en este caso son los siguientes:

 - Período de Evaluación: Diciembre 2001 - Diciembre 2019, ff = Date(2019, 12)
 - Trayectoria de inflación paramétrica con cambios de base cada 5 años, [InflationTotalRebaseCPI(60)].
 - Método de remuestreo de extracciones estocásticas independientes (Remuestreo por meses de ocurrencia), [ResampleScrambleVarMonths()].
 - Muestra completa para evaluación [SimConfig].
"""

## carga de paquetes
using DrWatson
@quickactivate "HEMI"

# Cargar el módulo de Distributed para computación paralela
using Distributed
# Agregar procesos trabajadores
addprocs(4, exeflags="--project")

# Cargar los paquetes utilizados en todos los procesos
@everywhere using HEMI
using DataFrames
using Plots, CSV
##
"""
Resultados de Evaluación 2019 con Matlab
Base 2000: [35,30,190,36,37,40,31,104,162,32,33,159,193,161] (14 Exclusiones)
MSE = 0.777
Base 2010 -> [29, 31, 116, 39, 46, 40, 30, 35, 186, 47, 197, 41, 22, 48, 185, 34, 184] (17 exclusiones)
MSE = 0.64

Escenario A
JULIA , con 125_000 simulaciones para el recorte de 10 vectores de exclusión 
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193, 161] (14 Exclusiones)
Base 2010 -> [29, 31, 116, 39, 46, 40, 30, 35, 186, 47, 197, 41, 22, 48, 185, 34, 184] (17 exclusiones)
MSE = 0.6421985f0

Escenario B
JULIA Date(2020, 12), con 125_000 simulaciones
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193, 161] (14 Exclusiones)
Base 2010 -> [29, 46, 39, 31, 116, 40, 30, 186, 35, 47, 197, 41, 22, 185, 48, 34, 37, 184] (18 exclusiones)
MSE = 0.6460847f0

"""

## Definición de instancias principales
trendfn    = TrendRandomWalk()
resamplefn = ResampleScrambleVarMonths()
paramfn    = InflationTotalRebaseCPI(60)

# Para optimización Base 2000
ff00 = Date(2010,12)
# Para optimización Base 2010
ff10 = Date(2019,12)

#################  Optimización Base 2000  ###################################
 
## Creación de vector de de gastos básicos ordenados por volatilidad.

estd = std(gt00.v |> capitalize |> varinteran, dims=1)

df = DataFrame(num = collect(1:218), Desv = vec(estd))

sorted_std = sort(df, "Desv", rev=true)

vec_v = sorted_std[!,:num]

# Creación de vectores de exclusión
# Se crean 218 vectores para la exploración inicial y se almacenan en v_exc
v_exc = []
for i in 1:length(vec_v)
   exc = vec_v[1:i]
   append!(v_exc, [exc])
end

# Diccionarios para exploración inicial (primero 100 vectores de exclusión)
FxEx_00 = Dict(
    :inflfn => InflationFixedExclusionCPI.(v_exc[1:100]), 
    :resamplefn => resamplefn, 
    :trendfn => trendfn,
    :paramfn => paramfn,
    :nsim => 10_000,
    :traindate => ff00) |> dict_list

savepath = datadir("results","Fx-Exc","Esc-C","C19","B0010K")  

## Lote de simulación con los primeros 100 vectores de exclusión

run_batch(gtdata, FxEx_00, savepath)

## Recolección de resultados
Exc_00C19 = collect_results(savepath)

## Análisis de exploración preliminar
# obtener longitud del vector de exclusión de cada simulación
exclusiones =  getindex.(map(x -> length.(x), Exc_00C19[!,:params]),1)
Exc_00C19[!,:exclusiones] = exclusiones 

# Ordenamiento por cantidad de exclusiones
Exc_00C19 = sort(Exc_00C19, :exclusiones)

# DF ordenado por MSE
sort_00C19 = sort(Exc_00C19, :mse)

## Exctracción de vector de exclusión  y MSE
a = collect(sort_00C19[1,:params])
sort_00C19[1,:mse]

"""
Resultados de Exploración inicial 

MATLAB InflationTotalRebaseCPI(36, 2)
Vector de Exclusión -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193, 161] (14 Exclusiones)
MSE = 0.777

JULIA, con 10K simulaciones y InflationTotalRebaseCPI(60)
Vector de Exclusión ->  [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193] (13 Exclusiones)
MSE = 0.85806346f0

"""
## Evaluación con 125_000 simulaciones al rededor del vector encontrado en la exploración inicial  (del 10 al 20)

FxEx_00 = Dict(
    :inflfn => InflationFixedExclusionCPI.(v_exc[10:20]), 
    :resamplefn => resamplefn, 
    :trendfn => trendfn,
    :paramfn => paramfn,
    :nsim => 125_000,
    :traindate => ff00) |> dict_list

savepath = datadir("results","Fx-Exc","Esc-C","C19","B00125K")  

## Lote de simulación con 10 vectores de exclusión 
run_batch(gtdata, FxEx_00, savepath)

## Recolección de resultados
Exc_00C19 = collect_results(savepath)

## Análisis de exploración preliminar
# obtener longitud del vector de exclusión de cada simulación
exclusiones =  getindex.(map(x -> length.(x), Exc_00C19[!,:params]),1)
Exc_00C19[!,:exclusiones] = exclusiones 

# Ordenamiento por cantidad de exclusiones
Exc_00C19 = sort(Exc_00C19, :exclusiones)

# DF ordenado por MSE
sort_00C19 = sort(Exc_00C19, :mse)

## Exctracción de vector de exclusión  y MSE
a = collect(sort_00C19[1,:params])
sort_00C19[1,:mse]

"""
Resultados de Evaluación de los vectores de exclusión 10 a 20 

MATLAB InflationTotalRebaseCPI(36, 2)
Vector de Exclusión -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193, 161] (14 Exclusiones)
MSE = 0.777

JULIA, con 10K simulaciones y InflationTotalRebaseCPI(60)
Vector de Exclusión ->  [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193] (13 Exclusiones)
MSE = 0.85806346f0

JULIA, con 125K simulaciones y InflationTotalRebaseCPI(60)
Vector de Exclusión ->  [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193] (13 Exclusiones)
MSE = 0.85986376f0

"""

#################  Optimización Base 2010  ###################################

# Vector óptimo base 2000 encontrado en la primera sección
exc00 =  [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193]

## Creación de vector de de gastos básicos ordenados por volatilidad, con información a Diciembre de 2019
gtdata_10 = gtdata[Date(2019,12)]
est_10 = std(gtdata_10[2].v |> capitalize |> varinteran, dims=1)

df = DataFrame(num = collect(1:279), Desv = vec(est_10))

sorted_std = sort(df, "Desv", rev=true)

vec_v = sorted_std[!,:num]

# Creación de vectores de exclusión
# Se crearán 100 vectores para la exploración inicial
v_exc = []
tot = []
total = []
for i in 1:length(vec_v)
   exc = vec_v[1:i]
   v_exc =  append!(v_exc, [exc])
   tot = (exc00, v_exc[i])
   total = append!(total, [tot])
end
total

# Diccionarios para exploración inicial (primero 100 vectores de exclusión)
FxEx_10 = Dict(
    :inflfn => InflationFixedExclusionCPI.(total[1:100]), 
    :resamplefn => resamplefn, 
    :trendfn => trendfn,
    :paramfn => paramfn,
    :nsim => 10_000,
    :traindate => ff10) |> dict_list

savepath = datadir("results","Fx-Exc","Esc-C","C19","B1010K")  

## Lote de simulación con los primeros 100 vectores de exclusión

run_batch(gtdata, FxEx_10, savepath)

## Recolección de resultados
Exc_1019 = collect_results(savepath)

## Análisis de exploración preliminar
# obtener longitud del vector de exclusión de cada simulación
exclusiones =  getindex.(map(x -> length.(x), Exc_1019[!,:params]),1)
Exc_1019[!,:exclusiones] = exclusiones 

# Ordenamiento por cantidad de exclusiones
Exc_1019 = sort(Exc_1019, :exclusiones)

# DF ordenado por MSE
sort_1019 = sort(Exc_1019, :mse)

## Exctracción de vector de exclusión  y MSE
a = collect(sort_1019[1,:params])
sort_1019[1,:mse]

"""
Resultados de Evaluación de exploración con 10_000 simulaciones para los 100 primeros vectores de exlcusión

MATLAB InflationTotalRebaseCPI(36, 2)
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193, 161] (14 Exclusiones)
Base 2010 -> [29, 31, 116, 39, 46, 40, 30, 35, 186, 47, 197, 41, 22, 48, 185, 34, 184] (17 exclusiones)
MSE = 0.64

JULIA, con 10K simulaciones y InflationTotalRebaseCPI(60)
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193] (13 Exclusiones)
Base 2010 -> [29, 31, 116, 39, 46, 40, 30] (7 exclusiones)
MSE = 0.8072317f0

"""

# Evaluación con 125_000 simulaciones al rededor del vector encontrado en la exploración inicial  (del 10 al 20)
FxEx_10 = Dict(
    :inflfn => InflationFixedExclusionCPI.(total[1:15]), 
    :resamplefn => resamplefn, 
    :trendfn => trendfn,
    :paramfn => paramfn,
    :nsim => 125_000,
    :traindate => ff10) |> dict_list

    savepath = datadir("results","Fx-Exc","Esc-C","C19","10125K")  

## Lote de simulación con los primeros 100 vectores de exclusión

run_batch(gtdata, FxEx_10, savepath)

## Recolección de resultados
Exc_1019 = collect_results(savepath)

## Análisis de exploración preliminar
# obtener longitud del vector de exclusión de cada simulación
exclusiones =  getindex.(map(x -> length.(x), Exc_1019[!,:params]),1)
Exc_1019[!,:exclusiones] = exclusiones 

# Ordenamiento por cantidad de exclusiones
Exc_1019 = sort(Exc_1019, :exclusiones)

# DF ordenado por MSE
sort_1019 = sort(Exc_1019, :mse)

## Exctracción de vector de exclusión  y MSE
a = collect(sort_1019[1,:params])
sort_1019[1,:mse]

"""
Resultados de Evaluación de exploración con 10_000 simulaciones para los 100 primeros vectores de exlcusión

MATLAB InflationTotalRebaseCPI(36, 2)
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193, 161] (14 Exclusiones)
Base 2010 -> [29, 31, 116, 39, 46, 40, 30, 35, 186, 47, 197, 41, 22, 48, 185, 34, 184] (17 exclusiones)
MSE = 0.64

JULIA, con 10K simulaciones y InflationTotalRebaseCPI(60)
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193] (13 Exclusiones)
Base 2010 -> [29, 31, 116, 39, 46, 40, 30] (7 exclusiones)
MSE = 0.8072317f0

JULIA, con 125K simulaciones y InflationTotalRebaseCPI(60)
Base 2000 -> [35, 30, 190, 36, 37, 40, 31, 104, 162, 32, 33, 159, 193] (13 Exclusiones)
Base 2010 -> [29, 31, 116, 39, 46, 40, 30] (7 exclusiones)
MSE = 0.8068863f0

"""