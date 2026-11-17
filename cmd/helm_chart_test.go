//go:build helmtest

package cmd

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"k8s.io/apimachinery/pkg/util/yaml"
	sigsyaml "sigs.k8s.io/yaml"
)

func repoRoot(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs("..")
	if err != nil {
		t.Fatal(err)
	}
	return root
}

func readYAMLDocument(t *testing.T, path string) map[string]interface{} {
	t.Helper()
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var document map[string]interface{}
	if err := sigsyaml.Unmarshal(content, &document); err != nil {
		t.Fatal(err)
	}
	return document
}

func nestedMap(t *testing.T, object map[string]interface{}, key string) map[string]interface{} {
	t.Helper()
	value, ok := object[key].(map[string]interface{})
	if !ok {
		t.Fatalf("%s is not a mapping: %#v", key, object[key])
	}
	return value
}

func TestChartPipelineRunTaskRunTemplatePlacement(t *testing.T) {
	for _, name := range []string{
		"rosa-seaplane-kube-applier-chart-pull-request.yaml",
		"rosa-seaplane-kube-applier-chart-push.yaml",
	} {
		t.Run(name, func(t *testing.T) {
			document := readYAMLDocument(t, filepath.Join(repoRoot(t), ".tekton", name))
			spec := nestedMap(t, document, "spec")
			taskRunTemplate := nestedMap(t, spec, "taskRunTemplate")
			if got := taskRunTemplate["serviceAccountName"]; got != "build-pipeline-rosa-seaplane-kube-applier" {
				t.Fatalf("unexpected taskRunTemplate serviceAccountName: %#v", got)
			}
			pipelineSpec := nestedMap(t, spec, "pipelineSpec")
			if _, found := pipelineSpec["taskRunTemplate"]; found {
				t.Fatal("pipelineSpec must not contain taskRunTemplate")
			}
			if _, found := pipelineSpec["workspaces"]; !found {
				t.Fatal("PipelineSpec workspaces declaration was moved")
			}
			if _, found := spec["workspaces"]; !found {
				t.Fatal("PipelineRun workspace binding is missing")
			}
		})
	}
}

func helmBinary() string {
	if binary := os.Getenv("HELM"); binary != "" {
		return binary
	}
	return "helm"
}

func renderChart(t *testing.T, overrides ...string) (map[string]string, []string) {
	t.Helper()
	root := repoRoot(t)
	args := []string{"template", "kube-applier", "charts/kube-applier", "--namespace", "kube-applier"}
	for _, override := range overrides {
		args = append(args, "--set-string", override)
	}
	command := exec.Command(helmBinary(), args...)
	command.Dir = root
	output, err := command.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			t.Fatalf("helm template failed: %v\n%s", err, exitError.Stderr)
		}
		t.Fatal(err)
	}

	decoder := yaml.NewYAMLOrJSONDecoder(strings.NewReader(string(output)), 4096)
	for {
		var document map[string]interface{}
		if err := decoder.Decode(&document); err != nil {
			if err == io.EOF {
				break
			}
			t.Fatal(err)
		}
		if document["kind"] != "Deployment" {
			continue
		}
		spec := nestedMap(t, document, "spec")
		podTemplate := nestedMap(t, spec, "template")
		podSpec := nestedMap(t, podTemplate, "spec")
		containers, ok := podSpec["containers"].([]interface{})
		if !ok || len(containers) != 1 {
			t.Fatalf("expected one Deployment container, got %#v", podSpec["containers"])
		}
		container := containers[0].(map[string]interface{})
		args, ok := container["args"].([]interface{})
		if !ok {
			t.Fatalf("container args are not a list: %#v", container["args"])
		}
		parsedArgs := make([]string, 0, len(args))
		for _, arg := range args {
			parsedArgs = append(parsedArgs, fmt.Sprint(arg))
		}
		ports, ok := container["ports"].([]interface{})
		if !ok {
			t.Fatalf("container ports are not a list: %#v", container["ports"])
		}
		containerPorts := make(map[string]string, len(ports))
		for _, value := range ports {
			port := value.(map[string]interface{})
			containerPorts[fmt.Sprint(port["name"])] = fmt.Sprint(port["containerPort"])
		}
		return containerPorts, parsedArgs
	}
	t.Fatal("rendered chart has no Deployment")
	return nil, nil
}

