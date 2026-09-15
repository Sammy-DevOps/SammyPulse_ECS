# Build Gatus
FROM golang:alpine AS builder

WORKDIR /app

COPY . .

RUN go mod tidy -diff
RUN CGO_ENABLED=0 GOOS=linux go build -o gatus .


# Run Gatus
FROM alpine:latest

RUN apk add --no-cache ca-certificates

RUN addgroup -S gatus && adduser -S gatus -G gatus

WORKDIR /app

COPY --from=builder /app/gatus ./gatus
COPY --from=builder /app/config.yaml ./config.yaml

ENV GATUS_CONFIG_PATH=/app/config.yaml
ENV PORT=8080

EXPOSE 8080

USER gatus

ENTRYPOINT ["./gatus"]
