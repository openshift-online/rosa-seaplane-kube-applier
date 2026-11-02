FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:44b74e7349b73b68f30a17dcdc52842f14ff3fa1293827a408d8d051049ec08d AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:b793b36bc6129d842d28f051681deb7907aae8b9b40e894fcd62e0fb2c1eaad5
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
