module GlobalServerCache

using LRUCache
using DataFrames
using Dates
using Base.Threads
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types: DayData

export initialize_server_cache,
    get_price_data,
    get_indicator_data,
    cache_price_data,
    cache_indicator_data,
    cleanup_cache,
    clear_old_cache_entries,
    get_subtree_data,
    cache_subtree_data

mutable struct CacheEntry{T}
    data::T
    last_accessed::DateTime
    last_updated::DateTime
end

mutable struct ServerCacheManager
    prices::LRU{String,CacheEntry{DataFrame}}
    indicators::LRU{String,CacheEntry{Vector{Float32}}}
    subtree::LRU{String,CacheEntry{Vector{DayData}}}
    cache_lock::ReentrantLock
    initialized::Bool
    max_age::Period
    live_execution::Bool
end

# Singleton instance
const CACHE_MANAGER = Ref{ServerCacheManager}()

"""
Initialize the server cache with configuration parameters
"""
function initialize_server_cache(;
    price_cache_size::Int=1000,
    indicator_cache_size::Int=1000,
    subtree_cache_size::Int=2000,
    max_age::Period=Hour(4),
    live_execution::Bool=false,
)
    if !isdefined(CACHE_MANAGER, :x) || !CACHE_MANAGER[].initialized
        CACHE_MANAGER[] = ServerCacheManager(
            LRU{String,CacheEntry{DataFrame}}(; maxsize=price_cache_size, by=sizeof),
            LRU{String,CacheEntry{Vector{Float32}}}(;
                maxsize=indicator_cache_size, by=sizeof
            ),
            LRU{String,CacheEntry{Vector{DayData}}}(;
                maxsize=subtree_cache_size, by=sizeof
            ),
            ReentrantLock(),
            true,
            max_age,
            live_execution,
        )

        # Start background cleanup task
        @async begin
            while true
                try
                    sleep(Hour(1))  # Run cleanup every hour
                    clear_old_cache_entries()
                catch e
                    @error "Cache cleanup error" exception = e
                end
            end
        end
    end
    return CACHE_MANAGER[]
end

"""
Get price data from cache
"""
function get_price_data(symbol::String)::Union{DataFrame,Nothing}
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        if haskey(cache_manager.prices, symbol)
            entry = cache_manager.prices[symbol]
            current_time = Dates.now()

            if current_time - entry.last_updated > cache_manager.max_age
                delete!(cache_manager.prices, symbol)
                return nothing
            end

            # Update last accessed time
            entry.last_accessed = current_time
            return entry.data
        end
        return nothing
    end
end

"""
Get indicator data from cache
"""
function get_indicator_data(key::String)::Union{Vector{Float32},Nothing}
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        if haskey(cache_manager.indicators, key)
            entry = cache_manager.indicators[key]
            if Dates.now() - entry.last_updated ≤ cache_manager.max_age
                entry.last_accessed = Dates.now()
                return entry.data
            else
                delete!(cache_manager.indicators, key)
            end
        end
        return nothing
    end
end

"""
Get subtree data from cache
"""
function get_subtree_data(key::String)::Union{Vector{DayData},Nothing}
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        if haskey(cache_manager.subtree, key)
            entry = cache_manager.subtree[key]
            if Dates.now() - entry.last_updated ≤ cache_manager.max_age
                entry.last_accessed = Dates.now()
                return entry.data
            else
                delete!(cache_manager.subtree, key)
            end
        end
        return nothing
    end
end

"""
Cache price data
"""
function cache_price_data(symbol::String, data::DataFrame)
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        now = Dates.now()
        cache_manager.prices[symbol] = CacheEntry(data, now, now)
    end
end

"""
Cache indicator data
"""
function cache_indicator_data(key::String, data::Vector{Float32})
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        now = Dates.now()
        cache_manager.indicators[key] = CacheEntry(data, now, now)
    end
end

"""
Cache subtree data
"""
function cache_subtree_data(key::String, data::Vector{DayData})
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        now = Dates.now()
        cache_manager.subtree[key] = CacheEntry(data, now, now)
    end
end

"""
Clear old entries from cache
"""
function clear_old_cache_entries(age::Period=Hour(4))
    cache_manager = CACHE_MANAGER[]
    lock(cache_manager.cache_lock) do
        now = Dates.now()

        # Clear old price entries
        for (key, entry) in cache_manager.prices
            if now - entry.last_updated > cache_manager.max_age ||
                now - entry.last_accessed > age
                delete!(cache_manager.prices, key)
            end
        end

        # Clear old indicator entries
        for (key, entry) in cache_manager.indicators
            if now - entry.last_updated > cache_manager.max_age ||
                now - entry.last_accessed > age
                delete!(cache_manager.indicators, key)
            end
        end

        # Clear old subtree entries
        for (key, entry) in cache_manager.subtree
            if now - entry.last_updated > cache_manager.max_age ||
                now - entry.last_accessed > age
                delete!(cache_manager.subtree, key)
            end
        end
    end
end

"""
Cleanup cache (for shutdown)
"""
function cleanup_cache()
    if isdefined(CACHE_MANAGER, :x)
        lock(CACHE_MANAGER[].cache_lock) do
            empty!(CACHE_MANAGER[].prices)
            empty!(CACHE_MANAGER[].indicators)
            empty!(CACHE_MANAGER[].subtree)
        end
    end
end

end
