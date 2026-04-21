FROM golang:1.25-alpine AS builder

WORKDIR /app

ENV GOPROXY=https://goproxy.cn,direct
ENV GOSUMDB=sum.golang.google.cn

COPY go.mod ./
RUN go mod download

COPY . ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/token-service ./cmd/server

FROM alpine:3.22

WORKDIR /app
COPY --from=builder /out/token-service /usr/local/bin/token-service

EXPOSE 8091

ENTRYPOINT ["/usr/local/bin/token-service"]
