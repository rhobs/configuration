package main

import (
	"fmt"
	"os"

	"github.com/go-kit/log"
	"github.com/magefile/mage/mg"
	"github.com/philipgough/mimic"
)

type (
	Stage      mg.Namespace
	Production mg.Namespace
	Local      mg.Namespace
	Build      mg.Namespace
)

const (
	templatePath         = "resources"
	templateServicesPath = "services"
	templateClustersPath = "clusters"
)

// Available build steps
const (
	StepCRDS            = "crds"
	StepOperator        = "operator"
	StepThanos          = "thanos"
	StepServiceMonitors = "servicemonitors"
	StepAlertmanager    = "alertmanager"
	StepSecrets         = "secrets"
	StepGateway         = "gateway"
)

// BuildStepFunctions maps build step names to their implementation functions
var BuildStepFunctions = map[string]func(Build, ClusterConfig) error{
	StepCRDS: func(b Build, cfg ClusterConfig) error {
		return b.CRDS(cfg)
	},
	StepOperator: func(b Build, cfg ClusterConfig) error {
		b.Operator(cfg)
		return nil
	},
	StepThanos: func(b Build, cfg ClusterConfig) error {
		b.DefaultThanos(cfg)
		return nil
	},
	StepServiceMonitors: func(b Build, cfg ClusterConfig) error {
		b.ServiceMonitors(cfg)
		return nil
	},
	StepAlertmanager: func(b Build, cfg ClusterConfig) error {
		b.Alertmanager(cfg)
		return nil
	},
	StepSecrets: func(b Build, cfg ClusterConfig) error {
		b.Secrets(cfg)
		return nil
	},
	StepGateway: func(b Build, cfg ClusterConfig) error {
		err := b.Gateway(cfg)
		if err != nil {
			return err
		}
		return nil
	},
}

// ExecuteSteps executes a list of build steps for a cluster
func (b Build) ExecuteSteps(steps []string, cfg ClusterConfig) error {
	for _, step := range steps {
		if fn, exists := BuildStepFunctions[step]; exists {
			if err := fn(b, cfg); err != nil {
				return fmt.Errorf("build step '%s' failed for cluster %s: %w", step, cfg.Name, err)
			}
		} else {
			return fmt.Errorf("unknown build step '%s' for cluster %s", step, cfg.Name)
		}
	}
	return nil
}

func (b Build) Clusters() error {
	clusters := GetClusters()
	if len(clusters) == 0 {
		return fmt.Errorf("no clusters registered")
	}

	for _, cfg := range clusters {
		if err := b.ExecuteSteps(cfg.BuildSteps, cfg); err != nil {
			return err
		}
	}
	return nil
}

// BuildCluster builds manifests for a specific cluster by name
func (b Build) Cluster(clusterName string) error {
	cluster, err := GetClusterByName(ClusterName(clusterName))
	if err != nil {
		return err
	}

	return b.ExecuteSteps(cluster.BuildSteps, *cluster)
}

// BuildEnvironment builds manifests for all clusters in a specific environment
func (b Build) Environment(environment string) error {
	env := ClusterEnvironment(environment)
	if !env.IsValid() {
		return fmt.Errorf("invalid environment: %s", environment)
	}

	clusters := GetClustersByEnvironment(env)
	if len(clusters) == 0 {
		return fmt.Errorf("no clusters found for environment: %s", environment)
	}

	for _, cfg := range clusters {
		if err := b.ExecuteSteps(cfg.BuildSteps, cfg); err != nil {
			return err
		}
	}
	return nil
}

// ListAvailableSteps lists all available build steps
func (b Build) List() {
	fmt.Println("Available build steps:")
	for step := range BuildStepFunctions {
		fmt.Printf("  - %s\n", step)
	}
}

// ListClusterSteps shows the build steps for each registered cluster
func (b Build) ListClusters() {
	clusters := GetClusters()
	if len(clusters) == 0 {
		fmt.Println("No clusters registered")
		return
	}

	for _, cluster := range clusters {
		fmt.Printf("Cluster: %s (%s)\n", cluster.Name, cluster.Environment)
		fmt.Printf("  Steps: %v\n", cluster.BuildSteps)
		fmt.Println()
	}
}

// Build Builds the manifests for the stage environment.
func (Stage) Build() {
	mg.SerialDeps(Stage.Alertmanager, Stage.CRDS, Stage.Operator, Stage.Thanos, Stage.TelemeterRules, Stage.ServiceMonitors, Stage.Secrets)
}

// Build Builds the manifests for a local environment.
func (Local) Build() {
	mg.SerialDeps(Local.CRDS, Local.Operator, Local.Thanos, Local.TelemeterRules, Local.ServiceMonitors, Local.Secrets)
}

func (Build) generator(config ClusterConfig, component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateClustersPath, string(config.Environment), string(config.Name), component)
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

func (Stage) generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "staging")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

func (Production) generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "production")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

func (Local) generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "local")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

const (
	stageNamespace = "rhobs-stage"
	prodNamespace  = "rhobs-production"
	localNamespace = "rhobs-local"
)

func (Stage) namespace() string {
	return stageNamespace
}

func (Production) namespace() string {
	return prodNamespace
}

func (Local) namespace() string {
	return localNamespace
}

// Build Builds the manifests for the production environment.
func (Production) Build() {
	mg.Deps(Production.Alertmanager)
}
