#############################
#   Initialize Logger
#############################
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
#############################
#   Log Data
#############################
function logData(session::SimTreeUtils.SimTreeSession, data::Dict{String, Any}; level::Logging.LogLevel=Logging.Info)
    if session.useLokiLogger == false
        return
    end
    
    json = JSON3.write(data)
    _simpleLog(session.lokiData, string(json), level)
end
function logData(session::SimTreeUtils.SimTreeSession, data::OrderedDict{String, Any}; level::Logging.LogLevel=Logging.Info)
    if session.useLokiLogger == false
        return
    end
    
    json = JSON3.write(data)
    _simpleLog(session.lokiData, string(json), level)
end
function logData(session::SimTreeUtils.SimTreeSession, column::String, data::Any; level::Logging.LogLevel=Logging.Info)
    if session.useLokiLogger == false
        return
    end
    
    _simpleLog(session.lokiData, Dict{String, Any}(column => data); level)
end
