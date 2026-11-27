FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:9c9ea263e72d671940017c68dd0a1d9032235d1cc3b4e3f66c40f88a2afada5d AS builder

USER root

WORKDIR /app
COPY go.mod go.sum ./
COPY seaplane-dynamo/go.mod ./seaplane-dynamo/go.mod
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /kube-applier-aws .

FROM registry.access.redhat.com/hi/go:latest-fips@sha256:cbeb139cbce889663602b3d450bdd87b2bb9c4b730a6441027c03ac67239fba9
COPY --from=builder /kube-applier-aws /kube-applier-aws
USER 65532:65532
ENTRYPOINT ["/kube-applier-aws"]
