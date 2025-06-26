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
function DynamicLogger(loggers::AbstractLogger...)
    return DynamicLogger(collect(loggers))
end
# For checking if child logger will take the message you are sending
function comp_handle_message_check(logger, args...; kwargs...)
    level, message, _module, group, id, file, line = args
    return comp_shouldlog(logger, level, _module, group, id)
end
function Logging.handle_message(demux::DynamicLogger, args...; kwargs...)
    for logger in demux.loggers
        if comp_handle_message_check(logger, args...; kwargs...)
            Logging.handle_message(logger, args...; kwargs...)
        end
    end
end
# For checking child logger, need to check both `min_enabled_level` and `shouldlog`
function comp_shouldlog(logger, level, _module, group, id)
    level = convert(LogLevel, level)
    (Logging.min_enabled_level(logger) <= level && Logging.shouldlog(logger, level, _module, group, id)) ||
        Base.CoreLogging.env_override_minlevel(group, _module)
        # `env_override_minlevel` is the internal function that makes JULIA_DEBUG environment variable work
end
function Logging.shouldlog(demux::DynamicLogger, args...)
    any(comp_shouldlog(logger, args...) for logger in demux.loggers)
end

function Logging.min_enabled_level(demux::DynamicLogger)
    minimum(Logging.min_enabled_level(logger) for logger in demux.loggers)
end

function Logging.catch_exceptions(demux::DynamicLogger)
    any(Logging.catch_exceptions(logger) for logger in demux.loggers)
end
#############################
#   Dynamic Functions (extends TeeLogger)
#############################
function add_logger!(demux::DynamicLogger, logger::AbstractLogger)
    if !(logger in demux.loggers)
        push!(demux.loggers, logger)
    end
end
function remove_logger!(demux::DynamicLogger, logger::AbstractLogger)
    filter!(x -> x != logger, demux.loggers)
end
function replace_logger!(demux::DynamicLogger, oldlogger::AbstractLogger, newlogger::AbstractLogger)
    remove_logger!(demux, oldlogger)
    add_logger!(demux, newlogger)
end
