FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:64782b57247b11c07377043520135e12eb6ddbed3b2d33b1223e7a3c880f8bd4 AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:a462174f0bd7a1be81ccbeadf91b584a2cdacc8df790c9d2c9b970e0684eb792
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
