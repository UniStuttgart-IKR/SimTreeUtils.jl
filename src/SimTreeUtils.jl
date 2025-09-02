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
using Serialization

using Plots

export copyresults, findrelpaths, getparameters, simsnum, getsims, getsimspath, SimTreeSession, TestSession, CloseSession, SaveBSON, logValues, saveDB

import DuckDB: create_logical_type  # wichtig: import, nicht using

"Mappt Vector{UInt8} & Co. auf BLOB"
create_logical_type(::Type{<:AbstractVector{UInt8}}) = DuckDB.LogicalType(DuckDB.DUCKDB_TYPE_BLOB)


const primitive_types = Set([Int, Int32, Int64, UInt8, Float32, Float64, Bool, Char,])
const primitive_numeric = Set([Int, Int32, Int64, UInt8])
const primitive_float = Set([Float32, Float64])
const primitive_string = Set([String])

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
