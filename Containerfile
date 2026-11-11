FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:e424db07a04673ec9c732981d3d97e96044cce39215f5c528d4f549e45eb1c2c AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:275df00eba7680ddee0a3701af59af981a4c9a6fad41a84e0bc371c778ed21e8
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
