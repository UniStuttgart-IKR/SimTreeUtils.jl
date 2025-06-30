#############################
#   Open & Close DB
#############################
function OpenDuckDB(session::SimTreeUtils.SimTreeSession, dbfile::String, drop::Bool)
    if session.useDuckDB == false
        return
    end

    session.duckDBfile = dbfile
    if session.duckDBfile == ":memory:"
        @error "Not implemented!"
        return
    end

    SimTreeUtils.simpleLog(session, "[DuckDB] Creating Database '$(session.duckDBfile))' Drop: $drop"; level=Logging.Debug)

    if drop==true && isfile(session.duckDBfile)
        SimTreeUtils.simpleLog(session, "[DuckDB] Drop Previos Database '$(session.duckDBfile))'"; level=Logging.Debug)
        rm(session.duckDBfile)
    end

    session.duckDBcon = DBInterface.connect(DuckDB.DB, session.duckDBfile)
    
    SimTreeUtils.simpleLog(session, "[DuckDB] Connection established; '$(session.duckDBfile))' Drop: $drop"; level=Logging.Debug)
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
    
    DBInterface.execute(session.duckDBcon, query)
end
function _executeDuckDBSelect(session::SimTreeUtils.SimTreeSession, query::String)::DataFrames.DataFrame
    if session.useDuckDB == false
        return
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
    Nothing => "NULL"
)
function GetDuckDBType(column::Type; default::String="TEXT")::String
    return get(julia_to_duckDB, column, default)
end
#############################
#   Create & Alter Tables
#############################
function CreateDuckDBTable(session::SimTreeUtils.SimTreeSession, tableName::String, columns::OrderedDict{String, Type})
    if session.useDuckDB == false
        return
    end

    createColumns = join(["$k $(GetDuckDBType(v))" for (k, v) in columns], ", ")

    _executeDuckDBQuery(session, "CREATE TABLE IF NOT EXISTS $tableName (TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP, $createColumns)")

    for (k, v) in columns
        AddDuckDBTableColumn(session, tableName, k, v)
    end
end
function AddDuckDBTableColumn(session::SimTreeSession, tableName::String, column::String, columntype::Type)
    _executeDuckDBQuery(session, "ALTER TABLE $tableName ADD COLUMN IF NOT EXISTS $column $(GetDuckDBType(columntype))")
end
#############################
#   Insert Data
#############################
function AppendDuckDBData(session::SimTreeUtils.SimTreeSession, tableName::String, columnsDict::OrderedDict{String, Type}, dataDict::OrderedDict{String, Any})
    if session.useDuckDB == false
        return
    end
    
    SimTreeUtils.CreateDuckDBTable(session, tableName, columnsDict)
    SimTreeUtils.AddDuckDBTableRow(session, tableName, dataDict)
    #SimTreeUtils.ViewDuckDBScheme(session)
end
function AddDuckDBTableRow(session::SimTreeSession, tableName::String, data::Vector)
    columns = join([v for (v) in data], ", ")
    _executeDuckDBQuery(session, "INSERT INTO $(tableName) VALUES($columns)")
end
function AddDuckDBTableRow(session::SimTreeSession, tableName::String, data::Dict{String, Any})
    columns = join(["$v AS $k" for (k, v) in data], ", ")
    _executeDuckDBQuery(session, "INSERT INTO $(tableName) BY NAME (SELECT $columns)")
end
function AddDuckDBTableRow(session::SimTreeSession, tableName::String, data::OrderedDict{String, Any})
    columns = join(["$v AS $k" for (k, v) in data], ", ")
    _executeDuckDBQuery(session, "INSERT INTO $(tableName) BY NAME (SELECT $columns)")
end
function InsertDuckDBDataFrame(session::SimTreeSession, tableName::String, df::DataFrame)
    println("Test function: Save '$tableName' via DataFrame")
    println("1 - Generate DF for '$tableName'")
    
    #DuckDB.load!(df, table, session.duckDBcon; overwrite=true)
    
    # register it as a view in the database
    println("2 - Create view '$tableName'")
    DuckDB.register_data_frame(session.duckDBcon, df, "$(tableName)_view")
    println("3 - Create table '$tableName'")
    DBInterface.execute(session.duckDBcon, "CREATE TABLE $tableName AS SELECT * FROM $(tableName)_view")
    println("4 - Drop view '$tableName'")
    DBInterface.execute(session.duckDBcon, "DROP VIEW IF EXISTS $(tableName)_view")
    
    println("9 - GC '$tableName'")
    df = nothing
    GC.gc()
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
