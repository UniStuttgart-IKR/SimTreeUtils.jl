function copyresults(respath, filename, metapath = "MetaResults/")
    rm(metapath, force=true, recursive=true)
    relpths = Vector{String}()
    nofiles = true
    for (root, _, files) in walkdir(respath)
        if filename ∈ files
            nofiles = false
            relpth = relpath(root, respath)
            mkpath(metapath * relpth)
            cp(root*"/"*filename, metapath * relpth * "/"*filename)
            println("copying "*root)
            push!(relpths, relpth)
        end
    end
    if nofiles
        error("Given path contains no simulation results data")
    end
    return relpths
end

function findrelpaths(filename, respath = "MetaResults/")
    relpths = Vector{String}()
    for (root, _, files) in walkdir(respath)
        if filename ∈ files
            relpth = relpath(root, respath)
            push!(relpths, relpth)
        end
    end
    return relpths
end


"""
Return all parameters used in a SimTree simulation as a dictionary
"""
function getparameters(relpaths::Vector{String})
	pard = Dict{String, Any}()
	for path in relpaths
		for m in eachmatch(r"Para[S,F,I,B]__([a-z,A-Z,0-9,_]+)__([a-z,A-Z,0-9,._]+)", path)
			parsedInt = tryparse(Int, m[2])
			if parsedInt !== nothing
				haskey(pard, m[1]) || (pard[m[1]] = Set{Int}())
				push!(pard[m[1]], parsedInt) 
				continue
			end
			parsedFloat = tryparse(Float64, m[2])
			if parsedFloat !== nothing
				haskey(pard, m[1]) || (pard[m[1]] = Set{Float64}())
				push!(pard[m[1]], parsedFloat) 
				continue
			end
			haskey(pard, m[1]) || (pard[m[1]] = Set{String}())
			push!(pard[m[1]], m[2]) 
		end
	end
	return Dict(k => sort(collect(v)) for (k,v) in pard)
end

"""
$(TYPEDSIGNATURES)

Get the simtree parameters of the simulation in a Dict{String, Any}
Give absolute path of the simulation directory as a string.

# Example
```julia
julia> getsimusimtreeparams("ParaS__Topology__BA10_3/ParaS__PoissonProcess__A1_S3/ParaS__DemandValues__DV4_6_8/ParaI__PAR_K_CANDPATHS__1/ParaI__PAR_SPECTRUMSLOTLENGTH__20/ParaS__PAR_POMDP__DummyPOMDP/ParaF__PAR_DISCOUNT__0.8/ParaS__ExploreDecay__LDS_1_001_5000/ParaI__PAR_MAX_STEPS__3000/ParaF__PAR_LEARNING_RATE__0.005/ParaS__NNHiddenLayers__HL_128_128_128_128_128/Seed01")
```
"""
function getparameters(path::String; allstring=false)
	m = match(r"Results/(.*)", path)
	if !isnothing(m)
		relpath = string(first(m.captures))
	else
		return nothing
	end
	pard = Dict{String, Any}()
	for m in eachmatch(r"Para[S,F,I,B]__([a-z,A-Z,0-9,_]+)__([a-z,A-Z,0-9,._]+)", relpath)
		if !allstring
			parsedInt = tryparse(Int, m[2])
			if parsedInt !== nothing
				pard[m[1]] = parsedInt
				continue
			end
			parsedFloat = tryparse(Float64, m[2])
			if parsedFloat !== nothing
				pard[m[1]] = parsedFloat
				continue
			end
		end
		pard[m[1]] = string(m[2])
	end
	return pard
end


parseseeds(relpths::Vector{String}) = [parse(Int, match(r"Seed([0-9]+)", relpth).captures[1]) for relpth in relpths] |> unique! |> sort!

"""
Return index of simulation containing the parameters
"""
function simsnum(relsimpths::Vector{String}, pars::String...)
	length(pars) == 0 && return collect(1:length(relsimpths))
	simsn = Vector{Int}()
	for (i,relpth) in enumerate(relsimpths)
		ispicked = true
		for par in pars
			if occursin(r"[0-9]+\.[0-9]*$", par)
				reg = Regex("__$(par)0*/")
			else
				reg = Regex("__$(par)/")
			end
			ispicked = ispicked && occursin(reg, relpth)
			ispicked || break
		end
		ispicked && push!(simsn, i)
	end
	return simsn
end

"""
Return index of simulation containing the parameters for specific seed
"""
function simsnum(relsimpths::Vector{String}, seed::Int, parsx...)
	#pars = string.(parsx)
	pars = [ps for p in parsx for ps in [string(p)]]
	simsn = simsnum(relsimpths, pars...)
	reg = Regex("/Seed0?$(seed)")
	seededn = [i for i in simsn if occursin(reg, relsimpths[i])]
    return seededn
end

"""Return model of simulation indexes"""
function model(modelds::Vector, v::Vector{Int})
	mods = [modelds[i] for i in v]
	if length(mods) == 1
		return mods[1]
	elseif length(mods) == 0
		return missing
	else 
		return mods
	end
end
function model(lazmodelds::Function, relsimpths::Vector, v::Vector{Int})
	mods = [lazmodelds(relsimpths, i) for i in v]
		if length(mods) == 1
		return mods[1]
	elseif length(mods) == 0
		return missing
	else 
		return mods
	end
end

"""Return simulation path based on indexes"""
function modelpath(relsimpths::Vector, v::Vector{Int})
	paths = [relsimpths[i] for i in v]
	if length(paths) == 1
		return paths[1]
	elseif length(paths) == 0
		return missing
	else 
		return paths
	end
end

"""Return simulation model"""
getsims(models::Vector, paths::Vector{String},seed::Int,pars...) = model(models, simsnum(paths,seed,pars...))
getsims(models::Vector, paths::Vector{String},pars::String...) = model(models, simsnum(paths,pars...))

getsims(lazmodels::Function, paths::Vector{String},seed::Int,pars...) = model(lazmodels, simsnum(paths,seed,pars...))
getsims(lazmodels::Function, paths::Vector{String},pars::String...) = model(lazmodels, simsnum(paths,pars...))
"""Return simulation path"""
getsimspath(paths::Vector{String},seed::Int,pars...) = modelpath(paths, simsnum(paths,seed,pars...))
getsimspath(paths::Vector{String},pars::String...) = modelpath(paths, simsnum(paths,pars...))

