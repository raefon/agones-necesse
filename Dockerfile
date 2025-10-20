# syntax=docker/dockerfile:1

# Base runtime image
FROM alpine:3.20 AS base

LABEL maintainer="BrammyS <https://github.com/raefon>"
LABEL org.label-schema.name="raefon/necesse-server"
LABEL org.label-schema.description="A Docker image for a dedicated Necesse game server."
LABEL org.label-schema.vendor="raefon"
LABEL org.label-schema.url="https://github.com/raefon/agones-necesse"
LABEL org.label-schema.docker.cmd="docker run -d -v /necesse/saves:/necesse/saves -p 14159:14159/udp -e PASSWORD=strong_pass -e PAUSE=1 --restart=always --name necesse-server raefon/necesse-server"

# Expose UDP port and mount points
EXPOSE 14159/udp
VOLUME ["/necesse/logs", "/necesse/saves"]

# Server configs (consider not baking sensitive defaults)
ENV WORLD=world \
    SLOTS=10 \
    OWNER="" \
    MOTD="This server is made possible by Docker!" \
    PASSWORD="" \
    PAUSE=0 \
    GIVE_CLIENTS_POWER=1 \
    LOGGING=1 \
    ZIP=1 \
    JVMARGS=""

# Runtime deps: JRE and certs
RUN apk add --no-cache \
    openjdk17-jre-headless \
    ca-certificates \
    tzdata \
    bash \
  && update-ca-certificates

# Builder stage for Go wrapper and fetching Necesse server
FROM golang:1.22-alpine AS build

ARG version
ARG build
ARG url

WORKDIR /work

# Tools needed to fetch and extract, and to resolve Go modules
RUN apk add --no-cache ca-certificates wget unzip git \
  && update-ca-certificates

# Fail early if URL is missing
RUN test -n "$url" || (echo "Build arg 'url' is empty" && exit 1)

# Download Necesse server and extract to a known path
RUN wget -O necesse-server-linux64-${version}-${build}.zip "$url"
RUN mkdir -p /work/necesse && unzip -q necesse-server-linux64-${version}-${build}.zip -d /work/necesse

# Remove any bundled JRE to use the system JRE in the final image
RUN find /work/necesse -type d -name jre -prune -exec rm -rf {} +

# Build the Go wrapper
# Copy only go.mod first to leverage Docker layer caching
COPY go.mod ./
# Download direct module requirements (cacheable)
RUN go mod download
# Now copy sources that affect dependency graph and build
COPY main.go ./
# Ensure go.mod/go.sum include all transitive deps used by main.go (e.g. cloud.google.com/go)
RUN go mod tidy
# Build static-ish binary
RUN CGO_ENABLED=0 GOOS=linux go build -o /work/wrapper ./main.go

# Final image: copy server files and wrapper into runtime
FROM base AS final

# If you need build args here for labeling or paths, redeclare:
ARG version
ARG build

# Move server files and wrapper
COPY --from=build /work/necesse /necesse
COPY necesseserver.sh /necesse/necesseserver.sh
COPY --from=build /work/wrapper /usr/local/bin/wrapper

# Chmod execute to necesseserver.sh
RUN chmod +x /necesse/necesseserver.sh

WORKDIR /necesse

# Run the server via the wrapper; point to the script within /necesse
ENTRYPOINT ["/usr/local/bin/wrapper", "-i", "/necesse/necesseserver.sh"]
