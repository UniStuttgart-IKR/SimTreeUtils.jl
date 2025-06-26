module SimTreeUtils

using Parameters
using Printf
using DocStringExtensions
using Suppressor
using DimensionalData
using BSON
using TOML

using DuckDB
using SQLite
using DataFrames
using LokiLogger
using Logging
using LoggingExtras
using JSON3
using OrderedCollections

using Plots

export copyresults, findrelpaths, getparameters, simsnum, getsims, getsimspath, SimTreeSession, logValues, saveDuckDB

include("dynamiclogger.jl")     #Extends TeeLogger
include("simTreeSession.jl")    #Holds Session Variables
include("simpleLogging.jl")     #Simple Logging functions

include("simulation.jl")
include("loaddata.jl")
include("metaanalysis.jl")

include("dbhandling_duckdb.jl")
include("dbhandling_sqlite.jl")
include("loghandling_loki.jl")
include("MakroWrapper.jl")
include("basicplot.jl")
include("saveresults.jl")

end
