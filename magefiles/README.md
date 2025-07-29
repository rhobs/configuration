# RHOBS Configuration Build System

This repository contains the configuration management system for RHOBS (Red Hat Observability Service) clusters. The build system is implemented using [Mage](https://magefile.org/) and provides a flexible, code-driven approach to managing multiple cluster deployments.

## Table of Contents

- [Build System Components](#build-system-components)
- [Available Build Steps](#available-build-steps)
- [Template System](#template-system)
- [Cluster Definitions](#cluster-definitions)
- [Build Commands](#build-commands)
- [Adding New Clusters](#adding-new-clusters)
- [Template Configuration](#template-configuration)
- [Advanced Usage](#advanced-usage)

### Key Design Principles

1. **Self-Registering Clusters**: Each cluster auto-registers via `init()` functions
2. **Inheritance-First**: Base templates with targeted overrides
3. **Composable Build Steps**: Mix and match build components
4. **Environment Awareness**: Integration, staging, and production variants
5. **Type Safety**: Go's type system prevents configuration errors

## Build System Components

### Core Files

```
magefiles/
├── magefile.go         # Main build orchestration
├── clusters.go         # Cluster registry and types
├── template.go         # Template system and inheritance
├── thanos.go           # Thanos component generation
├── operator.go         # Operator component generation
├── secrets.go          # Secrets management
├── alertmanager.go     # Alertmanager configuration
├── servicemonitors.go  # Service monitoring setup
└── cluster_*.go        # Individual cluster definitions
```

### Cluster Registry

```go
// Global registry - clusters auto-register on import
var ClusterRegistry = make(map[ClusterName]ClusterConfig)

// Each cluster file registers itself
func init() {
    RegisterCluster(ClusterConfig{
        Name:        "my-cluster",
        Environment: EnvironmentProduction,
        Namespace:   "rhobs-prod",
        Templates:   myClusterTemplates(),
        BuildSteps:  DefaultBuildSteps(),
    })
}
```

## Available Build Steps

The system provides modular build steps that can be composed per cluster:

| Step | Constant | Description |
|------|----------|-------------|
| **CRDs** | `StepCRDS` | Thanos Operator Custom Resource Definitions |
| **Operator** | `StepOperator` | Thanos Operator Manager and RBAC |
| **Thanos** | `StepThanos` | Core Thanos components (Query, Store, Receive, etc.) |
| **Service Monitors** | `StepServiceMonitors` | Prometheus ServiceMonitor resources |
| **Alertmanager** | `StepAlertmanager` | Alertmanager configuration |
| **Secrets** | `StepSecrets` | Required secrets and credentials |
| **Gateway** | `StepGateway` | API Gateway configuration |

### Default Build Pipeline

```go
func DefaultBuildSteps() []string {
    return []string{
        StepThanos,          // Core components first
        StepCRDS,            // Custom Resource Definitions
        StepOperator,        // Operator deployment
        StepServiceMonitors, // Monitoring setup
        StepAlertmanager,    // Alerting configuration
        StepSecrets,         // Secrets last
        StepGateway,         // Gateway configuration
    }
}
```

## Template System

The template system uses **inheritance with overrides** to minimize boilerplate while allowing cluster-specific customization.

### Base Template Structure

```go
type TemplateMaps struct {
    Images               ParamMap[string]                    // Container images
    Versions             ParamMap[string]                    // Component versions
    LogLevels            ParamMap[string]                    // Logging configuration
    StorageSize          ParamMap[v1alpha1.StorageSize]     // Storage allocations
    Replicas             ParamMap[int32]                     // Replica counts
    ResourceRequirements ParamMap[corev1.ResourceRequirements] // CPU/Memory limits
    ObjectStorageBucket  ParamMap[v1alpha1.ObjectStorageConfig] // Object storage config
}
```

### Override Types

- **`Images`**: Container image overrides
- **`Versions`**: Component version overrides  
- **`LogLevels`**: Logging level configuration
- **`Replicas`**: Replica count overrides
- **`StorageSizes`**: Storage size configuration
- **`Resources`**: CPU/Memory resource overrides

### Inheritance Example

```go
func productionClusterTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        // High-traffic production needs more replicas
        Replicas{
            "QUERY":                    3,
            "RECEIVE_ROUTER":           2,
            "RECEIVE_INGESTOR_DEFAULT": 3,
        },
        // Production-specific images
        Images{
            "THANOS_OPERATOR": "quay.io/rhobs/thanos-operator:v1.0.0",
        },
        // Enhanced logging for debugging
        LogLevels{
            "QUERY": "debug",
        },
        // Larger storage for high volume
        StorageSizes{
            "RECEIVE_DEFAULT_STORAGE_SIZE": v1alpha1.StorageSize("100Gi"),
        },
    )
}
```

## Cluster Definitions

Each cluster is defined in its own file following the pattern `cluster_<name>.go`:

### Basic Cluster Definition

```go
package main

const (
    ClusterMyProduction ClusterName = "my-production"
)

func init() {
    RegisterCluster(ClusterConfig{
        Name:        ClusterMyProduction,
        Environment: EnvironmentProduction,
        Namespace:   "rhobs-prod",
        Templates:   myProductionTemplates(),
        BuildSteps:  DefaultBuildSteps(),
    })
}

func myProductionTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        Replicas{"QUERY": 3},
        LogLevels{"QUERY": "warn"},
    )
}
```

### Advanced Cluster with Custom Build Steps

```go
func init() {
    RegisterCluster(ClusterConfig{
        Name:        "minimal-test",
        Environment: EnvironmentIntegration,
        Namespace:   "rhobs-test",
        Templates:   minimalTemplates(),
        BuildSteps:  customMinimalSteps(), // Custom pipeline
    })
}

func customMinimalSteps() []string {
    return []string{
        StepCRDS,     // CRDs first
        StepOperator, // Operator only
        StepSecrets,  // Basic secrets
        // Skip Thanos, ServiceMonitors, Alertmanager, Gateway for minimal setup
    }
}
```

## Build Commands

### Available Mage Targets

#### Cluster-Specific Builds

```bash
# Build all registered clusters
mage build:clusters

# Build specific cluster by name
mage build:cluster my-cluster-name

# Build all clusters in an environment
mage build:environment staging
mage build:environment production
mage build:environment integration
```

#### Utility Commands

```bash
# List all available build steps
mage build:list

# Show build steps for each cluster
mage build:listClusters

# List all available mage targets
mage -l
```

#### Legacy Environment Builds

```bash
# Legacy single-environment builds (still supported)
mage stage:build       # Builds staging environment
mage production:build  # Builds production environment  
mage local:build       # Builds local development environment

# Additional legacy component builds
mage stage:cache       # Builds memcached cache for staging
mage production:cache  # Builds memcached cache for production
mage stage:gateway     # Builds gateway for staging
mage production:gateway # Builds gateway for production
mage stage:telemeterRules    # Builds telemeter rules for staging
mage local:telemeterRules    # Builds telemeter rules for local
```

### Output Structure

Generated manifests are organized as:

```
resources/
└── clusters/
    └── {environment}/
        └── {cluster-name}/
            └── {component}/
                └── *.yaml
```

Example:
```
resources/
└── clusters/
    └── production/
        └── my-cluster/
            ├── thanos-operator-default-cr/
            │   └── thanos-operator-default-cr.yaml
            ├── thanos-operator/
            │   └── operator.yaml
            └── secrets/
                └── thanos-default-secret.yaml
```

## Adding New Clusters

### Step 1: Create Cluster Definition File

Create `magefiles/cluster_<name>.go`:

```go
package main

const (
    ClusterNewProduction ClusterName = "new-production"
)

func init() {
    RegisterCluster(ClusterConfig{
        Name:        ClusterNewProduction,
        Environment: EnvironmentProduction,
        Namespace:   "rhobs-new-prod",
        Templates:   newProductionTemplates(),
        BuildSteps:  DefaultBuildSteps(),
    })
}

func newProductionTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        // Your cluster-specific overrides here
        Replicas{
            "QUERY": 2,
            "RECEIVE_ROUTER": 2,
        },
        LogLevels{
            "QUERY": "info",
        },
    )
}
```

### Step 2: Verify Registration

```bash
# Check that your cluster is registered
mage build:listClusters

# Should show your new cluster in the output
```

### Step 3: Test Build

```bash
# Build your specific cluster
mage build:cluster new-production

# Or build entire environment
mage build:environment production
```

### Step 4: Validate Output

Check that manifests are generated in:
```
resources/clusters/production/new-production/
```

## Template Configuration

### Common Override Patterns

#### High-Traffic Production Cluster

```go
func highTrafficProdTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        Replicas{
            "QUERY":                    5,
            "RECEIVE_ROUTER":           3,
            "RECEIVE_INGESTOR_DEFAULT": 5,
            "STORE_DEFAULT":            3,
        },
        Resources{
            "QUERY": {
                Limits: corev1.ResourceList{
                    corev1.ResourceCPU:    resource.MustParse("2"),
                    corev1.ResourceMemory: resource.MustParse("4Gi"),
                },
                Requests: corev1.ResourceList{
                    corev1.ResourceCPU:    resource.MustParse("1"),
                    corev1.ResourceMemory: resource.MustParse("2Gi"),
                },
            },
        },
        StorageSizes{
            "RECEIVE_DEFAULT_STORAGE_SIZE": v1alpha1.StorageSize("500Gi"),
        },
    )
}
```

#### Development/Testing Cluster

```go
func testingTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        // Minimal resources for testing
        Replicas{
            "QUERY":                    1,
            "RECEIVE_ROUTER":           1,
            "RECEIVE_INGESTOR_DEFAULT": 1,
        },
        LogLevels{
            "QUERY": "debug", // More verbose for debugging
        },
        StorageSizes{
            "RECEIVE_DEFAULT_STORAGE_SIZE": v1alpha1.StorageSize("10Gi"),
        },
    )
}
```

#### Regional Production Cluster

```go
func regionalProdTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        Images{
            "THANOS_OPERATOR": "quay.io/rhobs/thanos-operator:v1.0.0-region-eu",
        },
        // Regional-specific storage configuration
        ObjectStorageBucket{
            "DEFAULT": v1alpha1.ObjectStorageConfig{
                Key: "thanos-eu.yaml",
                LocalObjectReference: corev1.LocalObjectReference{
                    Name: "observatorium-thanos-objectstorage-eu",
                },
                Optional: ptr.To(false),
            },
        },
    )
}
```

## Advanced Usage

### Custom Build Steps

You can create entirely custom build pipelines:

```go
func deploymentSpecificSteps() []string {
    base := DefaultBuildSteps()
    
    // Different ordering for special requirements
    return []string{
        StepSecrets,        // Secrets first for this deployment
        StepCRDS,          // Then CRDs
        StepOperator,      // Operator
        StepThanos,        // Core components
        // Skip ServiceMonitors, Alertmanager, and Gateway
    }
}

// Or compose from existing steps
func debugBuildSteps() []string {
    return []string{
        StepCRDS,
        StepOperator,
        // Only basic components for debugging
    }
}
```
### Debugging Template Values

Add debug prints to see resolved template values:

```go
func debugTemplates() TemplateMaps {
    result := DefaultBaseTemplate().Override(
        Replicas{"QUERY": 3},
    )
    
    // Debug output
    fmt.Printf("QUERY Replicas: %d\n", TemplateFn("QUERY", result.Replicas))
    fmt.Printf("QUERY Image: %s\n", TemplateFn("QUERY", result.Images))
    
    return result
}
```

## Troubleshooting

### Common Issues

1. **Cluster not found**: Ensure your cluster file is in `magefiles/` and has correct `init()` function
2. **Missing parameters**: Check that all required template parameters are defined in `DefaultBaseTemplate()`
3. **Build step failures**: Verify build step names match constants in `magefile.go`
4. **Template errors**: Use debug prints to verify template parameter resolution

### Getting Help

```bash
# List all available commands
mage -l

# Get help for specific namespace
mage -h build

# Show cluster information
mage build:listClusters
```