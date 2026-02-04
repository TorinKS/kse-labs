# Use pre-built binary (built in CI pipeline)
FROM alpine:3.19

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy pre-built binary from build context
ARG BINARY_PATH=example-service
COPY ${BINARY_PATH} /app/server

RUN chmod +x /app/server

EXPOSE 8080

USER nobody

ENTRYPOINT ["/app/server"]
