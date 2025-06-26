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
function stsimulate(simulatefunction::Function; savefile::Bool=true, app::String="Unnamed Study", useLokiLogger::Bool=true, useDuckDB::Bool=true, useSQLite::Bool=true)
    #Initialize Variables
    SEED = -1
    datapath = ""
    SIMTREE_RESULTS_PATH = ""
    results = nothing

    #Initialize Session
    session = SimTreeUtils.InitializeSession(app)

    #Initialize Environment
    Logging.with_logger(session.logger) do
        @debug "Init-Logger initialized!"

        if haskey(ENV, "SIMTREE_RESULTS_PATH")
            SIMTREE_RESULTS_PATH = ENV["SIMTREE_RESULTS_PATH"]
        else
            @warn "Now resultspath set using $(pwd())/results"
            SIMTREE_RESULTS_PATH = "$(pwd())/results"
        end
        @info "SIMTREE_RESULTS_PATH: " * SIMTREE_RESULTS_PATH

        starguments=TOML.parsefile("$SIMTREE_RESULTS_PATH/simtree_arguments.toml")
        if starguments === nothing
            @warn "starguments empty"
        else
            @info "starguments: " * string(starguments)
        end

        if haskey(starguments, "s")
            str_seed = starguments["s"]
            @info "Seed is: " * str_seed

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
        @info "datapath: " * datapath

        PARAMSDICT["stresultspath"]=SIMTREE_RESULTS_PATH
        @show PARAMSDICT
        @debug "Init-Logger closed"
        
        #Prepare Session for Production
        SimTreeUtils.PrepareSession(session, SIMTREE_RESULTS_PATH, PARAMSDICT, SEED, datapath)

        @debug "Prod-Logger initialized!"
        results = simulatefunction(session, PARAMSDICT, SEED, datapath)
        SimTreeUtils.ViewDBSchema(session)

        SimTreeUtils.CloseSession(session)

        @debug "Save Data"
        # @show results
        if savefile
            BSON.bson("$SIMTREE_RESULTS_PATH/study.bson", results)
        end
        @debug "Prod-Logger closed"
    end

    #Return Data
    return results
end
