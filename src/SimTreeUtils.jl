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

export TestSession, TestSaveBSON, CloseSession

include("dynamiclogger.jl")         #Extends TeeLogger
include("simTreeSession.jl")        #Holds Session Variables
include("simpleLogging.jl")         #Simple Logging functions

include("simulation.jl")
include("loaddata.jl")
include("metaanalysis.jl")

include("dbhandling_duckdb.jl")     #Storage-Handling DuckDB
include("dbhandling_sqlite.jl")     #Storage-Handling SQLite
include("loghandling_loki.jl")      #Logging Functionality Loki
include("MakroWrapper.jl")          #Macros for easy use

include("basicplot.jl")             #Test Retrieve Data from DB and Plot XY
include("saveresults.jl")           #Test Save results

end
