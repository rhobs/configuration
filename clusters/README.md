# RHOBS Configuration Build System

This directory contains the configuration management system for RHOBS (Red Hat Observability Service) clusters. The system generates Kubernetes manifests for Thanos-based observability infrastructure across multiple environments. Build orchestration is handled through [Mage](https://magefile.org/) build targets that process Go-based cluster definitions and templates.

## Table of Contents

- [Build System Components](#build-system-components)
- [Available Build Steps](#available-build-steps)
- [Template System](#template-system)
- [Cluster Definitions](#cluster-definitions)
- [Build Commands](#build-commands)
- [Adding New Clusters](#adding-new-clusters)
- [Template Configuration](#template-configuration)
- [Advanced Usage](#advanced-usage)

### Architecture Overview

1. **Cluster Registration**: Clusters register themselves in a global registry during package initialization through `init()` functions
2. **Template Inheritance**: Base templates define default values, with cluster-specific overrides applied through composition
3. **Modular Build Pipeline**: Build steps can be combined and reordered per cluster through configurable pipelines
4. **Environment Support**: Configurations support integration, staging, and production deployment targets
5. **Type-Safe Configuration**: Go types enforce compile-time validation of configuration parameters
6. **Centralized Constants**: Template parameter names are defined as exportable constants to prevent naming inconsistencies

### Additional Notes

- **Template Key Constants**: All template parameter names are defined as exportable constants in `template.go`

## Build System Components

### Core Files

```
clusters/
├── clusters.go         # Cluster registry, types, and build step constants
├── template.go         # Template system with exportable constants
└── cluster_*.go        # Individual cluster definitions

magefiles/
├── magefile.go         # Main build orchestration
├── thanos.go           # Thanos component generation
├── operator.go         # Operator component generation
├── secrets.go          # Secrets management
├── alertmanager.go     # Alertmanager configuration
├── servicemonitors.go  # Service monitoring setup
└── gateway.go          # Gateway configuration
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

The cluster registry is implemented in [`clusters.go`](clusters.go) with the [`RegisterCluster`](clusters.go#L45) function and [`ClusterConfig`](clusters.go#L18) type.

## Available Build Steps

Modular build steps can be composed per cluster:

| Step | Constant | Description | Implementation |
|------|----------|-------------|----------------|
| **Thanos Operator CRDs** | `StepThanosOperatorCRDS` | Thanos Operator Custom Resource Definitions | [`operator.go`](../magefiles/operator.go) |
| **Thanos Operator** | `StepThanosOperator` | Thanos Operator Manager and RBAC | [`operator.go`](../magefiles/operator.go) |
| **Default Thanos Stack** | `StepDefaultThanosStack` | Core Thanos components (Query, Store, Receive, etc.) | [`thanos.go`](../magefiles/thanos.go) |
| **Service Monitors** | `StepThanosOperatorServiceMonitors` | Prometheus ServiceMonitor resources | [`servicemonitors.go`](../magefiles/servicemonitors.go) |
| **Alertmanager** | `StepAlertmanager` | Alertmanager configuration | [`alertmanager.go`](../magefiles/alertmanager.go) |
| **Secrets** | `StepSecrets` | Required secrets and credentials | [`secrets.go`](../magefiles/secrets.go) |
| **Gateway** | `StepGateway` | API Gateway configuration | [`gateway.go`](../magefiles/gateway.go) |

### Default Build Pipeline

```go
func DefaultBuildSteps() []string {
    return []string{
        StepThanosOperatorCRDS,            // Custom Resource Definitions first
        StepThanosOperator,                // Thanos Operator Manager and RBAC
        StepDefaultThanosStack,            // Core Thanos components
        StepThanosOperatorServiceMonitors, // Monitoring setup
        StepAlertmanager,                  // Alerting configuration
        StepSecrets,                       // Secrets
        StepGateway,                       // Gateway configuration
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

The [`TemplateMaps`](template.go#L16) type and [`ParamMap`](template.go#L13) are defined in [`template.go`](template.go).

### Template Key Constants

Exportable constants are available for all template keys to ensure type safety and consistency:

```go
// Service and component keys
const (
    MemcachedExporter = "MEMCACHED_EXPORTER"
    ApiCache          = "API_CACHE"
    Jaeger            = "JAEGER_AGENT"
    ObservatoriumAPI  = "OBSERVATORIUM_API"
    OpaAMS            = "OPA_AMS"
    
    // Thanos component keys
    ThanosOperator         = "THANOS_OPERATOR"
    KubeRbacProxy          = "KUBE_RBAC_PROXY"
    StoreDefault           = "STORE_DEFAULT"
    ReceiveRouter          = "RECEIVE_ROUTER"
    ReceiveIngestorDefault = "RECEIVE_INGESTOR_DEFAULT"
    Ruler                  = "RULER"
    CompactDefault         = "COMPACT_DEFAULT"
    Query                  = "QUERY"
    QueryFrontend          = "QUERY_FRONTEND"
    Manager                = "MANAGER"
    
    // Object storage keys
    Default   = "DEFAULT"
    Telemeter = "TELEMETER"
    ROS       = "ROS"
)
```

### Override Types

The template system supports several override types, all implemented in [`template.go`](template.go):

- **[`Images`](template.go#L41)**: Container image overrides
- **[`Versions`](template.go#L106)**: Component version overrides  
- **[`LogLevels`](template.go#L93)**: Logging level configuration
- **[`Replicas`](template.go#L54)**: Replica count overrides
- **[`StorageSizes`](template.go#L67)**: Storage size configuration
- **[`Resources`](template.go#L80)**: CPU/Memory resource overrides

### Using Template Functions

When accessing template values in code, use the [`TemplateFn`](template.go#L121) function with the provided constants:

```go
// Preferred: Using constants
replicas := clusters.TemplateFn(clusters.Query, templates.Replicas)
image := clusters.TemplateFn(clusters.StoreDefault, templates.Images)

// Avoid: Using string literals (error-prone)
replicas := clusters.TemplateFn("QUERY", templates.Replicas)
```

### Inheritance Example

```go
func productionClusterTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        // High-traffic production needs more replicas
        Replicas{
            clusters.Query:                    3,
            clusters.ReceiveRouter:           2,
            clusters.ReceiveIngestorDefault: 3,
        },
        // Production-specific images
        Images{
            clusters.ThanosOperator: "quay.io/rhobs/thanos-operator:v1.0.0",
        },
        // Enhanced logging for debugging
        LogLevels{
            clusters.Query: "debug",
        },
        // Larger storage for high volume
        StorageSizes{
            clusters.ReceiveIngestorDefault: v1alpha1.StorageSize("100Gi"),
        },
    )
}
```

This example uses [`DefaultBaseTemplate()`](template.go#L187) and the [`.Override()`](template.go#L27) method.

## Cluster Definitions

Each cluster is defined in its own file following the pattern `cluster_<name>.go`:

### Basic Cluster Definition

```go
package clusters

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
        Replicas{clusters.Query: 3},
        LogLevels{clusters.Query: "warn"},
    )
}
```

This uses the [`ClusterName`](clusters.go#L11) type, [`EnvironmentProduction`](clusters.go#L14) constant, and [`DefaultBuildSteps()`](clusters.go#L91) function.

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
        StepThanosOperatorCRDS, // CRDs first
        StepThanosOperator,     // Operator only
        StepSecrets,            // Basic secrets
        // Skip DefaultThanosStack, ServiceMonitors, Alertmanager, Gateway for minimal setup
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

These commands are implemented in [`../magefiles/magefile.go`](../magefiles/magefile.go): [`Clusters()`](../magefiles/magefile.go#L85), [`Cluster()`](../magefiles/magefile.go#L100), and [`Environment()`](../magefiles/magefile.go#L110).

#### Utility Commands

```bash
# List all available build steps
mage build:list

# Show build steps for each cluster
mage build:listClusters

# List all available mage targets
mage -l
```

The utility commands [`List()`](../magefiles/magefile.go#L130) and [`ListClusters()`](../magefiles/magefile.go#L138) are also in [`../magefiles/magefile.go`](../magefiles/magefile.go).

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
            clusters.Query:                    5,
            clusters.ReceiveRouter:           3,
            clusters.ReceiveIngestorDefault: 5,
            clusters.StoreDefault:            3,
        },
        Resources{
            clusters.Query: {
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
            clusters.ReceiveIngestorDefault: v1alpha1.StorageSize("500Gi"),
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
            clusters.Query:                    1,
            clusters.ReceiveRouter:           1,
            clusters.ReceiveIngestorDefault: 1,
        },
        LogLevels{
            clusters.Query: "debug", // More verbose for debugging
        },
        StorageSizes{
            clusters.ReceiveIngestorDefault: v1alpha1.StorageSize("10Gi"),
        },
    )
}
```

#### Regional Production Cluster

```go
func regionalProdTemplates() TemplateMaps {
    return DefaultBaseTemplate().Override(
        Images{
            clusters.ThanosOperator: "quay.io/rhobs/thanos-operator:v1.0.0-region-eu",
        },
        // Regional-specific storage configuration
        ObjectStorageBucket{
            clusters.Default: v1alpha1.ObjectStorageConfig{
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
        StepSecrets,               // Secrets first for this deployment
        StepThanosOperatorCRDS,    // Then CRDs
        StepThanosOperator,        // Operator
        StepDefaultThanosStack,    // Core components
        // Skip ServiceMonitors, Alertmanager, and Gateway
    }
}

// Or compose from existing steps
func debugBuildSteps() []string {
    return []string{
        StepThanosOperatorCRDS,
        StepThanosOperator,
        // Only basic components for debugging
    }
}
```
### Debugging Template Values

Add debug prints to see resolved template values:

```go
func debugTemplates() TemplateMaps {
    result := DefaultBaseTemplate().Override(
        Replicas{clusters.Query: 3},
    )
    
    // Debug output
    fmt.Printf("QUERY Replicas: %d\n", TemplateFn(clusters.Query, result.Replicas))
    fmt.Printf("QUERY Image: %s\n", TemplateFn(clusters.Query, result.Images))
    
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