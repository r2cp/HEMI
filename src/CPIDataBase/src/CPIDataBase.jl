"""
    CPIDataBase

Librería base para tipos y funcionalidad básica para manejo de datos del IPC a
nivel desagregado de gastos básicos
"""
module CPIDataBase

    using Dates
    using DataFrames

    # Export types
    export IndexCPIBase, VarCPIBase, FullCPIBase
    export CountryStructure, UniformCountryStructure, MixedCountryStructure

    # Export functions
    export capitalize, varinterm, varinteran, 
        capitalize!, varinterm!, varinteran!, 
        periods, infl_periods, infl_dates,
        getunionalltype

    # Export types for implement new inflation functions
    export InflationFunction, EnsembleInflationFunction
    export EnsembleFunction, CombinationFunction
    export num_measures, weights, measure_name, measure_tag

    # Export types needed to specify type of results
    export CPIIndex, CPIVarInterm

    # Basic inflation function
    export InflationTotalCPI

    # Definición de tipos para bases del IPC
    include("cpibase.jl")
    include("countrystructure.jl")

    # Operaciones básicas
    include("utils/capitalize.jl")
    include("utils/varinterm.jl")
    include("utils/varinteran.jl")

    # Estructura básica para medidas de inflación 
    include("inflation/inflation.jl")
    include("inflation/ensemble.jl")

    # Funciones de utilidad
    export getdates
    include("utils/utils.jl")

    
    # Submódulo con funciones relacionadas con los tipos de este paquete para
    # realizar pruebas en paquetes que extiendan la funcionalidad. Este módulo
    # no se exporta por defecto, requiere carga explícita (e.g using
    # CPIDataBase.TestHelpers)
    module TestHelpers
        using Dates, ..CPIDataBase    
        
        export getrandomweights, getbasedates, 
            getzerobase, getzerocountryst

        include("test/test_helpers.jl")
    end

end # module
