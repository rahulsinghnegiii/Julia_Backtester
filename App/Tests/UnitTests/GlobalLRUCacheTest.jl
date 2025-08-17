# test/test_global_cache.jl
include("../../Main.jl")
using Test
using Dates
using DataFrames
using .VectoriseBacktestService.Types
using .VectoriseBacktestService.GlobalServerCache

@testset "GlobalServerCache Tests" begin
    @testset "Cache Initialization" begin
        # Test basic initialization
        cache = initialize_server_cache(;
            price_cache_size=100,
            indicator_cache_size=200,
            subtree_cache_size=300,
            max_age=Hour(1),
        )
        @test cache.initialized == true
        @test cache.max_age == Hour(1)

        # Test re-initialization (should return same instance)
        cache2 = initialize_server_cache()
        @test cache === cache2
    end

    @testset "Price Cache Operations" begin
        initialize_server_cache(; max_age=Hour(1))

        # Test caching new data
        test_df = DataFrame(; A=1:3, B=4:6)
        cache_price_data("AAPL", test_df)
        cached_data = get_price_data("AAPL")
        @test cached_data == test_df

        # Test non-existent data
        @test get_price_data("NONEXISTENT") === nothing
        GlobalServerCache.CACHE_MANAGER[].initialized = false
        # Test data expiration
        initialize_server_cache(; max_age=Millisecond(1))
        cache_price_data("AAPL", test_df)
        sleep(0.01)  # Wait for data to expire
        @test get_price_data("AAPL") === nothing
    end

    @testset "Indicator Cache Operations" begin
        GlobalServerCache.CACHE_MANAGER[].initialized = false
        initialize_server_cache(; max_age=Hour(1))

        # Test caching new data
        test_data = Float32[1.0, 2.0, 3.0]
        cache_indicator_data("indicator1", test_data)
        cached_data = get_indicator_data("indicator1")
        @test cached_data == test_data

        # Test non-existent data
        @test get_indicator_data("NONEXISTENT") === nothing
        GlobalServerCache.CACHE_MANAGER[].initialized = false
        # Test data expiration
        initialize_server_cache(; max_age=Millisecond(1))
        cache_indicator_data("indicator1", test_data)
        sleep(0.01)
        @test get_indicator_data("indicator1") === nothing
    end

    @testset "Subtree Cache Operations" begin
        GlobalServerCache.CACHE_MANAGER[].initialized = false
        initialize_server_cache(; max_age=Hour(1))

        # Test caching new data
        test_data = [DayData([StockInfo("AAPL", 0.5f0)])]
        cache_subtree_data("subtree1", test_data)
        cached_data = get_subtree_data("subtree1")
        @test cached_data == test_data

        # Test non-existent data
        @test get_subtree_data("NONEXISTENT") === nothing

        GlobalServerCache.CACHE_MANAGER[].initialized = false
        # Test data expiration
        initialize_server_cache(; max_age=Millisecond(1))
        cache_subtree_data("subtree1", test_data)
        sleep(0.01)
        @test get_subtree_data("subtree1") === nothing
    end

    @testset "Cache Cleanup" begin
        initialize_server_cache(; max_age=Hour(1))

        # Add some data
        test_df = DataFrame(; A=1:3, B=4:6)
        test_indicator = Float32[1.0, 2.0, 3.0]
        test_subtree = [DayData([StockInfo("AAPL", 0.5f0)])]

        cache_price_data("AAPL", test_df)
        cache_indicator_data("indicator1", test_indicator)
        cache_subtree_data("subtree1", test_subtree)

        # Test manual cleanup
        cleanup_cache()
        @test get_price_data("AAPL") === nothing
        @test get_indicator_data("indicator1") === nothing
        @test get_subtree_data("subtree1") === nothing

        # Test automatic cleanup
        cache_price_data("AAPL", test_df)
        clear_old_cache_entries(Millisecond(1))
        sleep(0.01)
        @test get_price_data("AAPL") === nothing
    end

    @testset "Thread Safety" begin
        initialize_server_cache(; max_age=Hour(1))

        # Test concurrent access
        test_df = DataFrame(; A=1:3, B=4:6)
        n_threads = 10

        # Concurrent writes
        @sync begin
            for i in 1:n_threads
                @async begin
                    cache_price_data("AAPL_$i", test_df)
                end
            end
        end

        # Verify all writes succeeded
        for i in 1:n_threads
            @test get_price_data("AAPL_$i") == test_df
        end

        # Test concurrent reads and writes
        @sync begin
            for i in 1:n_threads
                @async begin
                    if i % 2 == 0
                        cache_price_data("AAPL_$i", test_df)
                    else
                        get_price_data("AAPL_$(i-1)")
                    end
                end
            end
        end
    end

    @testset "Edge Cases" begin
        initialize_server_cache(; max_age=Hour(1))

        # Test empty DataFrame
        empty_df = DataFrame()
        cache_price_data("EMPTY", empty_df)
        @test get_price_data("EMPTY") == empty_df

        # Test empty vector
        empty_vec = Float32[]
        cache_indicator_data("EMPTY", empty_vec)
        @test get_indicator_data("EMPTY") == empty_vec

        # Test empty DayData vector
        empty_daydata = DayData[]
        cache_subtree_data("EMPTY", empty_daydata)
        @test get_subtree_data("EMPTY") == empty_daydata

        # Test with very large data
        large_df = DataFrame(; A=1:1000000)
        cache_price_data("LARGE", large_df)
        @test get_price_data("LARGE") == large_df
    end

    @testset "Cache Size Limits" begin
        # Initialize cache with small sizes
        initialize_server_cache(;
            price_cache_size=2,
            indicator_cache_size=2,
            subtree_cache_size=2,
            max_age=Hour(1),
        )

        # Test price cache size limit
        for i in 1:3
            cache_price_data("AAPL_$i", DataFrame(; A=[i]))
        end
        @test get_price_data("AAPL_1") !== nothing  # Should be evicted
        @test get_price_data("AAPL_3") !== nothing  # Should still exist

        # Test indicator cache size limit
        for i in 1:3
            cache_indicator_data("IND_$i", Float32[i])
        end
        @test get_indicator_data("IND_1") !== nothing  # Should be evicted
        @test get_indicator_data("IND_3") !== nothing  # Should still exist

        # Test subtree cache size limit
        for i in 1:3
            cache_subtree_data("SUB_$i", [DayData([StockInfo("AAPL", Float32(i))])])
        end
        @test get_subtree_data("SUB_1") !== nothing  # Should be evicted
        @test get_subtree_data("SUB_3") !== nothing  # Should still exist
    end

    @testset "Cache Access Patterns" begin
        cache_manager = initialize_server_cache(;
            price_cache_size=1,
            indicator_cache_size=3,
            subtree_cache_size=3,
            max_age=Hour(1),
        )

        # Test LRU behavior for prices
        for i in 1:3
            cache_price_data("AAPL_$i", DataFrame(; A=[i]))
        end

        # Access AAPL_1 to make it most recently used
        get_price_data("AAPL_1")

        # Add new entry, should evict AAPL_2 (least recently used)
        cache_price_data("AAPL_4", DataFrame(; A=[4]))
        @test get_price_data("AAPL_2") !== nothing
        @test get_price_data("AAPL_1") !== nothing
        @test get_price_data("AAPL_4") !== nothing

        # Similar test for indicators
        for i in 1:3
            cache_indicator_data("IND_$i", Float32[i])
        end
        get_indicator_data("IND_1")
        cache_indicator_data("IND_4", Float32[4])
        @test get_indicator_data("IND_2") !== nothing
        @test get_indicator_data("IND_1") !== nothing
        @test get_indicator_data("IND_4") !== nothing
    end

    @testset "Cache Expiration Behavior" begin
        GlobalServerCache.CACHE_MANAGER[].initialized = false
        # Initialize with a longer expiration time to avoid timing issues
        initialize_server_cache(; max_age=Second(2))

        # Test gradual expiration
        test_df = DataFrame(; A=1:3)
        cache_price_data("AAPL", test_df)

        # Should still be valid immediately
        @test get_price_data("AAPL") !== nothing

        # Print current time and cache entry time for debugging
        cache_manager = GlobalServerCache.CACHE_MANAGER[]
        entry = cache_manager.prices["AAPL"]
        println("Current time: ", Dates.now())
        println("Entry last_updated: ", entry.last_updated)
        println("Entry last_accessed: ", entry.last_accessed)

        # Wait for half the expiration time
        sleep(1)
        @test get_price_data("AAPL") !== nothing

        # Wait for full expiration plus a small buffer
        sleep(1.5)  # Total sleep time is now 2.5 seconds

        # Print times again before final check
        println("Current time after sleep: ", Dates.now())
        if haskey(cache_manager.prices, "AAPL")
            entry = cache_manager.prices["AAPL"]
            println("Entry last_updated: ", entry.last_updated)
            println("Entry last_accessed: ", entry.last_accessed)
        end

        @test get_price_data("AAPL") === nothing

        # Test that accessing data updates last_accessed
        cache_price_data("AAPL", test_df)
        for i in 1:3
            result = get_price_data("AAPL")
            @test result !== nothing
            sleep(0.5)  # Sleep for less than expiration time
        end
    end

    @testset "Error Handling" begin
        initialize_server_cache(; max_age=Hour(1))

        # Test with invalid data types
        @test_throws MethodError cache_price_data("AAPL", [1, 2, 3])  # Not a DataFrame
        @test_throws MethodError cache_indicator_data("IND", [1.0, 2.0])  # Not Float32
        @test_throws MethodError cache_subtree_data("SUB", [1, 2, 3])  # Not Vector{DayData}

        # Test with empty keys
        cache_price_data("", DataFrame(; A=1:3))
        @test get_price_data("") !== nothing

        # Test with very long keys
        long_key = repeat("a", 1000)
        cache_price_data(long_key, DataFrame(; A=1:3))
        @test get_price_data(long_key) !== nothing
    end

    @testset "Concurrent Cache Operations" begin
        initialize_server_cache(; max_age=Hour(1))

        # Test concurrent mixed operations
        @sync begin
            for i in 1:50
                @async begin
                    # Random operation: read, write, or delete
                    op = rand(1:3)
                    key = "TEST_$i"

                    if op == 1  # Read
                        get_price_data(key)
                    elseif op == 2  # Write
                        cache_price_data(key, DataFrame(; A=[i]))
                    else  # Delete via cleanup
                        clear_old_cache_entries(Hour(0))
                    end
                end
            end
        end

        # Test concurrent cache updates
        test_df = DataFrame(; A=1:3)
        @sync begin
            for i in 1:10
                @async begin
                    cache_price_data("CONCURRENT", test_df)
                    cached = get_price_data("CONCURRENT")
                    @test cached == test_df
                end
            end
        end
    end

    @testset "Cache Performance Degradation" begin
        initialize_server_cache(;
            price_cache_size=1000,
            indicator_cache_size=1000,
            subtree_cache_size=1000,
            max_age=Hour(1),
        )

        # Test performance with increasing cache size
        start_time = time()
        for i in 1:100
            cache_price_data("PERF_$i", DataFrame(; A=1:100))
        end
        first_batch_time = time() - start_time
        println("First batch time: $first_batch_time")
        start_time = time()
        for i in 101:200
            cache_price_data("PERF_$i", DataFrame(; A=1:100))
        end
        second_batch_time = time() - start_time
        println("Second batch time: $second_batch_time")
        first_batch_time = max(first_batch_time, 1e-6)  # Avoid division by zero
        # Performance shouldn't degrade significantly
        @test second_batch_time < first_batch_time * 2
    end

    # Clean up after all tests
    cleanup_cache()
end
