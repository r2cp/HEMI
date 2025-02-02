# # Script de Evaluación de inflación media ponderada y promedios móviles 

# Escenario C:  cambio de la trayectoria de inflación paramétrica por una con cambio de base sintético 
#cada cinco años, respecto a la configuración del escenario A.
# utilizando la información hasta diciembre de 2019 y diciembre 2020
#   - Período de Evaluación: Diciembre 2001 - Diciembre 2019 y Diciembre 2020, ff19 = Date(2019, 12),ff20 = Date(2020, 12).
#   - Trayectoria de inflación paramétrica con cambio de base sintético: cada 5 años, [InflationTotalRebaseCPI(60)] (legacy).
#   - Método de remuestreo de extracciones estocásticas independientes (Remuestreo por meses de ocurrencia), [ResampleScrambleVarMonths()].
#   - Muestra completa para evaluación, [SimConfig].
Esc = "EscC"
medida = "WeightedMean"
using DrWatson
@quickactivate "HEMI"

# Cargar el módulo de Distributed para computación paralela
using Distributed
# Agregar procesos trabajadores
nprocs() < 5 && addprocs(4, exeflags="--project")

# Cargar los paquetes utilizados en todos los procesos
@everywhere using HEMI


# 1. Definir los parámetros de evaluación. 
resamplefn = ResampleScrambleVarMonths()
trendfn = TrendRandomWalk()
paramfn = InflationTotalRebaseCPI(60)
ff19= Date(2019,12)

# la función de inflación, la instanciamos dentro del diccionario.
dict_wm = Dict(
    :inflfn => InflationWeightedMean(), 
    :resamplefn => resamplefn,
    :trendfn => trendfn,
    :paramfn => paramfn,
    :traindate => ff19,
    :nsim => 125000) |> dict_list
    


# 2. Definimos las carpetas para almacenar los resultados 
savepath = datadir("results",medida,Esc,"C19")

# 3. Usamos run_batch, para gnenerar la evluación de la media simple
run_batch(gtdata, dict_wm, savepath,savetrajectories=true)

# ## Medias Móviles

avrange = 2:12
wmfs = [InflationMovingAverage(InflationWeightedMean(),i) for i in avrange]

dict_ma = Dict(
    :inflfn => wmfs, 
    :resamplefn => resamplefn,
    :trendfn => trendfn,
    :paramfn => paramfn,
    :traindate => ff19,
    :nsim => 125000) |> dict_list

# Usamos run_batch, para gnenerar la evluación de las medias móviles de 2 a 12 períodos de la media ponderada interanual
run_batch(gtdata, dict_ma, savepath,savetrajectories=true)

# Revisión de resultados, usando collect_results
using DataFrames
using Chain
using PrettyTables
df_wm = collect_results(savepath)

# Tabla de resultados principales del escenario 
df_results = @chain df_wm begin 
    select(:measure, :mse, :mse_std_error)
    #sort(:mse)
    #filter(:measure => s -> !occursin("FP",s), _)
end
# select(df_results, :measure => ByRow(s -> match(r"(?:\w), (?:\d{1,2})", s).match |> split))
#vscodedisplay(df_results)
pretty_table(df_results, tf=tf_markdown, formatters=ft_round(4))

sens_metrics = @chain df_wm begin 
    select(:measure, :mse, :rmse, :me, :mae, :huber, :corr)
    #sort(:mse)
end 
# select(:measure, :mse, r"^mse_[bvc]",)
# select(:measure, :mse, :mse_std_error, r"^mse_[bvc]", :rmse, :me, :mae, :huber, :corr)
#vscodedisplay(sens_metrics)
pretty_table(sens_metrics, tf=tf_markdown, formatters=ft_round(4))

## Gráficas de resultados 
using Plots

plotspath = joinpath("docs", "src", "eval", Esc, "images", medida)

p = plot(InflationTotalCPI(), gtdata, fmt = :svg)
plot!(InflationWeightedMean(), gtdata, fmt = :svg)
plot!(InflationMovingAverage(InflationWeightedMean(),10), gtdata, fmt = :svg)

savefig(joinpath(plotspath, "obs_trajectory"))


