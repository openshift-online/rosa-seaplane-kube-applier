FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:2944ca2126a611f87c3ff7a28d567bdd051cafb69a6a1f35e73c6f1f8bf72b9f AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:5d4d54bffb06c691f14316f524b8ea40202c38314b624ee9d37a7668468eaf60
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
