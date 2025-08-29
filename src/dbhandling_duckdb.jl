#############################
#   Open & Close DB
#############################
function OpenDuckDB(session::SimTreeUtils.SimTreeSession, dbfile::String; dropDataBase::Bool=false, createParamsDictTable::Bool=false)
    if session.useDuckDB == false
        return
    end

    session.duckDBfile = dbfile
    if session.duckDBfile == ":memory:"
        @error "Not implemented!"
        return
    end

    SimTreeUtils.simpleLog(session, "[DuckDB] Creating Database '$(session.duckDBfile))' Drop: $dropDataBase"; level=Logging.Debug)

    if dropDataBase==true && isfile(session.duckDBfile)
        SimTreeUtils.simpleLog(session, "[DuckDB] Drop Previos Database '$(session.duckDBfile))'"; level=Logging.Debug)
        rm(session.duckDBfile)
    end

    session.duckDBcon = DBInterface.connect(DuckDB.DB, session.duckDBfile)
    
    SimTreeUtils.simpleLog(session, "[DuckDB] Connection established; '$(session.duckDBfile))' Drop: $dropDataBase"; level=Logging.Debug)

    if createParamsDictTable
        CreateParamsDictTable(session)
    end
end
function CreateParamsDictTable(session::SimTreeUtils.SimTreeSession)
    columnsDict = OrderedDict{String, Type}((("$(k)" => typeof(v)) for (k, v) in session.PARAMSDICT)...)
    dataDict = OrderedDict{String, Any}((("$(k)" => isa(v, String) ? "'$v'" : v) for (k, v) in session.PARAMSDICT)...)
    AppendDuckDBData(session, "PARAMSDICT", columnsDict, dataDict; defaultColumns=false)
end
function CloseDuckDB(session::SimTreeUtils.SimTreeSession)
    if session.useDuckDB == false
        return
    end

    if session.duckDBcon === nothing
        return
    end

    if session.duckDBfile == ":memory:"
        @error "Not implemented!"
        return
    end
    
    SimTreeUtils.simpleLog(session, "[DuckDB] Closing Connection '$(session.duckDBfile)'"; level=Logging.Debug)
    
    DBInterface.close(session.duckDBcon)
    session.duckDBcon = nothing

    SimTreeUtils.simpleLog(session, "[DuckDB] Closed '$(session.duckDBfile)'"; level=Logging.Debug)
end
#############################
#   Execute Querys
#############################
function _executeDuckDBQuery(session::SimTreeUtils.SimTreeSession, query::String)
    if session.useDuckDB == false
        return
    end

    if session.duckDBcon === nothing
        OpenDuckDB(session, session.duckDBfile)
    end
    
    DBInterface.execute(session.duckDBcon, query)
end
function _executeDuckDBSelect(session::SimTreeUtils.SimTreeSession, query::String)::DataFrames.DataFrame
    if session.useDuckDB == false
        return
    end

    if session.duckDBcon === nothing
        OpenDuckDB(session, session.duckDBfile)
    end
    
    return DBInterface.execute(session.duckDBcon, query) |> DataFrames.DataFrame
end
#############################
#   Lookup Types
#############################
const julia_to_duckDB = Dict(
    Int32   => "INTEGER",
    Int64   => "INTEGER",
    Float32 => "REAL",
    Float64 => "REAL",
    String  => "TEXT",
    Bool    => "BOOLEAN",
    Missing => "NULL",
    Nothing => "NULL",
    Vector{UInt8} => "BLOB"
)
function GetDuckDBType(column::Type; default::String="TEXT")::String
    return get(julia_to_duckDB, column, default)
end
#############################
#   Create & Alter Tables
#############################
function CreateDuckDBTable(session::SimTreeUtils.SimTreeSession, tableName::String, columns::OrderedDict{String, Type}; schema::Union{String, Nothing}=nothing, defaultColumns::Bool=true)
    if session.useDuckDB == false
        return
    end

    createColumns = join(["\"$k\" $(GetDuckDBType(v))" for (k, v) in columns], ", ")

    tableName = CreateSchema(session, schema, tableName)
    if defaultColumns
        _executeDuckDBQuery(session, "CREATE TABLE IF NOT EXISTS $(tableName) (TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP, $createColumns)")
    else
        _executeDuckDBQuery(session, "CREATE TABLE IF NOT EXISTS $(tableName) ($createColumns)")
    end

    for (k, v) in columns
        AddDuckDBTableColumn(session, tableName, k, v)
    end
end
function AddDuckDBTableColumn(session::SimTreeSession, tableName::String, column::String, columntype::Type)
    _executeDuckDBQuery(session, "ALTER TABLE $(tableName) ADD COLUMN IF NOT EXISTS \"$column\" $(GetDuckDBType(columntype))")
