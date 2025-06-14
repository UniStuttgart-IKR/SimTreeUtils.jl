mutable struct SimTreeSession
    app::String
    SIMTREE_RESULTS_PATH::Union{String, Nothing}
    PARAMSDICT::Union{Dict{String, Any}, Nothing}
    SEED::Union{Int, Nothing}
    datapath::Union{String, Nothing}

    useLokiLogger::Bool
    lokiInit::LokiLogger.Logger
    lokiProd::Union{LokiLogger.Logger, Nothing}
    lokiData::Union{LokiLogger.Logger, Nothing}
    
    useDuckDB::Bool
    duckDBfile::Union{String, Nothing}
    duckDBcon::Union{DBInterface.Connection, Nothing}

    useSQLite::Bool
    sqliteFile::Union{String, Nothing}
    sqliteCon::Union{Nothing, Nothing}
end

function InitializeSession(app::String; useLokiLogger::Bool=true, useDuckDB::Bool=true, useSQLite::Bool=true)::SimTreeUtils.SimTreeSession
    session = SimTreeUtils.SimTreeSession(app, nothing, nothing, nothing, nothing,  #Simulation Parameters
        useLokiLogger, simloginit(app), nothing, nothing,                           #Loki Logger Init
        useDuckDB, nothing, nothing,                                                #DuckDB Init
        useSQLite, nothing, nothing)                                                #SQLite Init

    return SaveSession(session)
end

function PrepareSession(session::SimTreeUtils.SimTreeSession, SIMTREE_RESULTS_PATH::String, PARAMSDICT::Dict{String, Any}, SEED::Int, datapath::String)
    session.SIMTREE_RESULTS_PATH = SIMTREE_RESULTS_PATH
    session.PARAMSDICT = PARAMSDICT
    session.SEED = SEED
    session.datapath = datapath

    #Initialize Loki-Logger (Prod & Data)
    if session.useLokiLogger
        session.lokiProd = simloginit(session, "prod")
        session.lokiData = simloginit(session, "data")
    end

    #Initialize DuckDB Connection+DB (One DB per Parameter-Set)
    if session.useDuckDB
        session.duckDBfile = "$SIMTREE_RESULTS_PATH/$(session.app)).duckdb"
        session.duckDBcon = DBInterface.connect(DuckDB.DB, session.duckDBfile) #Open File & Create if not exist
        #CreateBaseTable(OpenDatabase(SIMTREE_RESULTS_PATH, "database"), PARAMSDICT, SEED, datapath)
    end

    #Initialize SQLIte Connection+DB (One single DB with multiple Write-Connections => WAL)
    if session.useSQLite
        session.sqliteFile = "$SIMTREE_RESULTS_PATH/$(session.app)).sqlite"
        session.sqliteCon = nothing # DBInterface.connect(DuckDB.DB, session.sqliteFile)
    end

    SaveSession(session)
end

function CloseSession(session::SimTreeUtils.SimTreeSession)
    CloseDataBase(session)

    SaveSession(session)
end

function SaveSession(session::SimTreeUtils.SimTreeSession)::SimTreeUtils.SimTreeSession
    Base.task_local_storage("session", session)
    return session
end

function GetSession()::SimTreeUtils.SimTreeSession
    session = Base.task_local_storage("session")
    session === nothing && @error "No active Session found!"
    return session
end
function GetSession(session::Union{SimTreeUtils.SimTreeSession, Nothing})::SimTreeUtils.SimTreeSession
    if session === nothing
        return GetSession()
    end
    return session
end

