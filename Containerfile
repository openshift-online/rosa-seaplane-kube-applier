FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:ea524c060979cf725f7bca8e3cdd0ef2d99d07b780d734092bd0bde68900aa0f AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:09bb6f946265bd6689f424c68827fa3719b09bb161db15e20aa28c3773f94389
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
