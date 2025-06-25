function OpenDuckDB(session::SimTreeUtils.SimTreeSession, dbfile::String, drop::Bool)
    if session.useDuckDB == false
        return
    end

    if session.duckDBfile == ":memory:"
        @error "Not implemented!"
        return
    end

    SimTreeUtils.logInit(session, "[DuckDB] Creating Database '$(dbfile)' Drop: $(drop)")
    session.duckDBfile = dbfile

    if drop==true && isfile(session.duckDBfile)
        rm(session.duckDBfile)
    end

    session.duckDBcon = DBInterface.connect!(DuckDB.DB, session.duckDBfile)
    
    SimTreeUtils.logInit(session, "[DuckDB] Connection established; '$(dbfile)' Drop: $(drop)")
end
function CloseDuckDB(session::SimTreeUtils.SimTreeSession)
    if session.useDuckDB == false
        return
    end

    if session.duckDBfile == ":memory:"
        @error "Not implemented!"
        return
    end
    
    SimTreeUtils.logInit(session, "[DuckDB] Closing Connection '$(session.sqliteFile)'")
    
    DBInterface.close(session.duckDBcon)
    session.duckDBcon = nothing

    SimTreeUtils.logInit(session, "[DuckDB] Closed '$(session.sqliteFile)'")
end

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

function AppendDuckDBData(session::SimTreeUtils.SimTreeSession, tableName::String, columnsDict::OrderedDict{String, Type}, dataDict::OrderedDict{String, Any})
    if session.useDuckDB == false
        return
    end
    
    SimTreeUtils.CreateDuckDBTable(session, tableName, columnsDict)
    SimTreeUtils.AddDuckDBTableRow(session, tableName, dataDict)
    #SimTreeUtils.ViewDuckDBScheme(session)
end

const julia_to_duckDB = Dict(
    Int32   => "INTEGER",
    Int64   => "INTEGER",
    Float32 => "REAL",
    Float64 => "REAL",
    String  => "TEXT",
    Bool    => "BOOLEAN",
    Missing => "NULL"
)
function GetDuckDBType(column::Type; default::String="TEXT")::String
    return get(julia_to_duckDB, column, default)
end

function CreateDuckDBTable(session::SimTreeUtils.SimTreeSession, tableName::String, columns::OrderedDict{String, Type})
    if session.useDuckDB == false
        return nothing
    end

    createColumns = join(["$k $(GetDuckDBType(v))" for (k, v) in columns], ", ")

    _executeDuckDBQuery(session, "CREATE TABLE IF NOT EXISTS $tableName ($createColumns)")

    for (k, v) in columns
        AddDuckDBTableColumn(session, tableName, k, v)
    end
end

function AddDuckDBTableColumn(session::SimTreeSession, tableName::String, column::String, columntype::Type)
    _executeDuckDBQuery(session, "ALTER TABLE $tableName ADD COLUMN IF NOT EXISTS $column $(GetDuckDBType(columntype)))")
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


#Aufruf SelectDuckDBData mit Open/Close-DB
#function SelectDuckDBData(session::SimTreeUtils.SimTreeSession, table::String; limit::Integer=8, Columns::String="*")::DataFrame
#    #database = OpenDatabase(datapath::String, dbname::String)
#    data = SelectDuckDBData(session, table; limit, Columns)
#    CloseDuckDB(session)
#    return data
#end
function SelectDuckDBData(session::SimTreeUtils.SimTreeSession, tableName::String; limit::Integer=8, Columns::String="*")::DataFrame
    return _executeDuckDBSelect(session, "SELECT $(Columns) FROM $(tableName) LIMIT $(limit);")
end

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
        table = string(tableRow[:name])
        if tableRow[:temporary]
            println("Skip temporary Table '$table")
        else
            println("Show Table '$table")
            
            schema = _executeDuckDBSelect(session, "DESCRIBE $(table)")
            println(schema)

            println(SelectDuckDBData(session, table))
        end
    end
end

#Temporary easy plotting function
function plotXY(session::SimTreeUtils.SimTreeSession, tableName::String, colX::String, colY::Matrix{String}; limit::Integer=8)
    #database = OpenDatabase(datapath::String, dbname::String)
    x = SelectDuckDBData(session, tableName; limit, Columns=colX)
    y = SelectDuckDBData(session, tableName; limit, Columns=join(colY, ", "))
    CloseDuckDB(session)
    
    Plots.plot(Matrix(x), Matrix(y), title="$(session.app)/$tableName", labels=colY, xlabel="$colX")
end
