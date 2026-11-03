FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:9b159a6371ac623f7a9170459efd2a3d96ab34ca37c3fcf215043865e1a40d0c AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:071fc6c7b99f743b61f10f837bb72c9c1c1528193e0665e923b194c4a75535af
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
