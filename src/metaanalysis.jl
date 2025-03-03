"""
$(TYPEDSIGNATURES)

Automatically select out single value dimensions
"""
function atfirstvalue(da::DimArray)
    ds = [d for d in dims(da) if length(d) == 1]
    if length(ds) > 0
	return da[[Dim{name(d)}(At(first(d))) for d in ds]...]
    else
	return da
    end
end

"""
$(TYPEDSIGNATURES)

Select out first value for all `names`
"""
function atfirstvalue(da::DimArray, names::Vector{Symbol})
    ismissing(da) && return missing
    fnames = filter(nm -> nm in name.(dims(da)), names)
    firstvals = [first(dims(da, nm)) for nm in fnames]
    return da[[Dim{nm}(At(fv)) for (nm, fv) in zip(fnames, firstvals)]...]
end

"""
$(TYPEDSIGNATURES)

Delete single entries in dictionary
"""
function deletesinglevalueentries!(dict::Dict)
    singlevaluekeys = [k for (k, v) in dict if length(v) == 1]
    foreach(x -> delete!(dict, x), singlevaluekeys)
    return dict
end

"""
$(TYPEDSIGNATURES)

get all individual name-value pairs
"""
function getallsingledims(da::DimArray; ignoredims::Vector{Symbol}=Symbol[])
    singldims = [(typeof(d).parameters[1], v) for d in dims(da) for v in d]
    return filter!(x -> x[1] ∉ ignoredims, singldims)
end

"""
$(TYPEDSIGNATURES)
"""
function getvalue(da::DimArray, nt::NamedTuple)
    all(p -> hasdimval(da, p), pairs(nt)) || return missing
    return da[[Dim{Symbol(key)}(At(keyval)) for (key, keyval) in pairs(nt)]...]
end

"""
$(TYPEDSIGNATURES)

get all first values from dict given as names
"""
function atfirstvalue(parametersdict::Dict{Symbol}, names::Vector{Symbol})
    fnames = filter(nm -> nm in keys(parametersdict), names)
    return [Dim{nm}(At(first(parametersdict[nm]))) for nm in fnames]
end

"""
$(TYPEDSIGNATURES)
"""
function atfirstvalue(parametersnamedtuple, names::Vector{Symbol})
    fnames = filter(nm -> nm in keys(parametersnamedtuple), names)
    return [Dim{nm}(At(first(getfield(parametersnamedtuple, nm)))) for nm in fnames]
end

"""
$(TYPEDSIGNATURES)
"""
function dictstring2symbol(d::Dict{String})
    Dict(Symbol(k) => v for (k,v) in d)
end

"""
$(TYPEDSIGNATURES)

Construct string name of the parameter dictionary
"""
function getpdvalues(pd::AbstractDict)
    [[string(k) * "__" * string(vel) for vel in v] for (k, v) in pd]
end

function hasdimval(da::DimArray, p)
    return p[1] in name.(dims(da)) && p[2] ∈ dims(da, p[1])
end

