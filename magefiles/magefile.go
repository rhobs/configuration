package main

import (
	"fmt"
	"os"

	"github.com/go-kit/log"
	"github.com/magefile/mage/mg"
	"github.com/philipgough/mimic"
	"github.com/rhobs/configuration/clusters"
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

// BuildStepFunctions maps build step names to their implementation functions
var BuildStepFunctions = map[string]func(Build, clusters.ClusterConfig) error{
	clusters.StepThanosOperatorCRDS: func(b Build, cfg clusters.ClusterConfig) error {
		return b.ThanosOperatorCRDS(cfg)
	},
	clusters.StepThanosOperator: func(b Build, cfg clusters.ClusterConfig) error {
		b.ThanosOperator(cfg)
		return nil
	},
	clusters.StepDefaultThanosStack: func(b Build, cfg clusters.ClusterConfig) error {
		b.DefaultThanosStack(cfg)
		return nil
	},
	clusters.StepThanosOperatorServiceMonitors: func(b Build, cfg clusters.ClusterConfig) error {
		b.ThanosOperatorServiceMonitors(cfg)
		return nil
	},

	clusters.StepLokiOperatorCRDS: func(b Build, cfg clusters.ClusterConfig) error {
		return b.LokiOperatorCRDS(cfg)
	},
	clusters.StepLokiOperator: func(b Build, cfg clusters.ClusterConfig) error {
		b.LokiOperator(cfg)
		return nil
	},
	clusters.StepDefaultLokiStack: func(b Build, cfg clusters.ClusterConfig) error {
		b.DefaultLokiStack(cfg)
		return nil
	},

	clusters.StepAlertmanager: func(b Build, cfg clusters.ClusterConfig) error {
		b.Alertmanager(cfg)
		return nil
	},
	clusters.StepSecrets: func(b Build, cfg clusters.ClusterConfig) error {
		b.Secrets(cfg)
		return nil
	},
	clusters.StepMemcached: func(b Build, cfg clusters.ClusterConfig) error {
		b.Cache(cfg)
		return nil
	},
	clusters.StepGateway: func(b Build, cfg clusters.ClusterConfig) error {
		err := b.Gateway(cfg)
		if err != nil {
			return err
		}
		return nil
	},
}

// ExecuteSteps executes a list of build steps for a cluster
func (b Build) executeSteps(steps []string, cfg clusters.ClusterConfig) error {
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
	clusterConfigs := clusters.GetClusters()
	if len(clusterConfigs) == 0 {
		return fmt.Errorf("no clusters registered")
	}

	for _, cfg := range clusterConfigs {
		if err := b.executeSteps(cfg.BuildSteps, cfg); err != nil {
			return err
		}
	}
	return nil
}

// BuildCluster builds manifests for a specific cluster by name
func (b Build) Cluster(clusterName string) error {
	cluster, err := clusters.GetClusterByName(clusters.ClusterName(clusterName))
	if err != nil {
		return err
	}

	return b.executeSteps(cluster.BuildSteps, *cluster)
}

// BuildEnvironment builds manifests for all clusters in a specific environment
func (b Build) Environment(environment string) error {
	env := clusters.ClusterEnvironment(environment)
	if !env.IsValid() {
		return fmt.Errorf("invalid environment: %s", environment)
	}

	clusterConfigs := clusters.GetClustersByEnvironment(env)
	if len(clusterConfigs) == 0 {
		return fmt.Errorf("no clusters found for environment: %s", environment)
	}

	for _, cfg := range clusterConfigs {
		if err := b.executeSteps(cfg.BuildSteps, cfg); err != nil {
			return err
		}
	}
	return nil
}

// ListAvailableSteps lists all available build steps
func (b Build) List() {
	fmt.Fprintln(os.Stdout, "Available build steps:")
	for step := range BuildStepFunctions {
		fmt.Fprintf(os.Stdout, "  - %s\n", step)
	}
}

// ListClusterSteps shows the build steps for each registered cluster
func (b Build) ListClusters() {
	clusterConfigs := clusters.GetClusters()
	if len(clusterConfigs) == 0 {
		fmt.Fprintln(os.Stdout, "No clusters registered")
		return
	}

	for _, cluster := range clusterConfigs {
		fmt.Fprintf(os.Stdout, "Cluster: %s (%s)\n", cluster.Name, cluster.Environment)
		fmt.Fprintf(os.Stdout, "  Steps: %v\n", cluster.BuildSteps)
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

func (Build) generator(config clusters.ClusterConfig, component string) *mimic.Generator {
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
