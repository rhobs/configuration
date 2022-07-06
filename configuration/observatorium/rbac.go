package cfgobservatorium

import (
	"fmt"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
)

type tenantID string

const (
	cnvqeTenant      tenantID = "cnvqe"
	telemeterTenant  tenantID = "telemeter"
	rhobsTenant      tenantID = "rhobs"
	psiocpTenant     tenantID = "psiocp"
	rhodsTenant      tenantID = "rhods"
	rhacsTenant      tenantID = "rhacs"
	rhocTenant       tenantID = "rhoc"
	odfmsTenant      tenantID = "odfms"
	refAddonTenant   tenantID = "reference-addon"
	hypershiftTenant tenantID = "hypershift"
)

type signal string

const (
	metricsSignal signal = "metrics"
	logsSignal    signal = "logs"
	tracesSignal  signal = "traces"
)

type env string

const (
	testingEnv    env = "testing"
	stagingEnv    env = "staging"
	productionEnv env = "production"
)

// GenerateRBAC generates rbac.json that is meant to be consumed by observatorium.libsonnet
// and put into config map consumed by observatorium-api.
//
// RBAC defines roles and role binding for each tenant and matching subject names that will be validated
// against 'user' field in the incoming JWT token that contains service account.
//
// TODO(bwplotka): Generate tenants.yaml (without secrets) using the same tenant definitions.
func GenerateRBAC(gen *mimic.Generator) {
	obsRBAC := observatoriumRBAC{
		mappedRoleNames: map[roleMapKey]string{},
	}

	// CNV-QE
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-cnv-qe",
		tenant:  cnvqeTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// RHODS
	attachBinding(&obsRBAC, bindingOpts{
		name:    "rhods-isv-staging",
		tenant:  rhodsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
		envs:    []env{stagingEnv},
	})
	attachBinding(&obsRBAC, bindingOpts{
		// Write only SA
		name:    "observatorium-rhods-isv-staging-wo",
		tenant:  rhodsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write},
		envs:    []env{stagingEnv},
	})

	// RHACS
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhacs-metrics",
		tenant:  rhacsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhacs-grafana",
		tenant:  rhacsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhacs-logs",
		tenant:  rhacsTenant,
		signals: []signal{logsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// RHOBS
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhobs",
		tenant:  rhobsTenant,
		signals: []signal{metricsSignal, logsSignal, tracesSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{testingEnv, stagingEnv, productionEnv},
	})
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhobs-mst",
		tenant:  rhobsTenant,
		signals: []signal{metricsSignal, logsSignal, tracesSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})
	// Special admin role.
	obsRBAC.RoleBindings = append(obsRBAC.RoleBindings, rbac.RoleBinding{
		Name: "rhobs-admin",
		Roles: []string{
			getOrCreateRoleName(&obsRBAC, telemeterTenant, metricsSignal, rbac.Read),
			getOrCreateRoleName(&obsRBAC, rhobsTenant, metricsSignal, rbac.Read),
			getOrCreateRoleName(&obsRBAC, rhobsTenant, logsSignal, rbac.Read),
			getOrCreateRoleName(&obsRBAC, rhobsTenant, tracesSignal, rbac.Read),
		},
		Subjects: []rbac.Subject{{Name: "team-monitoring@redhat.com", Kind: rbac.Group}},
	})

	// Telemeter
	attachBinding(&obsRBAC, bindingOpts{
		name:    "telemeter-service",
		tenant:  telemeterTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// Subwatch
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-subwatch",
		tenant:  telemeterTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// PSIOCP
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-psiocp",
		tenant:  psiocpTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv},
	})

	// RHOC
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhoc",
		tenant:  rhocTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv},
	})

	// ODFMS
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-odfms",
		tenant:  odfmsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write}, // Write only.
		envs:    []env{stagingEnv, productionEnv},
	})
	// Special request of extra read account.
	// Ref: https://issues.redhat.com/browse/MON-2536?focusedCommentId=20492830&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-20492830
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-odfms-read",
		tenant:  odfmsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read}, // Read only.
		envs:    []env{stagingEnv, productionEnv},
	})

	// reference-addon
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-reference-addon",
		tenant:  refAddonTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// hypershift
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-hypershift",
		tenant:  hypershiftTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// Use JSON because we want to have jsonnet using that in configmaps/secrets.
	gen.Add("rbac.json", encoding.JSON(obsRBAC))
}

type roleMapKey struct {
	tenant tenantID
	signal signal
	perm   rbac.Permission
}

// observatoriumRBAC represents the structure that is sued to parse RBAC configuration
// in Observatorium API: https://github.com/observatorium/api/blob/078b7ce75837bb03984f5ed99d2b69a512b696b5/rbac/rbac.go#L181.
type observatoriumRBAC struct {
	// mappedRoleNames is used for deduplication logic.
	mappedRoleNames map[roleMapKey]string

	Roles        []rbac.Role        `json:"roles"`
	RoleBindings []rbac.RoleBinding `json:"roleBindings"`
}

type bindingOpts struct {
	// NOTE(bwplotka): Name is strongly correlated to subject name that corresponds to the service account username (it has to match it)/
	// Any change, require changes on tenant side, so be careful.
	name    string
	tenant  tenantID
	signals []signal
	perms   []rbac.Permission
	envs    []env
}

func getOrCreateRoleName(o *observatoriumRBAC, tenant tenantID, s signal, p rbac.Permission) string {
	k := roleMapKey{tenant: tenant, signal: s, perm: p}

	n, ok := o.mappedRoleNames[k]
	if !ok {
		n = fmt.Sprintf("%s-%s-%s", k.tenant, k.signal, k.perm)
		o.Roles = append(o.Roles, rbac.Role{
			Name:        n,
			Permissions: []rbac.Permission{k.perm},
			Resources:   []string{string(k.signal)},
			Tenants:     []string{string(k.tenant)},
		})
		o.mappedRoleNames[k] = n
	}
	return n
}

func attachBinding(o *observatoriumRBAC, opts bindingOpts) {
	for _, b := range o.RoleBindings {
		if b.Name == opts.name {
			mimic.Panicf("found duplicate binding name", opts.name)
		}
	}

	// Is there role that satisfy this already? If not, create.
	var roles []string
	for _, s := range opts.signals {
		for _, p := range opts.perms {
			roles = append(roles, getOrCreateRoleName(o, opts.tenant, s, p))
		}
	}

	var subs []rbac.Subject
	for _, e := range opts.envs {
		n := fmt.Sprintf("service-account-%s-%s", opts.name, e)
		if e == productionEnv {
			n = fmt.Sprintf("service-account-%s", opts.name)
		}
		subs = append(subs, rbac.Subject{Name: n, Kind: rbac.User})
	}

	o.RoleBindings = append(o.RoleBindings, rbac.RoleBinding{
		Name:     opts.name,
		Roles:    roles,
		Subjects: subs,
	})
}