end
#############################
#   Insert Data
#############################
function AppendDuckDBData(session::SimTreeUtils.SimTreeSession, tableName::String, columnsDict::OrderedDict{String, Type}, dataDict::OrderedDict{String, Any}; schema::Union{String, Nothing}=nothing, defaultColumns::Bool=true)
    if session.useDuckDB == false
        return
    end
    
    SimTreeUtils.CreateDuckDBTable(session, tableName, columnsDict; schema=schema, defaultColumns=defaultColumns)
    SimTreeUtils.AddDuckDBTableRow(session, tableName, dataDict; schema=schema)
    #SimTreeUtils.ViewDuckDBScheme(session)
end
function AddDuckDBTableRow(session::SimTreeSession, tableName::String, data::Vector; schema::Union{String, Nothing}=nothing)
    #tableName = CreateSchema(ssession, chema, tableName)
    columns = join([v for (v) in data], ", ")
    _executeDuckDBQuery(session, "INSERT INTO $(tableName) VALUES($columns)")
end
function AddDuckDBTableRow(session::SimTreeSession, tableName::String, data::Dict{String, Any}; schema::Union{String, Nothing}=nothing)
    #tableName = CreateSchema(session, schema, tableName)
    columns = join(["$v AS $k" for (k, v) in data], ", ")
    _executeDuckDBQuery(session, "INSERT INTO $(tableName) BY NAME (SELECT $columns)")
end
function AddDuckDBTableRow(session::SimTreeSession, tableName::String, data::OrderedDict{String, Any}; schema::Union{String, Nothing}=nothing)
    #tableName = CreateSchema(session, schema, tableName)
    columns = join(["$v AS $k" for (k, v) in data], ", ")
    _executeDuckDBQuery(session, "INSERT INTO $(tableName) BY NAME (SELECT $columns)")
end
function InsertDuckDBDataFrame(session::SimTreeSession, tableName::String, df::DataFrame; schema::Union{String, Nothing}=nothing, insertParamsDict::Bool=true)
    if insertParamsDict
        insertcols!(df, 1, ("p[$(k)]" => fill(v, nrow(df)) for (k, v) in session.PARAMSDICT)...)
    end

    #viewName = "$(tableName)_view"
    #tableName = CreateSchema(session, schema, tableName)

    # register it as a view in the database
    #DuckDB.register_data_frame(session.duckDBcon, df, "$(viewName)")
    #_executeDuckDBQuery(session, "CREATE TABLE $(tableName) AS SELECT * FROM $(viewName)")
    #_executeDuckDBQuery(session, "DROP VIEW IF EXISTS $(viewName)")

    columnsDict = OrderedDict{String, Type}(name => eltype(df[!, name]) for name in names(df))
    CreateDuckDBTable(session, tableName, columnsDict; schema=schema, defaultColumns=false)
    
    # append data by row
    appender = DuckDB.Appender(session.duckDBcon, tableName, schema)
    for i in eachrow(df)
        for j in i
            DuckDB.append(appender, j)
        end
        DuckDB.end_row(appender)
    end
    # close the appender after all rows
    DuckDB.close(appender)
end
function CreateSchema(session::SimTreeSession, schema::Union{String, Nothing}, tableName::String)
    if schema === nothing
        return tableName
    else
        _executeDuckDBQuery(session, "CREATE SCHEMA IF NOT EXISTS $schema")
        return "$(schema).$(tableName)"
    end
end
#############################
#   Select Data
#############################
#Aufruf SelectDuckDBData mit Open/Close-DB
#function SelectDuckDBData(session::SimTreeUtils.SimTreeSession, table::String; limit::Integer=8, Columns::String="*")::DataFrame
#    #database = OpenDatabase(datapath::String, dbname::String)
#    data = SelectDuckDBData(session, table; limit, Columns)
#    CloseDuckDB(session)
#    return data
#end
function SelectDuckDBData(session::SimTreeUtils.SimTreeSession, tableName::String; limit::Integer=8, Columns::String="*")::DataFrame
    return _executeDuckDBSelect(session, "SELECT $Columns FROM $tableName LIMIT $limit;")
end
#############################
#   View Schema
#############################
#Aufruf ViewDuckDBScheme mit Open/Close-DB
#function ViewDuckDBScheme(db::string)
#    database = OpenDatabase(datapath::String, dbname::String)
#    ViewDuckDBScheme(session)
#    CloseDuckDB(session)
#end
function ViewDuckDBScheme(session::SimTreeUtils.SimTreeSession)
    tables = _executeDuckDBSelect(session, "SHOW ALL TABLES")
    println(tables)
    for tableRow in eachrow(tables)
        tableName = string(tableRow[:name])
        if tableRow[:temporary]
            println("Skip temporary Table '$tableName")
        else
            println("Show Table '$tableName")
            
            schema = _executeDuckDBSelect(session, "DESCRIBE $tableName")
            println(schema)

            println(SelectDuckDBData(session, tableName))
        end
    end
end
