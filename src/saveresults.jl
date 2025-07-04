function SaveBSON(session::SimTreeUtils.SimTreeSession, results)
    println(typeof(results))
    #Vorgehen:
    #   Durchloopen aller initialer Strings
    #   Daraus Tabellen-Name
    #       Dann Daten mit formatData
    PrepareTable(session, results)
end

function PrepareTable(session::SimTreeUtils.SimTreeSession, data; prefix="", name::String="")
    if data isa NamedTuple || data isa Dict
        for (k, v) in pairs(data)
            PrepareTable(session, v; prefix = isempty(prefix) ? string(k) : "$(prefix)_$(k)", name = k)
        end
    else
        println(prefix)
        df = formatData(data, name)
        if size(df) == (0, 0) 
            println("DataFrame ist komplett leer (0x0)")
        else
            SimTreeUtils.InsertDuckDBDataFrame(session, "results.$(prefix)", df)
        end
    end
end

function formatData(data, name::String)::DataFrame
    #println("01 - Normalize Data")
    rows = normalize(data, name;)
    
    #println("02 - Get all Keys")
    all_keys = Set{String}()
    for row in rows
        union!(all_keys, keys(row))
    end
    ordered_keys = sort(collect(all_keys))

    #println("03 - Fill EMpty Cells")
    filled = [
        Dict(k => get(row, k, missing) for k in ordered_keys)
        for row in rows
    ]
    
    #println("04 - Sort NAmed KEys")
    named = [
        NamedTuple{Tuple(Symbol.(ordered_keys))}(
            [row[k] for k in ordered_keys]
        ) for row in filled
    ]
    
    #println("05 - Export DataFrame")
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
            new_row["$(total)_level_$level"] = string(k)
            normalize(v, string(k); total = total + 1, level = level + 1, row = new_row, rows = rows)
        end
    elseif data isa Tuple || data isa AbstractArray
        for (i, v) in enumerate(data)
            #normalize(v; prefix = [prefix..., string(i)], out = out, sep = sep, level = level)
            new_row = copy(row)
            new_row["$(total)_$(name)_index"] = i
            normalize(v, name; total = total + 1, level = level, row = new_row, rows = rows)
        end
    elseif typeof(data) in primitive_types
        
        new_row = copy(row)
        new_row["$(total)_$(name)_value"] = data

        # println(row)
        # println(new_row)
        # readline()
        push!(rows, new_row)


        #key = join(prefix, ".")
        #row = (key = key, value = data)
        #print(row)

        #out[key] = data
        #push!(out, row)
    else
        #ToDo: Add as BLOB
        #println(typeof(data))
    end

    return rows

end

function flatten(data; prefix=[], name=nothing, rows=[])
    if data isa NamedTuple
        for (k, v) in pairs(data)
            flatten(v; prefix = isempty(prefix) ? string(k) : "$prefix.$k", name = k, rows)
        end
    elseif data isa Dict
        for (k, v) in pairs(data)
            flatten(v; prefix = "$prefix['$k']", name = k, rows)
        end
    elseif data isa Tuple || data isa AbstractArray
        for (i, v) in enumerate(data)
            flatten(v; prefix = "$prefix[$i]", name = i, rows)
        end
    else
        push!(rows, (prefix = prefix, name = name, value = data))
    end
    return rows
end

function extractData(data; prefix=[], rows=[])
    if data isa NamedTuple
        for (k, v) in pairs(data)
            extractData(v; prefix = isempty(prefix) ? string(k) : "$prefix.$k", rows)
        end
    elseif data isa Dict
        for (k, v) in pairs(data)
            extractData(v; prefix = "$prefix['$k']", rows)
        end
    elseif data isa Tuple || data isa AbstractArray
        for (i, v) in enumerate(data)
            extractData(v; prefix = "$prefix[$i]", rows)
        end
    else
        push!(rows, (key = prefix, value = data))
    end
    return rows
end
