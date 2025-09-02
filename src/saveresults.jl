#############################
#   Initialize Session
#############################
function SaveBSON(session::SimTreeUtils.SimTreeSession, results; createFullTable::Bool=false, insertParamsDict::Bool=true)
    if createFullTable
        #Insert Complete Dataset as one large Table
        InsertData(session, results, "fullresults", "results", "results", OrderedDict{String, Any}(), insertParamsDict)
    else
        #Split data into smaller Tables
        PrepareTable_Results(session, results, "bson_results", "", "", OrderedDict{String, Any}(), insertParamsDict)
    end
end

#############################
#   Results - Split results by Dict-Values
#############################
function PrepareTable_Results(session::SimTreeUtils.SimTreeSession, data, schemaName::String, tableName::String, columnName::String, resultsPath::OrderedDict{String, Any}, insertParamsDict::Bool=true)
    if columnName == "PARAMSDICT"
        return
    end

    if data isa NamedTuple || data isa Dict
        for (k, v) in pairs(data)
            index = length(resultsPath) + 1
            newdict = copy(resultsPath)
            newdict["r[$(index)]"] = k

            PrepareTable_Results(session, v, schemaName, isempty(tableName) ? string(k) : "$(tableName)_$(k)", string(k), newdict, insertParamsDict)
        end
    else
        InsertData(session, data, schemaName, tableName, columnName, resultsPath, insertParamsDict) # Übergeben: resultsPath
    end
end

#############################
#   Insert Data into DuckDB
#############################
function InsertData(session::SimTreeUtils.SimTreeSession, data, schemaName::String, tableName::String, columnName::String, resultsPath::OrderedDict{String, Any}, insertParamsDict::Bool=true)
    df = formatData(data, columnName)

    if size(df) == (0, 0) 
        println("[$(schemaName).$(tableName)] Skip empty DataFrame")
        return
    end

    insertcols!(df, 1, (k => fill(v, nrow(df)) for (k, v) in resultsPath)...)

    SimTreeUtils.InsertDuckDBDataFrame(session, tableName, df; schema=schemaName, insertParamsDict=insertParamsDict)
end

#############################
#   Format JSON Routine
#############################
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

#############################
#   Normalize Data (From Dict/Array to Row-Based Datastructure)
#############################
function normalize(
        data::Any,
        name::String;
        row::Dict{String, Any} = Dict{String, Any}(),
        rows::Vector{Dict{String, Any}} = Dict{String, Any}[]
    )::Vector{Dict{String, Any}}
    
    if data isa NamedTuple || data isa Dict
        for (k, v) in pairs(data)
            newname = "$(name)[d]"
            
            new_row = copy(row)
            new_row[newname] = string(k)

            if string(k) == "PARAMSDICT"
                continue
            end

            normalize(v, newname; row = new_row, rows = rows)
        end
    elseif data isa Tuple || data isa AbstractArray
        for (i, v) in enumerate(data)
            newname = "$(name)[i]"

            new_row = copy(row)
            new_row[newname] = i
            normalize(v, newname;  row = new_row, rows = rows)
        end
    elseif typeof(data) in primitive_numeric
        new_row = copy(row)
        new_row["$(name)_int"] = data

        push!(rows, new_row)
    elseif typeof(data) in primitive_float
        new_row = copy(row)
        new_row["$(name)_float"] = data

        push!(rows, new_row)
    elseif typeof(data) in primitive_string
        new_row = copy(row)
        new_row["$(name)_text"] = data

        push!(rows, new_row)
    elseif typeof(data) in primitive_types
        new_row = copy(row)
        new_row["$(name)_value"] = data

        push!(rows, new_row)
    else
        #In Rücksprache: Ignore BLOBs
        #ToDO: BLOBs > DF > DuckDB wirft error; Insert muss via Row-Insert passieren
        #return rows
        new_row = copy(row)
        #blob = to_blob(data)
        #revert = from_blob(blob)
        #new_row["$(name)_BLOB"] = false
        new_row["$(name)_BLOB"] = to_blob(data)
        push!(rows, new_row)
    end

    return rows

end

function to_blob(data)::String
    io = IOBuffer()
    serialize(io, data)
    bytes = take!(io)           # Vector{UInt8}
    return base64encode(bytes)  # String
end
function from_blob(data::String)
    bytes = base64decode(data)
    return deserialize(IOBuffer(bytes))
end
