#############################
#   Basic Plotting
#############################
function plotXY(session::SimTreeUtils.SimTreeSession, tableName::String, colX::String, colY::Vector{String}; limit::Integer=8, duckdb::Bool=true)
    x = nothing
    y = nothing

    if duckdb
        x = SelectDuckDBData(session, tableName; limit, Columns=colX)
        y = SelectDuckDBData(session, tableName; limit, Columns=join(colY, ", "))
    else
        x = SelectSQLiteData(session, tableName; limit, Columns=colX)
        y = SelectSQLiteData(session, tableName; limit, Columns=join(colY, ", "))
    end
    
    labels = reshape(colY, 1, :)
    Plots.plot(Matrix(x), Matrix(y), title="$(session.app)/$tableName", labels=labels, xlabel="$colX")
end
