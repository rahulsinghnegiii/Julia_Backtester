module ErrorHandlers

export ServerError,
    ValidationError,
    ProcessingError,
    DataError,
    handle_conditon_eval_error,
    handle_condition_node_error,
    handle_sort_node_error,
    create_error_response,
    BacktestError,
    BacktestExecutionError,
    CacheError,
    PortfolioUpdateError,
    SelectionError,
    BranchProcessingError,
    StockNodeError,
    StockProcessingError,
    ConditionNodeError,
    LockOnTriggerError,
    ConditionEvalError,
    AllocationError,
    AllocationNodeError,
    WeightCalculationError

# Base error type
abstract type BacktestError <: Exception end

# Specific error types
struct ServerError <: BacktestError
    status::Int
    message::String
    details::Any
    function ServerError(status::Int, message::String, details=nothing)
        return new(status, message, details)
    end
end

### Custom Error Types for AllocationNode
struct AllocationNodeError <: BacktestError
    message::String
    function_type::String
    details::Dict{String,Any}
end

struct WeightCalculationError <: BacktestError
    message::String
    calculation_type::String
    details::Dict{String,Any}
end

### Custom Error Types for ConditionNode
struct ConditionNodeError <: BacktestError
    message::String
    node_id::String
    details::Dict{String,Any}
end

struct ConditionEvalError <: BacktestError
    message::String
    condition_type::String
    details::Dict{String,Any}
end

struct AllocationError <: BacktestError
    message::String
    node_type::String
    details::Dict{String,Any}
end

# Custom error types for StockNode
struct StockNodeError <: BacktestError
    message::String
    details::Any
end

struct LockOnTriggerError <: BacktestError
    message::String
    details::Any
end

struct StockProcessingError <: BacktestError
    message::String
    details::Any
end

struct ValidationError <: BacktestError
    message::String
    details::Any
    ValidationError(message::String, details=nothing) = new(message, details)
end

struct ProcessingError <: BacktestError
    message::String
    details::Any
    ProcessingError(message::String, details=nothing) = new(message, details)
end

struct DataError <: BacktestError
    message::String
    details::Any
    DataError(message::String, details=nothing) = new(message, details)
end

struct BacktestExecutionError <: BacktestError
    message::String
    details::Any
    BacktestExecutionError(message::String, details=nothing) = new(message, details)
end

struct CacheError <: BacktestError
    message::String
    details::Any
    CacheError(message::String, details=nothing) = new(message, details)
end

struct PortfolioUpdateError <: BacktestError
    message::String
    details::Any
    PortfolioUpdateError(message::String, details=nothing) = new(message, details)
end

struct SelectionError <: BacktestError
    message::String
    details::Any
    SelectionError(message::String, details=nothing) = new(message, details)
end

struct BranchProcessingError <: BacktestError
    message::String
    details::Any
    BranchProcessingError(message::String, details=nothing) = new(message, details)
end

# Enhanced error handlers
function handle_conditon_eval_error(e::Exception)
    if isa(e, ArgumentError)
        throw(ValidationError("Invalid condition evaluation", e))
    elseif isa(e, BacktestError)
        rethrow(e)
    else
        throw(ProcessingError("Failed to evaluate condition", e))
    end
end

function handle_condition_node_error(e::Exception)
    if isa(e, BacktestError)
        rethrow(e)
    else
        throw(ProcessingError("Failed to process condition node", e))
    end
end

function handle_sort_node_error(e::Exception)::Nothing
    if isa(e, BacktestError)
        rethrow(e)
    else
        throw(ProcessingError("Failed to process sort node", e))
    end
end

end