func parseApplicationArgs(t *testing.T, args []string) {
	t.Helper()
	command := NewCmdRoot()
	if err := command.ParseFlags(args); err != nil {
		t.Fatalf("rendered chart args are not accepted by the application command: %v\nargs: %v", err, args)
	}
}

func hasArgPrefix(args []string, prefix string) bool {
	for _, arg := range args {
		if strings.HasPrefix(arg, prefix) {
			return true
		}
	}
	return false
}

func TestRenderedChartArgumentsMatchApplicationFlags(t *testing.T) {
	_, defaultArgs := renderChart(t)
	parseApplicationArgs(t, defaultArgs)
	for _, name := range []string{"--dynamo-poll-interval=", "--dynamo-relist-interval=", "--dynamo-max-lookback="} {
		if hasArgPrefix(defaultArgs, name) {
			t.Errorf("empty optional value unexpectedly rendered %s", name)
		}
	}

	_, configuredArgs := renderChart(t,
		"kubeApplier.config.dynamoPollInterval=15s",
		"kubeApplier.config.dynamoRelistInterval=5m",
		"kubeApplier.config.dynamoLookbackMax=2m",
	)
	parseApplicationArgs(t, configuredArgs)
	if !hasArgPrefix(configuredArgs, "--dynamo-max-lookback=2m") {
		t.Fatalf("configured lookback did not render the registered flag: %v", configuredArgs)
	}
	if hasArgPrefix(configuredArgs, "--dynamo-lookback-max=") || hasArgPrefix(configuredArgs, "--informer-resync-period=") {
		t.Fatalf("chart rendered an unsupported flag: %v", configuredArgs)
	}
}

func TestListenAddressPorts(t *testing.T) {
	cases := []struct {
		name    string
		address string
		port    int
	}{
		{name: "colon only", address: ":8081", port: 8081},
		{name: "IPv4", address: "127.0.0.1:9091", port: 9091},
		{name: "hostname", address: "localhost:9092", port: 9092},
		{name: "IPv6 loopback", address: "[::1]:9093", port: 9093},
		{name: "IPv6 address", address: "[2001:db8::1]:9094", port: 9094},
		{name: "IPv6 zone", address: "[fe80::1%eth0]:9095", port: 9095},
		{name: "leading zero", address: ":01234", port: 1234},
		{name: "leading zero with eight and nine", address: ":08081", port: 8081},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			ports, args := renderChart(t,
				"kubeApplier.config.metricsListenAddress="+test.address,
				"kubeApplier.config.healthzListenAddress="+test.address,
			)
			parseApplicationArgs(t, args)
			for _, name := range []string{"metrics", "healthz"} {
				got, err := strconv.Atoi(ports[name])
				if err != nil {
					t.Fatalf("%s container port is not an integer: %q", name, ports[name])
				}
				if got != test.port {
					t.Errorf("%s container port = %d, want %d", name, got, test.port)
				}
			}
		})
	}
}

func TestInvalidListenAddressFailsChartRendering(t *testing.T) {
	for _, field := range []string{"metricsListenAddress", "healthzListenAddress"} {
		for _, address := range []string{"", "localhost", ":0", ":00000", ":65536", ":99999", ":123456", "127.0.0.1:abc", "::1:8081", "[::1]8081", "[not-ipv6]:8081"} {
			t.Run(field+"/"+address, func(t *testing.T) {
				root := repoRoot(t)
				command := exec.Command(helmBinary(), "template", "kube-applier", "charts/kube-applier", "--set-string", "kubeApplier.config."+field+"="+address)
				command.Dir = root
				if output, err := command.CombinedOutput(); err == nil {
					t.Fatalf("helm template accepted invalid %s %q:\n%s", field, address, output)
				}
			})
		}
	}
}
