FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:0374b76ef9a21619360dd9920540e912c64a33980a472962017f532c8f19b56d AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:900dcc80cc2d493c9de3d5a97c347fd78cf26ca1b92a9e556d253409584869ae
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
