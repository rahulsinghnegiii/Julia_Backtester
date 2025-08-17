using SIMD
using Test
using BenchmarkTools

function compare_greater!(xs::Vector{Float32}, ys::Vector{Float32}, op::Symbol)
    len::Int = min(length(xs), length(ys))
    if (length(xs) != length(ys))
        if (length(xs) > length(ys))
            xs = xs[1:len]
        else
            ys = ys[1:len]
        end
    end
    N = 256
    quotient, remainder = divrem(len, N)
    lane = VecRange{N}(0)
    result = Vector{Bool}(undef, len)
    if (remainder == 0)
        @inbounds for i in 1:N:length(xs)
            if op == :>
                result[lane + i] = @fastmath (xs[lane + i] > ys[lane + i])
            elseif op == :>=
                result[lane + i] = @fastmath (xs[lane + i] >= ys[lane + i])
            else
                error("Unsupported operation: $op")
            end
        end
    else
        @inbounds for i in 1:N:(quotient * N)
            if op == :>
                result[lane + i] = @fastmath (xs[lane + i] > ys[lane + i])
            elseif op == :>=
                result[lane + i] = @fastmath (xs[lane + i] >= ys[lane + i])
            else
                error("Unsupported operation: $op")
            end
        end
        lane = VecRange{remainder}(0)
        @inbounds for i in (quotient * N + 1):remainder:len
            if op == :>
                result[lane + i] = @fastmath (xs[lane + i] > ys[lane + i])
            elseif op == :>=
                result[lane + i] = @fastmath (xs[lane + i] >= ys[lane + i])
            else
                error("Unsupported operation: $op")
            end
        end
    end
    return BitVector(result)
end

function compare_lower!(xs::Vector{Float32}, ys::Vector{Float32}, op::Symbol)
    len::Int = min(length(xs), length(ys))
    if (length(xs) != length(ys))
        if (length(xs) > length(ys))
            xs = xs[1:len]
        else
            ys = ys[1:len]
        end
    end
    N = 256
    quotient, remainder = divrem(len, N)
    lane = VecRange{N}(0)
    result = Vector{Bool}(undef, len)
    if (remainder == 0)
        @inbounds for i in 1:N:length(xs)
            if op == :<
                result[lane + i] = @fastmath (xs[lane + i] < ys[lane + i])
            elseif op == :<=
                result[lane + i] = @fastmath (xs[lane + i] <= ys[lane + i])
            else
                error("Unsupported operation: $op")
            end
        end
    else
        @inbounds for i in 1:N:(quotient * N)
            if op == :<
                result[lane + i] = @fastmath (xs[lane + i] < ys[lane + i])
            elseif op == :<=
                result[lane + i] = @fastmath (xs[lane + i] <= ys[lane + i])
            else
                error("Unsupported operation: $op")
            end
        end
        lane = VecRange{remainder}(0)
        @inbounds for i in (quotient * N + 1):remainder:len
            if op == :<
                result[lane + i] = @fastmath (xs[lane + i] < ys[lane + i])
            elseif op == :<=
                result[lane + i] = @fastmath (xs[lane + i] <= ys[lane + i])
            else
                error("Unsupported operation: $op")
            end
        end
    end
    return BitVector(result)
end
