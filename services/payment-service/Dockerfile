# image being used is golang:1.26.3
FROM golang:1.26.3 AS build

WORKDIR /app

ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

COPY go.mod go.sum ./

RUN go mod download

COPY main.go ./

RUN go build -o payment-service .

FROM alpine:3.22.4

WORKDIR /app

COPY --from=build /app/payment-service ./

RUN adduser -D dockeruser

RUN chown -R dockeruser .

USER dockeruser

CMD ["./payment-service"]
