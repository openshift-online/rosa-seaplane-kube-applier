FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:9c8fb40ab55e721ddc35370e3c5d37969f5a65290973263e7874eecb62482834 AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:04e15ddcf64b1d72d618d7ab3f02a8ff90bd1607ba500b7e31fcaa007bbcec07
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
