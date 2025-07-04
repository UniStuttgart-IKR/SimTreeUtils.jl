function SaveBSON(session::SimTreeUtils.SimTreeSession, results)
    println(typeof(results))
    #Vorgehen:
    #   Durchloopen aller initialer Strings
    #   Daraus Tabellen-Name
    #       Dann Daten mit formatData
    test(session, results)
    
end

##Aus Lokaler Testumgebung

function test(session::SimTreeUtils.SimTreeSession, data)::DataFrame
    println(PrepareTable(data))
    #describe(df)
    #SimTreeUtils.InsertDuckDBDataFrame(session, "test_table", df)
end

function PrepareTable(data; prefix=[], name=nothing, rows=[])
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
            if i > max_array_iteration
                continue
            end
            flatten(v; prefix = "$prefix[$i]", name = i, rows)
        end
    elseif data isa String
        push!(rows, (prefix = prefix, name = name, value = data))
    end
    return rows
end

function formatData(data)::DataFrame
    println("01 - Normalize Data")
    rows = normalize(data)
    
    println("02 - Get all Keys")
    all_keys = Set{String}()
    for row in rows
        union!(all_keys, keys(row))
    end
    ordered_keys = sort(collect(all_keys))

    println("03 - Fill EMpty Cells")
    filled = [
        Dict(k => get(row, k, missing) for k in ordered_keys)
        for row in rows
    ]
    
    println("04 - Sort NAmed KEys")
    named = [
        NamedTuple{Tuple(Symbol.(ordered_keys))}(
            [row[k] for k in ordered_keys]
        ) for row in filled
    ]
    
    println("05 - Export DataFrame")
    return DataFrame(named)
end

function normalize(
        data::Any;
        total::Int = 1,
        level::Int = 1,
        row::Dict{String, Any} = Dict{String, Any}(),
        rows::Vector{Dict{String, Any}} = Dict{String, Any}[],
        previous::Union{String, Nothing} = nothing
    )::Vector{Dict{String, Any}}
    
    if data isa NamedTuple || data isa Dict
        for (k, v) in pairs(data)
            #normalize(v; prefix = [prefix... , string(k)], out = out, sep = sep, level = level+1)
            new_row = copy(row)
            new_row["$(total)_level_$level"] = string(k)
            normalize(v; total = total + 1, level = level + 1, row = new_row, rows = rows, previous = string(k))
        end
    elseif data isa Tuple || data isa AbstractArray
        for (i, v) in enumerate(data)
            if i > max_array_iteration
                continue
            end
            #normalize(v; prefix = [prefix..., string(i)], out = out, sep = sep, level = level)
            new_row = copy(row)
            if previous == nothing
                new_row["$(total)_level_$level"] = i
                normalize(v; total = total + 1, level = level + 1, row = new_row, rows = rows, previous = previous)
            else
                new_row["$(total)_$(previous)_index"] = i
                normalize(v; total = total + 1, level = level, row = new_row, rows = rows, previous = previous)
            end
        end
    elseif typeof(data) in primitive_types
        
        new_row = copy(row)
        if previous == nothing
            new_row["$(total)_$(level)_value"] = data
        else
            new_row["$(total)_$(previous)_value"] = data
        end
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
            if i > max_array_iteration
                continue
            end
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
            if i > max_array_iteration
                continue
            end
            extractData(v; prefix = "$prefix[$i]", rows)
        end
    else
        push!(rows, (key = prefix, value = data))
    end
    return rows
end
