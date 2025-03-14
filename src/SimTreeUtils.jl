module SimTreeUtils

using Parameters
using Printf
using DocStringExtensions
using Suppressor
using DimensionalData
using BSON
using TOML

export copyresults, findrelpaths, getparameters, simsnum, getsims, getsimspath

include("simulation.jl")
include("loaddata.jl")
include("metaanalysis.jl")

end
