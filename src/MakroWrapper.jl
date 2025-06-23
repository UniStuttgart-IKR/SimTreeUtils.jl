#Macro Binding to extract variablename from input-variable
#https://discourse.julialang.org/t/retrieve-variable-name-inside-function/83753/2
macro logValues(vars...)
    pairs = [:( $(string(v)) => $(esc(v)) ) for v in vars]
    return quote
        session = SimTreeUtils.GetSession(nothing)
        dict = OrderedDict{String, Any}($(pairs...))

        if session.useLokiLogger == false
            return
        end

        SimTreeUtils.logData(session, dict; level=Logging.Info)
    end
end
macro saveDB(vars...)
    _tableName = string(vars[1])
    pairs = [:( $(string(v)) => $(esc(v)) ) for v in vars]
    return quote
        session = SimTreeUtils.GetSession(nothing)

        local tableName = $_tableName
        tempDict = OrderedDict{String, Any}(((k => v) for (k, v) in session.PARAMSDICT)..., $(pairs...))

        columnsDict = OrderedDict{String, Type}(((k => typeof(v)) for (k, v) in tempDict)...)
        dataDict = OrderedDict{String, Any}(((k => isa(v, String) ? "'$v'" : v) for (k, v) in tempDict)...)

        if session.useDuckDB == true
            SimTreeUtils.AppendDuckDBData(session, tableName, columnsDict, dataDict)
        end
        
        if session.useSQLite == true
            SimTreeUtils.AppendSQLiteData(session, tableName, columnsDict, dataDict)
        end
    end
end
