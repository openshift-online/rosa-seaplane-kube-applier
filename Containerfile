FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:dc428f0d29b8f64bfbdaf5af58110a361deeb1ac23f074261931f012982b64c3 AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:043e6232a9a689a9c36b14ee7b8ec50e8bb5cd88a7e202d82497c5c0e71adedd
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
