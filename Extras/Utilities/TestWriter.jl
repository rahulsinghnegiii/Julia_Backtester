arr = [
    "cumulativereturn_DBC_100_2024-10-01",
    "cumulativereturn_DBC_200_2024-10-01",
    "cumulativereturn_DBC_300_2024-10-01",
    "cumulativereturn_DBC_400_2024-10-01",
    "cumulativereturn_DBC_500_2024-10-01",
    "cumulativereturn_DBC_600_2024-10-01",
    "cumulativereturn_SPY_100_2024-10-01",
    "cumulativereturn_SPY_200_2024-10-01",
    "cumulativereturn_SPY_300_2024-10-01",
    "cumulativereturn_SPY_400_2024-10-01",
    "cumulativereturn_SPY_500_2024-10-01",
    "cumulativereturn_SPY_600_2024-10-01",
    "rsi_BIL_10_2024-10-01",
    "rsi_BIL_15_2024-10-01",
    "rsi_BIL_20_2024-10-01",
    "rsi_BIL_5_2024-10-01",
    "rsi_IEF_10_2024-10-01",
    "rsi_IEF_15_2024-10-01",
    "rsi_IEF_200_2024-10-01",
    "rsi_IEF_20_2024-10-01",
    "rsi_IEF_5_2024-10-01",
    "rsi_QQQ_10_2024-10-01",
    "rsi_QQQ_20_2024-10-01",
    "rsi_QQQ_30_2024-10-01",
    "rsi_SHY_8_2024-10-01",
    "rsi_SMH_10_2024-10-01",
    "rsi_SMH_20_2024-10-01",
    "rsi_SMH_30_2024-10-01",
    "rsi_SOXL_10_2024-10-01",
    "rsi_SOXL_5_2024-10-01",
    "rsi_SPHB_8_2024-10-01",
    "rsi_SPXL_10_2024-10-01",
    "rsi_SPXL_5_2024-10-01",
    "rsi_SPY_5_2024-10-01",
    "rsi_TLT_200_2024-10-01",
    "rsi_TQQQ_10_2024-10-01",
    "rsi_VIXM_10_2024-10-01",
]

function generate_compare_file(
    arr::Vector{String}, template_paths::Tuple{String,String}, output_file::String
)
    open(output_file, "w") do io
        for replacement in arr
            # Replace "param" with the replacement string in both paths
            modified_paths = map(x -> replace(x, "param" => replacement), template_paths)

            # Write the compare_two_files function call to the file
            println(io, "compare_two_files(")
            println(io, "    \"$(modified_paths[1])\",")
            println(io, "    \"$(modified_paths[2])\",")
            println(io, ")")
            println(io)  # Add an empty line for readability
        end
    end
end

template_paths = (
    "./IndicatorData/param", "./Tests/E2E/LargeExpectedResponse/IndicatorData/param"
)
output_file = "./compare_paths.txt"

generate_compare_file(arr, template_paths, output_file)
