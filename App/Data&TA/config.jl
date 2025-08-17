module Config
export API_KEY, API_SECRET, FINNHUB_API, FMP_API, EOD_API, FMP_LIST

const API_KEY::String = "PK4FS9DQ65WPGH8OMROX"
const API_SECRET::String = "jxWDzgPXYnebm6PLguBQgtti4pnXuZZ3y8iN91md"
const FINNHUB_API::String = "cmpciu1r01qg7bbo3mfgcmpciu1r01qg7bbo3mg0"
const FMP_API::String = "9R5cpvGC8GJ2mLtUrgmYj5z9E4QPTK1o"
const EOD_API::String = "65f4606264b710.50890662"
const FMP_LIST::Vector{String} = ["GBTC"]
end
