mutable struct DynamicLogger <: AbstractLogger
    loggers::Vector{AbstractLogger}
end

"""
    DynamicLogger(loggers...)

Send the same log message to all the loggers.

To include the current logger do:
`DynamicLogger(current_logger(), loggers...)`
to include the global logger, do:
`DynamicLogger(global_logger(), loggers...)`
"""
function DynamicLogger(loggers::Vararg{AbstractLogger})
    return DynamicLogger(loggers)
end

function handle_message(demux::DynamicLogger, args...; kwargs...)
    for logger in demux.loggers
        if comp_handle_message_check(logger, args...; kwargs...)
            handle_message(logger, args...; kwargs...)
        end
    end
end

function shouldlog(demux::DynamicLogger, args...)
    any(comp_shouldlog(logger, args...) for logger in demux.loggers)
end

function min_enabled_level(demux::DynamicLogger)
    minimum(min_enabled_level(logger) for logger in demux.loggers)
end

function catch_exceptions(demux::DynamicLogger)
    any(catch_exceptions(logger) for logger in demux.loggers)
end
#############################
#   Dynamic Functions (extends TeeLogger)
#############################
function add_logger!(wrapper::DynamicLogger, logger::AbstractLogger)
    if !(logger in wrapper.loggers)
        push!(wrapper.loggers, logger)
    end
end
function remove_logger!(wrapper::DynamicLogger, logger::AbstractLogger)
    filter!(x => x != logger, wrapper.loggers)
end
function replace_logger(wrapper::DynamicLogger, oldlogger::AbstractLogger, newlogger::AbstractLogger)
    remove_logger!(wrapper, oldlogger)
    add_logger!(wrapper, newlogger)
end
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
