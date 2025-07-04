function SaveBSON(session::SimTreeUtils.SimTreeSession, results)
    println(typeof(results))
    #Vorgehen:
    #   Durchloopen aller initialer Strings
    #   Daraus Tabellen-Name
    #       Dann Daten mit formatData
    PrepareTable(session, results)
end

function PrepareTable(session::SimTreeUtils.SimTreeSession, data; prefix="", name::String="")
    if name == "PARAMSDICT"
        return
    end

    if data isa NamedTuple || data isa Dict
        for (k, v) in pairs(data)
            PrepareTable(session, v; prefix = isempty(prefix) ? string(k) : "$(prefix)_$(k)", name = k)
        end
    else
        println(prefix)
        df = formatData(data, name)        
        if size(df) == (0, 0) 
            println("   Skip empty DataFrame")
            return
        end

        SimTreeUtils.InsertDuckDBDataFrame(session, prefix, df; schema="results")
    end
end

function formatData(data, name::String)::DataFrame
    rows = normalize(data, name;)
    
    all_keys = Set{String}()
    for row in rows
        union!(all_keys, keys(row))
    end
    ordered_keys = sort(collect(all_keys))

    filled = [
        Dict(k => get(row, k, missing) for k in ordered_keys)
        for row in rows
    ]
    
    named = [
        NamedTuple{Tuple(Symbol.(ordered_keys))}(
            [row[k] for k in ordered_keys]
        ) for row in filled
    ]
    
    df = DataFrame(named)
    return df
end

function normalize(
        data::Any,
        name::String;
        total::Int = 1,
        level::Int = 1,
        row::Dict{String, Any} = Dict{String, Any}(),
        rows::Vector{Dict{String, Any}} = Dict{String, Any}[]
    )::Vector{Dict{String, Any}}
    
    if data isa NamedTuple || data isa Dict
        for (k, v) in pairs(data)
            #normalize(v; prefix = [prefix... , string(k)], out = out, sep = sep, level = level+1)
            new_row = copy(row)
            new_row["$(total)_$(k)"] = string(k)
            normalize(v, string(k); total = total + 1, level = level + 1, row = new_row, rows = rows)
        end
    elseif data isa Tuple || data isa AbstractArray
        for (i, v) in enumerate(data)
            #normalize(v; prefix = [prefix..., string(i)], out = out, sep = sep, level = level)
            new_row = copy(row)
            new_row["$(total)_$(name)_index"] = i
            normalize(v, name; total = total, level = level, row = new_row, rows = rows)
        end
    elseif typeof(data) in primitive_types
        
        new_row = copy(row)
        new_row["$(total)_$(name)_value"] = data

        push!(rows, new_row)
    else
        #ToDo: Add as BLOB
        #println(typeof(data))
    end

    return rows

end
