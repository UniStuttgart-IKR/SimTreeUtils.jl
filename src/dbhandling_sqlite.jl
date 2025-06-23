
function OpenSQLiteDB(session::SimTreeUtils.SimTreeSession, dbfile::String, drop::Bool)
    if session.useSQLite == false
        return
    end
    
    SimTreeUtils.logInit(session, "[SQLite] Creating Database '$(dbfile)' Drop: $(drop)")
    session.sqliteFile = dbfile

    if drop==true && isfile(session.sqliteFile)
        rm(session.sqliteFile)
    end
    
    session.sqliteCon = SQLite.DB(session.sqliteFile) #Open File & Create if not exist
    #CreateBaseTable(OpenDatabase(SIMTREE_RESULTS_PATH, "database"), PARAMSDICT, SEED, datapath)
    
    SimTreeUtils.logInit(session, "[SQLite] Connection established; '$(dbfile)' Drop: $(drop)")
end

function CloseSQLiteDB(session::SimTreeUtils.SimTreeSession)
    if session.useSQLite == false
        return
    end
    
    SimTreeUtils.logInit(session, "[SQLite] Closing Connection '$(session.sqliteFile)'")
    
    DBInterface.close(session.sqliteCon)
    session.sqliteCon = nothing

    SimTreeUtils.logInit(session, "[SQLite] Closed '$(session.sqliteFile)'")
end

function AppendSQLiteData(session::SimTreeUtils.SimTreeSession, tableName::String, columnsDict::OrderedDict{String, Type}, dataDict::OrderedDict{String, Any})
    if session.useSQLite == false
        return
    end
    
    SimTreeUtils.CreateSQLiteTable(session, tableName, columnsDict)
    #SimTreeUtils.AddDuckDBTableRow(table, dataDict)
    #SimTreeUtils.ViewDuckDBScheme(session)
end

function CreateSQLiteTable(session::SimTreeUtils.SimTreeSession, tableName::String, columns::OrderedDict{String, Type})
    schema = Tables.Schema(["test1", "test2", "test3"], [Int, Float64, String])
    SQLite.createtable!(session.sqliteCon, tableName, schema; temp=false, ifnotexists=true)
end