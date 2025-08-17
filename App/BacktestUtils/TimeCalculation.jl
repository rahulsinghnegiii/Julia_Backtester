module TimeCalculation
export @maybe_time

HC_DEBUG_MODE = true
macro maybe_time(expr)
    if HC_DEBUG_MODE
        return esc(expr) # ironically we disable timing for debugging mode.
    else
        return :(@time $(esc(expr)))
    end
end

end
