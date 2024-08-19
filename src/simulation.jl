"""
$(TYPEDSIGNATURES)

Get the SimTree parameters in a `Dictionary{String, Vector{String}}`
SimTree must be installed.
Give the root simtree directory
"""
function getsimtreeparams(simtreedirectory::String=".")::Dict{String,Vector{String}}
    cmd = Cmd(`SimTree list`; dir=simtreedirectory)
    iobf = IOBuffer()
    @suppress begin
        run(pipeline(cmd, stdout=iobf))
    end
    seekstart(iobf)

    parvaldict = Dict{String, Vector{String}}()

    par_val_rgx = r"\[([^\] ]*) ([^\]]*)\]"

    for l in eachline(iobf)
        for m in eachmatch(par_val_rgx, l)
            if haskey(parvaldict, m.captures[1])
                vals = parvaldict[m.captures[1]]
                m.captures[2] ∈ vals && continue
                push!(vals, m.captures[2])
            else
                parvaldict[m.captures[1]] = String[m.captures[2]]
            end
        end
    end
    return parvaldict
end

"""
$(TYPEDSIGNATURES)

Wraps the function you want to run through SimTree simulate
"""
function stsimulate(simulatefunction;savefile=true)


    if haskey(ENV, "SIMTREE_RESULTS_PATH")
        SIMTREE_RESULTS_PATH = ENV["SIMTREE_RESULTS_PATH"]
    else
        @warn "Now resultspath set using $(pwd())/results"
        SIMTREE_RESULTS_PATH = "$(pwd())/results"
    end
    starguments=TOML.parsefile("$SIMTREE_RESULTS_PATH/simtree_arguments.toml")
    print(starguments)
    if haskey(starguments, "s")
        str_seed = starguments["s"]
        println("Seed is:$(str_seed):")

        SEED = parse(Int, str_seed)
    else
        @warn "Seed not set from ST using 0"
        SEED = 0
    end
    # INFO: This file has the definition from PARAMSDICT
    include("$SIMTREE_RESULTS_PATH/$(starguments["p"])")
    if haskey(starguments, "DATA_PATH")
        datapath = starguments["DATA_PATH"]
    else
        @warn "Datapath not set using pwd/data"
        datapath = "$(pwd())/data"
    end
    results = simulatefunction(PARAMSDICT, SEED,datapath)
    @show results
    if savefile
    BSON.bson("$SIMTREE_RESULTS_PATH/study.bson", results)
    end
    return results


end
