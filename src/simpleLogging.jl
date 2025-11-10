#############################
#   Generic/Simple Logging
#############################
function simpleLog(session::SimTreeUtils.SimTreeSession, data::String; level::Logging.LogLevel=Logging.Info)
    _simpleLog(session.logger, data, level)
end
function simpleLog(session::SimTreeUtils.SimTreeSession, data::Dict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _simpleLog(session.logger, string(json), level)
end
function simpleLog(session::SimTreeUtils.SimTreeSession, data::OrderedDict{String, Any}; level::Logging.LogLevel=Logging.Info)
    json = JSON3.write(data)
    _simpleLog(session.logger, string(json), level)
end
#############################
#   Fundamental Logger
#############################
function _simpleLog(logger::AbstractLogger, data::String, level::Logging.LogLevel)
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
