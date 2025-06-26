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
    
    SimTreeUtils.simpleLog(session, "[SQLite] Creating Database '$(session.sqliteFile))' Drop: $drop"; level=Logging.Debug)

    if drop==true && isfile(session.sqliteFile)
        SimTreeUtils.simpleLog(session, "[SQLite] Drop Previos Database '$(session.sqliteFile))'"; level=Logging.Debug)
        rm(session.sqliteFile)
    end
    
    session.sqliteCon = SQLite.DB(session.sqliteFile)
    SimTreeUtils._executeSQLiteQuery(session, "PRAGMA journal_mode_wal;")
    
    SimTreeUtils.simpleLog(session, "[SQLite] Connection established; '$(session.sqliteFile))' Drop: $drop"; level=Logging.Debug)
end
function CloseSQLiteDB(session::SimTreeUtils.SimTreeSession)
    if session.useSQLite == false
        return
    end

    if session.sqliteCon === nothing
        return
    end

    if session.sqliteFile == ":memory:"
        @error "Not implemented!"
        return
    end
    
    SimTreeUtils.simpleLog(session, "[SQLite] Closing Connection '$(session.sqliteFile)'"; level=Logging.Debug)
    
    DBInterface.close(session.sqliteCon)
    session.sqliteCon = nothing

    SimTreeUtils.simpleLog(session, "[SQLite] Closed '$(session.sqliteFile)'"; level=Logging.Debug)
end
#############################
#   Execute Querys
#############################
function _executeSQLiteQuery(session::SimTreeUtils.SimTreeSession, query::String)
    if session.useSQLite == false
        return
    end
    
    for attempt in 1:5
        try
            DBInterface.execute(session.sqliteCon, query)
            break
        catch e
            if isa(e, SQLite.SQLiteException)
                SimTreeUtils.logProd(session, "[SQLite] DB locked"; level=Logging.Error)
                sleep(0.5)
            else
                rethrow(e)
            end
        end
    end
end
function _executeSQLiteSelect(session::SimTreeUtils.SimTreeSession, query::String)::DataFrames.DataFrame
    if session.useSQLite == false
        return
    end
    
    for attempt in 1:5
        try
            return DBInterface.execute(session.sqliteCon, query) |> DataFrames.DataFrame
        catch e
            if isa(e, SQLite.SQLiteException)
                SimTreeUtils.logProd(session, "[SQLite] DB locked"; level=Logging.Error)
                sleep(0.5)
            else
                rethrow(e)
            end
        end
    end
    return nothing
end
#############################
#   Create & Alter Tables
#############################
function CreateSQLiteTable(session::SimTreeUtils.SimTreeSession, tableName::String, columns::OrderedDict{String, Type})
    if session.useSQLite == false
        return
    end

    createColumns = join(["$k $v" for (k, v) in columns], ", ")

    _executeSQLiteQuery(session, "CREATE TABLE IF NOT EXISTS $tableName (TIMESTAMP DATETIME DEFAULT(datetime('subsec')), $createColumns)")

    existing = SQLite.columns(session.sqliteCon, tableName)
    for (k, v) in columns
        if k in existing.name
            continue
        end

        AddSQLiteTableColumn(session, tableName, k, v)
    end
end
function AddSQLiteTableColumn(session::SimTreeSession, tableName::String, column::String, columntype::Type)
    _executeSQLiteQuery(session, "ALTER TABLE $tableName ADD COLUMN $column $columntype")
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
