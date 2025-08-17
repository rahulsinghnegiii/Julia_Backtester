include("RoutesTA.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, Genie.Router

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

PORT = 5005
up(PORT, "0.0.0.0"; async=false)
