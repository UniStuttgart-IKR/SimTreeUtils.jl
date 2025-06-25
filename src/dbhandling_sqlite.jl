#############################
#   Open & Close DB
#############################
function OpenSQLiteDB(session::SimTreeUtils.SimTreeSession, dbfile::String, drop::Bool)
    if session.useSQLite == false
        return
    end

    session.sqliteFile = dbfile
    if session.sqliteFile == ":memory:"
        @error "Not implemented!"
        return
    end
    
    SimTreeUtils.logInit(session, "[SQLite] Creating Database '$(session.sqliteFile))' Drop: $drop")

    if drop==true && isfile(session.sqliteFile)
        SimTreeUtils.logInit(session, "[SQLite] Drop Previos Database '$(session.sqliteFile))'")
        rm(session.sqliteFile)
    end
    
    session.sqliteCon = SQLite.DB(session.sqliteFile)
    
    SimTreeUtils.logInit(session, "[SQLite] Connection established; '$(session.sqliteFile))' Drop: $drop")
end
function CloseSQLiteDB(session::SimTreeUtils.SimTreeSession)
    if session.useSQLite == false
        return
    end

    if session.sqliteFile == ":memory:"
        @error "Not implemented!"
        return
    end
    
    SimTreeUtils.logInit(session, "[SQLite] Closing Connection '$(session.sqliteFile)'")
    
    DBInterface.close(session.sqliteCon)
    session.sqliteCon = nothing

    SimTreeUtils.logInit(session, "[SQLite] Closed '$(session.sqliteFile)'")
end
#############################
#   Execute Querys
#############################
function _executeSQLiteQuery(session::SimTreeUtils.SimTreeSession, query::String)
    if session.useSQLite == false
        return
    end
    
    DBInterface.execute(session.sqliteCon, query)
end
function _executeSQLiteSelect(session::SimTreeUtils.SimTreeSession, query::String)::DataFrames.DataFrame
    if session.useSQLite == false
        return
    end
    
    return DBInterface.execute(session.sqliteCon, query) |> DataFrames.DataFrame
end
#############################
#   Create & Alter Tables
#############################
function CreateSQLiteTable(session::SimTreeUtils.SimTreeSession, tableName::String, columns::OrderedDict{String, Type})
    columnsVec = [k for (k,v) in columns]
    columnsTypeVec = [v for (k,v) in columns]

    schema = Tables.Schema(columnsVec, columnsTypeVec)
    SQLite.createtable!(session.sqliteCon, tableName, schema; temp=false, ifnotexists=true)
end
#############################
#   Insert Data
#############################
function AppendSQLiteData(session::SimTreeUtils.SimTreeSession, tableName::String, columnsDict::OrderedDict{String, Type}, dataDict::OrderedDict{String, Any})
    if session.useSQLite == false
        return
    end
    
    SimTreeUtils.CreateSQLiteTable(session, tableName, columnsDict)
    SimTreeUtils.AddSQLiteTableRow(session, tableName, dataDict)
    #SimTreeUtils.ViewDuckDBScheme(session)
end
function AddSQLiteTableRow(session::SimTreeUtils.SimTreeSession, tableName::String, data::OrderedDict{String, Any})
    columns = join(["$k" for (k, v) in data], ", ")
    values = join(["$v" for (k, v) in data], ", ")

    _executeSQLiteQuery(session, "INSERT INTO $tableName ($columns) VALUES ($values);")
end
#############################
#   Select Data
#############################
function SelectSQLiteData(session::SimTreeUtils.SimTreeSession, tableName::String; limit::Integer=8, Columns::String="*")::DataFrame
    return _executeSQLiteSelect(session, "SELECT $Columns FROM $tableName LIMIT $limit;")
end
