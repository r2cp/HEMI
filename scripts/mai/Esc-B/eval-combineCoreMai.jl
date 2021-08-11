# # Combinación lineal de estimadores muestrales de inflación MAI
using DrWatson
@quickactivate "HEMI"

using HEMI 
using DataFrames, Chain
using Optim
using Plots

# Funciones de ayuda 
includet(scriptsdir("mai", "mai-optimization.jl"))

# Obtenemos el directorio de trayectorias resultados 
savepath = datadir("results", "CoreMai", "Esc-A")
tray_dir = datadir(savepath, "tray_infl")
plotspath = mkpath(plotsdir("CoreMai"))

# CountryStructure con datos hasta diciembre de 2019
gtdata_eval = gtdata[Date(2019, 12)]


## Obtener las trayectorias de simulación de inflación MAI de variantes F y G
df_mai = collect_results(savepath)

# Obtener variantes de MAI a combinar. Como se trata de los resultados de 2019,
# se combinan todas las versiones F y G
combine_df = @chain df_mai begin 
    filter(:measure => s -> !occursin("FP",s), _)
    select(:measure, :mse, :inflfn, :path => ByRow(p -> joinpath(tray_dir, basename(p))) => :tray_path)
    sort(:mse)
end

# Obtener las trayectorias de los archivos guardados en el directorio tray_infl 
tray_list_mai = map(combine_df.tray_path) do path
    tray_infl = load(path, "tray_infl")
end

# Obtener el arreglo de 3 dimensiones de trayectorias (T, 10, K)
tray_infl_mai = reduce(hcat, tray_list_mai)


## Obtener trayectoria paramétrica de inflación 

resamplefn = df_mai[1, :resamplefn]
trendfn = df_mai[1, :trendfn]
paramfn = df_mai[1, :paramfn]
param = InflationParameter(paramfn, resamplefn, trendfn)
tray_infl_pob = param(gtdata_eval)


## Algoritmo de combinación para ponderadores óptimos

# Obtener los ponderadores de combinación óptimos para el cubo de trayectorias
# de inflación MAI 
a_optim = combination_weights(tray_infl_mai, tray_infl_pob)

## Optimización iterativa con Optim 

n = size(tray_infl_mai, 2)
msefnwdata!(F, G, a) = msefn!(F, G, a, tray_infl_mai, tray_infl_pob)
optres = Optim.optimize(
    Optim.only_fg!(msefnwdata!), # Función objetivo = MSE
    rand(Float32, n), # Punto inicial de búsqueda 
    Optim.LBFGS(), # Algoritmo 
    Optim.Options(show_trace = true)) 

a_optim_iter = Optim.minimizer(optres)

println(optres)
println(a_optim_iter)
@info "Resultados de optimización:" min_mse=minimum(optres) iterations=Optim.iterations(optres)


## Conformar un DataFrame de ponderadores y guardarlos en un directorio 

dfweights = DataFrame(
    measure = combine_df.measure, 
    analytic_weight = a_optim, 
    iter_weight = a_optim_iter
)

weightsfile = datadir(savepath, "mse-weights", "mai-mse-weights.jld2")
wsave(weightsfile, "mai_mse_weights", a_optim)

## Evaluación de combinación lineal óptima 

# a_optim = ones(Float32, n) / n
# a_optim = a_optim_iter
tray_infl_maiopt = sum(tray_infl_mai .* a_optim', dims=2)

# Estadísticos 
metrics = eval_metrics(tray_infl_maiopt, tray_infl_pob)
@info "Métricas de evaluación:" metrics...

## Generación de gráfica de trayectoria histórica 

tray_infl_mai_obs = mapreduce(inflfn -> inflfn(gtdata), hcat, combine_df.inflfn)
tray_infl_maiopt = tray_infl_mai_obs * a_optim

plot(InflationTotalCPI(), gtdata)
plot!(infl_dates(gtdata), tray_infl_maiopt, 
    label="Combinación lineal óptima MSE MAI", 
    legend=:topright)

savefig(plotsdir(plotspath, "MAI-optima-MSE.svg"))