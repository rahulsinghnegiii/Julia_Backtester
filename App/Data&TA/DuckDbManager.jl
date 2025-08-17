module DatabaseManager

using DuckDB
using Base.Threads
using Logging

export get_connection,
    close_connection, init_connection, get_thread_connection, cleanup_connections

# Global variables for connection management
const DB_CONNECTION = Ref{Union{DuckDB.DB,Nothing}}(nothing)
const CONNECTION_POOL = Vector{Union{DuckDB.DB,Nothing}}()
const CONNECTION_LOCK = ReentrantLock()
const POOL_SIZE = Ref{Int}(20)  # Increased pool size to handle more connections

"""
    initialize_connection_pool(pool_size::Int = 10)

Initialize the connection pool with specified size.
"""
function initialize_connection_pool(pool_size::Int=10)
    try
        lock(CONNECTION_LOCK) do
            POOL_SIZE[] = pool_size
            resize!(CONNECTION_POOL, pool_size)
            fill!(CONNECTION_POOL, nothing)
            @info "Initialized connection pool with size $pool_size"
        end
    catch e
        @error "Error initializing connection pool" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    get_available_connection()

Get an available connection from the pool or create a new one.
"""
function get_available_connection()
    try
        lock(CONNECTION_LOCK) do
            # First, try to find an existing connection
            for (i, conn) in enumerate(CONNECTION_POOL)
                if conn !== nothing && check_connection_health(conn)
                    return conn
                end
            end

            # If no healthy connection found, create a new one in an empty slot
            for i in 1:length(CONNECTION_POOL)
                if CONNECTION_POOL[i] === nothing
                    CONNECTION_POOL[i] = DuckDB.DB()
                    return CONNECTION_POOL[i]
                end
            end

            # If no empty slots, create a new connection in the first position
            if !isempty(CONNECTION_POOL)
                try
                    close(CONNECTION_POOL[1])
                catch
                end
                CONNECTION_POOL[1] = DuckDB.DB()
                return CONNECTION_POOL[1]
            end

            # If pool is empty (shouldn't happen), create a new connection
            push!(CONNECTION_POOL, DuckDB.DB())
            return CONNECTION_POOL[end]
        end
    catch e
        @error "Error getting available connection" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    get_thread_connection()

Get a database connection (thread-safe).
"""
function get_thread_connection()
    try
        return get_available_connection()
    catch e
        @error "Error in get_thread_connection" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    init_connection()

Initialize the main database connection and connection pool.
"""
function init_connection()
    try
        initialize_connection_pool()

        lock(CONNECTION_LOCK) do
            if DB_CONNECTION[] === nothing
                @info "Initializing main database connection"
                DB_CONNECTION[] = DuckDB.DB()
            end
        end
        return DB_CONNECTION[]
    catch e
        @error "Error initializing database connection" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    get_connection()

Get the main database connection.
"""
function get_connection()
    try
        if DB_CONNECTION[] === nothing
            @info "Connection not initialized. Initializing..."
            return init_connection()
        end
        return DB_CONNECTION[]
    catch e
        @error "Error getting database connection" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    close_connection()

Close the main database connection safely.
"""
function close_connection()
    try
        lock(CONNECTION_LOCK) do
            if DB_CONNECTION[] !== nothing
                close(DB_CONNECTION[])
                DB_CONNECTION[] = nothing
            end
        end
    catch e
        @error "Error closing database connection" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    cleanup_connections()

Clean up all connections in the pool.
"""
function cleanup_connections()
    try
        lock(CONNECTION_LOCK) do
            for (i, conn) in enumerate(CONNECTION_POOL)
                if conn !== nothing
                    try
                        close(conn)
                    catch
                    end
                    CONNECTION_POOL[i] = nothing
                end
            end
        end
    catch e
        @error "Error cleaning up connections" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

"""
    check_connection_health(conn::Union{DuckDB.DB, Nothing})

Verify if a connection is healthy and active.
"""
function check_connection_health(conn::Union{DuckDB.DB,Nothing})
    if conn === nothing
        return false
    end

    try
        DuckDB.execute(conn, "SELECT 1")
        return true
    catch
        return false
    end
end

# Initialize when the module loads
function __init__()
    return initialize_connection_pool()
end

end
