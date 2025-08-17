FROM julia:latest

WORKDIR /app

ARG LIVE_DATA_API_URL
ARG LIVE_DATA_API_USERNAME
ARG LIVE_DATA_API_SECRET

ENV LIVE_DATA_API_URL=$LIVE_DATA_API_URL
ENV LIVE_DATA_API_USERNAME=$LIVE_DATA_API_USERNAME
ENV LIVE_DATA_API_SECRET=$LIVE_DATA_API_SECRET

# Copy only necessary files
COPY LaunchServer.sh .
COPY . .

# Install dependencies
RUN julia -e 'using Pkg; \
    Pkg.add(Pkg.PackageSpec(name="BenchmarkTools", version="1.5.0")); \
    Pkg.add(Pkg.PackageSpec(name="DataFrames", version="1.6.1")); \
    Pkg.add(Pkg.PackageSpec(name="DuckDB", version="1.0.0")); \
    Pkg.add(Pkg.PackageSpec(name="Glob", version="v1.3.1")); \
    Pkg.add(Pkg.PackageSpec(name="HTTP", version="1.10.8")); \
    Pkg.add(Pkg.PackageSpec(name="JSON", version="0.21.4")); \
    Pkg.add(Pkg.PackageSpec(name="MarketTechnicals", version="0.6.0")); \
    Pkg.add(Pkg.PackageSpec(name="Parquet", version="0.8.4")); \
    Pkg.add(Pkg.PackageSpec(name="SIMD", version="3.5.0")); \
    Pkg.add(Pkg.PackageSpec(name="TimeSeries", version="0.21.0")); \
    Pkg.add(Pkg.PackageSpec(name="TimeZones", version="1.17.0")); \
    Pkg.add(Pkg.PackageSpec(name="MsgPack", version="1.2.1")); \
    Pkg.add("Parquet2"); \
    Pkg.add("JSON3"); \
    Pkg.add("Dates"); \
    Pkg.add("Profile"); \
    Pkg.add("Oxygen"); \
    Pkg.add("Statistics"); \
    Pkg.add("Test"); \
    Pkg.add("LRUCache"); \
    Pkg.add("DotEnv"); \
    Pkg.add("Blobs"); \
    Pkg.add("MbedTLS"); \
    Pkg.precompile()'

EXPOSE 5004

# Make the startup script executable and ensure it has Unix-style line endings
RUN chmod +x /app/LaunchServer.sh && \
    sed -i 's/\r$//' /app/LaunchServer.sh

# Use the startup script as the entry point
CMD ["/app/LaunchServer.sh"]
