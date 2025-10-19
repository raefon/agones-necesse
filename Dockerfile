# Setup base image
FROM alpine:3 AS base

LABEL maintainer="BrammyS <https://github.com/raefon>"
LABEL org.label-schema.name="raefon/necesse-server"
LABEL org.label-schema.description="A Docker image for a dedicated Necesse game server."
LABEL org.label-schema.vendor="raefon"
LABEL org.label-schema.url="https://github.com/raefon/agones-necesse"
LABEL org.label-schema.docker.cmd="docker run -d -v /necesse/saves:/necesse/saves -p 14159:14159/udp -e PASSWORD=strong_pass -e PAUSE=1 --restart=always --name necesse-server raefon/necesse-server"

# Misc configurations.
ARG version
ARG build
ARG url
EXPOSE 14159/udp
VOLUME  [                       \
    "/necesse/logs",            \
    "/necesse/saves"            \
]

# Server configs.
ENV WORLD=world
ENV SLOTS=10
ENV OWNER=""
ENV MOTD="This server is made possible by Docker!"
ENV PASSWORD=""
ENV PAUSE=0
ENV GIVE_CLIENTS_POWER=1
ENV LOGGING=1
ENV ZIP=1
ENV JVMARGS=""

# Install java, wget and unzip and cleanup package cache.
RUN apk --update add wget unzip 
RUN apk add openjdk17
RUN rm -rf /var/cache/apk/*

# Setup build image
FROM base AS build

# Install necesse server files.
RUN wget ${url}
RUN unzip necesse-server-linux64-${version}-${build}.zip
RUN rm -rf ${dir}/jre

COPY main.go go.mod ./
RUN go mod download agones.dev/agones && \
    go mod tidy && \
    go build -o wrapper

# Setup final image
FROM base AS final

# Move server files to generic necesse folder.
COPY --from=build /necesse-server-${version}-${build} /necesse/

COPY --from=build /wrapper /usr/local/bin/wrapper

WORKDIR /necesse

ENTRYPOINT ["/usr/local/bin/wrapper", "-i", "/usr/local/bin/necesse.sh"]
CMD ["-args", "-world ${WORLD} -slots ${SLOTS} -owner ${OWNER} -motd ${MOTD} -password ${PASSWORD} -pausewhenempty ${PAUSE} -giveclientspower ${GIVE_CLIENTS_POWER} -logging ${LOGGING} -zipsaves ${ZIP}"]