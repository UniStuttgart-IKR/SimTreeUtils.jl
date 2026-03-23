#############################
#   Session Struct
#############################
"""
SimTreeSession(app, SIMTREE_RESULTS_PATH, PARAMSDICT, SEED, datapath, logger, tempLogger,
useLokiLogger, lokiData, useDuckDB, duckDBfile, duckDBcon, useSQLite, sqliteFile, sqliteCon)


Container for the runtime configuration and resources of a SimTree session.


Fields



app::String Name of the application or simulation run.

SIMTREE_RESULTS_PATH::Union{String, Nothing} Optional path where results should be written.

PARAMSDICT::Union{Dict{String, Any}, Nothing} Optional dictionary of parameters used for the session.

SEED::Union{Int, Nothing} Optional random seed for reproducibility.

datapath::Union{String, Nothing} Optional base data path used by the session.


Logging



logger::DynamicLogger Primary logger used for the session.

tempLogger::Union{LokiLogger.Logger, Nothing} Optional temporary logger (e.g., buffered or short-lived).

useLokiLogger::Bool Whether Loki logging is enabled.

lokiData::Union{LokiLogger.Logger, Nothing} Optional Loki logger instance / data sink.


Databases



useDuckDB::Bool Whether DuckDB is in use.

duckDBfile::Union{String, Nothing} Optional path to the DuckDB file.

duckDBcon::Union{DBInterface.Connection, Nothing} Optional active DuckDB connection (should be closed when done).

useSQLite::Bool Whether SQLite is in use.

sqliteFile::Union{String, Nothing} Optional path to the SQLite file.

sqliteCon::Union{SQLite.DB, Nothing} Optional active SQLite connection (should be closed when done).


Notes



Instances are mutable and hold external resources (temporary loggers, DB connections). Callers are responsible for cleanly closing or releasing these resources when the session ends (for example via a cleanup/close! function or in a try/finally block).

This docstring documents the type and its intended usage. If you provide a custom constructor or helper (e.g., SimTreeSession(...; init_databases=true)), document that constructor separately.


Example
Create a minimal session and remember to close DB connections and loggers when finished:
s = SimTreeSession("myapp", nothing, nothing, 1234, "/data", mylogger, nothing, false, nothing, false, nothing, nothing, false, nothing, nothing)


... use s ...

close sqliteCon / duckDBcon / tempLogger as appropriate

"""
mutable struct SimTreeSession
    app::String
    SIMTREE_RESULTS_PATH::Union{String, Nothing}
    PARAMSDICT::Union{Dict{String, Any}, Nothing}
    SEED::Union{Int, Nothing}
    datapath::Union{String, Nothing}

    logger::DynamicLogger
    tempLogger::Union{LokiLogger.Logger, Nothing}

    useLokiLogger::Bool
    lokiData::Union{LokiLogger.Logger, Nothing}

    useDuckDB::Bool
    duckDBfile::Union{String, Nothing}
    duckDBcon::Union{DBInterface.Connection, Nothing}

    useSQLite::Bool
    sqliteFile::Union{String, Nothing}
    sqliteCon::Union{SQLite.DB, Nothing}
end
#############################
#   Initialize Session
#############################
function InitializeSession(app::String, useLokiLogger::Bool = true, useDuckDB::Bool = true, useSQLite::Bool = true)::SimTreeUtils.SimTreeSession
    session = SimTreeUtils.SimTreeSession(
        app, nothing, nothing, nothing, nothing,  #Simulation Parameters
        DynamicLogger(global_logger()), nothing,                                    #DynamicLogger
        useLokiLogger, nothing,                                                     #Loki Logger Init
        useDuckDB, nothing, nothing,                                                #DuckDB Init
        useSQLite, nothing, nothing
    )                                                #SQLite Init

    #Initialize Loki-Logger (Init)
    if session.useLokiLogger
        session.tempLogger = simloginit(app)
        add_logger!(session.logger, session.tempLogger)
        SimTreeUtils.simpleLog(session, "[Loki] Init-Logger ready"; level = Logging.Debug)
    end

    return SaveSession(session)
end
function TestSession(resultspath; app::String = "TestSession", useLokiLogger::Bool = true, useDuckDB::Bool = true, useSQLite::Bool = true)::SimTreeUtils.SimTreeSession
    session = InitializeSession(app, useLokiLogger, useDuckDB, useSQLite)

    datapath = "$(pwd())"
    PrepareSession(session, resultspath, Dict{String, Any}("param1" => 1, "param2" => 0.01, "param3" => "test"), 1, datapath; drop = true)
    return SaveSession(session)
end
#############################
#   Extend Session (Prod-Use)
#############################
function PrepareSession(session::SimTreeUtils.SimTreeSession, SIMTREE_RESULTS_PATH::String, PARAMSDICT::Dict{String, Any}, SEED::Int, datapath::String; drop::Bool = false)
    session.SIMTREE_RESULTS_PATH = SIMTREE_RESULTS_PATH
    session.PARAMSDICT = PARAMSDICT
    session.SEED = SEED
    session.datapath = datapath

    #Initialize Loki-Logger (Prod & Data)
    if session.useLokiLogger
        #Replace Init-Logger with Prod-Logger
        SimTreeUtils.simpleLog(session, "[Loki] Init-Logger dropped"; level = Logging.Debug)
        replace_logger!(session.logger, session.tempLogger, simloginit(session, "prod"))
        session.tempLogger = nothing

        SimTreeUtils.simpleLog(session, "[Loki] Prod-Logger ready"; level = Logging.Debug)
        session.lokiData = simloginit(session, "data")
        SimTreeUtils.simpleLog(session, "[Loki] Data-Logger ready"; level = Logging.Debug)
    end

    #Initialize DuckDB Connection+DB (One DB per Parameter-Set)
    if session.useDuckDB
        SimTreeUtils.OpenDuckDB(session, "$(session.SIMTREE_RESULTS_PATH)/results.duckdb"; dropDataBase = drop, createParamsDictTable = true)
    end

    #Initialize SQLIte Connection+DB (One single DB with multiple Write-Connections => WAL)
    if session.useSQLite
        SimTreeUtils.OpenSQLiteDB(session, "$(session.SIMTREE_RESULTS_PATH)/results.sqlite", drop)
    end

    return SaveSession(session)
end
#############################
#   Close Session
#############################
function CloseSession(session::SimTreeUtils.SimTreeSession)
    if session.useDuckDB
        CloseDuckDB(session)
    end

    if session.useSQLite
        CloseSQLiteDB(session)
    end

    return SaveSession(session)
end
#############################
#   Store/Get Session
#############################
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
