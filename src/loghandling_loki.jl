function simloginit(
    app::String,
    status::String = "initializing"
    ;endpoint::String="http://netlabdesk5:3100")::LokiLogger.Logger
    
    return _simloginit(endpoint, app, status, Dict{String, String}())
end

function simloginit(session::SimTreeUtils.SimTreeSession,
    status::String="prod"
    ;endpoint::String="http://netlabdesk5:3100")::LokiLogger.Logger

    return _simloginit(endpoint, session.app, status,
        Dict{String, String}("SEED" => string(session.SEED), "datapath" => session.datapath,
            ((k => string(v)) for (k, v) in session.PARAMSDICT)...))
end

function _simloginit(
    endpoint::String,
    app::String,
    status::String,
    labelsDict::Dict{String, String})::LokiLogger.Logger


    return LokiLogger.Logger(LokiLogger.json, endpoint; 
        labels=Dict{String, String}("host" => gethostname(), "user" => Sys.username(), "lokiLogger" => "LokiLogger.jl", "app" => app, "status" => status,
            ((k => v) for (k, v) in labelsDict)...))
end

#Logging der Init-Ereignisse
function logInit(session::SimTreeUtils.SimTreeSession, data::String; level::Logging.LogLevel=Logging.Info)
    _lokiLog(session.lokiInit, data, level)
end
function logInit(session::SimTreeUtils.SimTreeSession, data::Dict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _lokiLog(session.lokiInit, string(json), level)
end
function logInit(session::SimTreeUtils.SimTreeSession, data::OrderedDict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _lokiLog(session.lokiInit, string(json), level)
end
#Logging der Produktiv-Ereignisse
function logProd(session::SimTreeUtils.SimTreeSession, data::String; level::Logging.LogLevel=Logging.Info)
    _lokiLog(session.lokiProd, data, level)
end
function logProd(session::SimTreeUtils.SimTreeSession, data::Dict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _lokiLog(session.lokiProd, string(json), level)
end
function logProd(session::SimTreeUtils.SimTreeSession, data::OrderedDict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _lokiLog(session.lokiProd, string(json), level)
end
#Logging von Rohdaten als JSON
function logData(session::SimTreeUtils.SimTreeSession, data::Dict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _lokiLog(session.lokiData, string(json), level)
end
function logData(session::SimTreeUtils.SimTreeSession, data::OrderedDict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _lokiLog(session.lokiData, string(json), level)
end
function logData(session::SimTreeUtils.SimTreeSession, column::String, data::Any; level::Logging.LogLevel=Logging.Info)
    logData(session, Dict{String, Any}(column => data); level)
end

function _lokiLog(logger::LokiLogger.Logger, data::String, level::Logging.LogLevel)
    with_logger(logger) do
        if level == Logging.Info
            @info data
        elseif level == Logging.Debug
            @debug data
        elseif level == Logging.Warn
            @warn data
        elseif level == Logging.Error
            @error data
            
        else
            @error string("INVALID LOGLEVEL: ", level, " | ", data)
        end
    end
end
