FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:8b2ff041651f118890d61393ed362b9e6a9f36aaaa643b546dc5d7b992f6a354 AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:d47aa37c51118bc92bb537bbadb707ed948d3eb83893d3cbe18ec45408befd4d
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
