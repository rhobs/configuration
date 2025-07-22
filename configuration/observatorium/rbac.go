package cfgobservatorium

import (
	"fmt"
	"strings"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
)

type tenantID string

const (
	cnvqeTenant     tenantID = "cnvqe"
	telemeterTenant tenantID = "telemeter"
	rhobsTenant     tenantID = "rhobs"
	psiocpTenant    tenantID = "psiocp"
	rhodsTenant     tenantID = "rhods"
	rhacsTenant     tenantID = "rhacs"
	odfmsTenant     tenantID = "odfms"
	refAddonTenant  tenantID = "reference-addon"
	rhtapTenant     tenantID = "rhtap"
	rhelTenant      tenantID = "rhel"
	rosTenant       tenantID = "ros"
)

type signal string

const (
	metricsSignal signal = "metrics"
)

type env string

const (
	testingEnv    env = "testing"
	stagingEnv    env = "staging"
	productionEnv env = "production"
)

func GenerateRBACFile(gen *mimic.Generator) {
	gen.Add("rbac.json", encoding.JSON(GenerateRBAC()))
}

// GenerateRBAC generates rbac.json that is meant to be consumed by observatorium.libsonnet
// and put into config map consumed by observatorium-api.
//
// RBAC defines roles and role binding for each tenant and matching subject names that will be validated
// against 'user' field in the incoming JWT token that contains service account.
//
// TODO(bwplotka): Generate tenants.yaml (without secrets) using the same tenant definitions.
func GenerateRBAC() *observatoriumRBAC {
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
	// Starbust write-only
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-starburst-isv-write",
		tenant:  rhodsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write},
		envs:    []env{stagingEnv},
	})
	// Starbust read-only
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-starburst-isv-read",
		tenant:  rhodsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
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

	// RHOBS
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhobs",
		tenant:  rhobsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{testingEnv, stagingEnv, productionEnv},
	})
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhobs-mst",
		tenant:  rhobsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})
	// Special admin role.
	obsRBAC.RoleBindings = append(obsRBAC.RoleBindings, rbac.RoleBinding{
		Name: "rhobs-admin",
		Roles: []string{
			getOrCreateRoleName(&obsRBAC, telemeterTenant, metricsSignal, rbac.Read),
			getOrCreateRoleName(&obsRBAC, rhobsTenant, metricsSignal, rbac.Read),
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

	// CCX Processing
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-ccx-processing",
		tenant:  telemeterTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// SD TCS (App-interface progressive delivery feature)
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-sdtcs",
		tenant:  telemeterTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
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

	// ODFMS
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-odfms-write",
		tenant:  odfmsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write}, // Write only.
		envs:    []env{productionEnv},
	})
	// Special request of extra read account.
	// Ref: https://issues.redhat.com/browse/MON-2536?focusedCommentId=20492830&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-20492830
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-odfms-read",
		tenant:  odfmsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read}, // Read only.
		envs:    []env{productionEnv},
	})

	// ODFMS has one set of staging credentials that has read & write permissions
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-odfms",
		tenant:  odfmsTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read, rbac.Write},
		envs:    []env{stagingEnv},
	})

	// reference-addon
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-reference-addon",
		tenant:  refAddonTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write, rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})

	// placeholder read only prod
	// Special request of extra read account.
	// https://issues.redhat.com/browse/RHOBS-1116
	attachBinding(&obsRBAC, bindingOpts{
		name:                "7f7f912e-0429-4639-8e70-609ecf65b280",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// analytics read only prod
	// Special request of extra read account.
	// https://issues.redhat.com/browse/RHOBS-1116
	attachBinding(&obsRBAC, bindingOpts{
		name:                "8f7aa5e1-aa08-493d-82eb-cf24834fc08f",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// data foundation pms read only prod
	// Special request of extra read account.
	// https://issues.redhat.com/browse/RHOBS-1116
	attachBinding(&obsRBAC, bindingOpts{
		name:                "4bfe1a9f-e875-4d37-9c6a-d2faff2a69dc",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// observability pms read only prod
	// Special request of extra read account.
	attachBinding(&obsRBAC, bindingOpts{
		name:                "f6b3e12c-bb50-4bfc-89fe-330a28820fa9",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// hybrid-platforms pms read only prod
	// Special request of extra read account.
	attachBinding(&obsRBAC, bindingOpts{
		name:                "1a45eb31-bcc6-4bb7-8a38-88f00aa718ee",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// cnv read only prod
	// Special request of extra read account.
	// https://issues.redhat.com/browse/RHOBS-1116
	attachBinding(&obsRBAC, bindingOpts{
		name:                "e7c2f772-e418-4ef3-9568-ea09b1acb929",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// dev-spaces read only prod
	// Special request of extra read account.
	// https://issues.redhat.com/browse/RHOBS-1116
	attachBinding(&obsRBAC, bindingOpts{
		name:                "e07f5b10-e62b-47a2-9698-e245d1198a3b",
		tenant:              telemeterTenant,
		signals:             []signal{metricsSignal},
		perms:               []rbac.Permission{rbac.Read}, // Read only.
		envs:                []env{productionEnv},
		skipConventionCheck: true,
	})

	// RHTAP
	// Reader and Writer serviceaccount
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhtap",
		tenant:  rhtapTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read, rbac.Write},
		envs:    []env{stagingEnv, productionEnv},
	})

	// RHEL
	// Reader serviceaccount
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhel-read",
		tenant:  rhelTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
		envs:    []env{stagingEnv, productionEnv},
	})
	// RHEL
	// Writer serviceaccount
	attachBinding(&obsRBAC, bindingOpts{
		name:    "observatorium-rhel-write",
		tenant:  rhelTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Write},
		envs:    []env{stagingEnv, productionEnv},
	})

	// Resource Optimization on Open Shift (ROS)
	// Reader serviceaccount
	attachBinding(&obsRBAC, bindingOpts{
		name:    "c6882aba-3eda-4fa7-be07-df5f4fc6e2ec",
		tenant:  rosTenant,
		signals: []signal{metricsSignal},
		perms:   []rbac.Permission{rbac.Read},
		envs:    []env{stagingEnv},
	})

	// Use JSON because we want to have jsonnet using that in configmaps/secrets.
	return &obsRBAC
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
	name                string
	tenant              tenantID
	signals             []signal
	perms               []rbac.Permission
	envs                []env
	skipConventionCheck bool
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

func tenantNameFollowsConvention(name string) (string, bool) {
	var envs = []env{stagingEnv, productionEnv, testingEnv}

	for _, e := range envs {
		if strings.HasSuffix(name, string(e)) {
			err := fmt.Sprintf(
				"found name breaking conventions with environment suffix: %s, should be: %s",
				name,
				strings.TrimRight(strings.TrimSuffix(name, string(e)), "-"),
			)
			return err, false
		}
	}

	return "", true
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
		errMsg, ok := tenantNameFollowsConvention(opts.name)
		if !ok && !opts.skipConventionCheck {
			mimic.Panicf(errMsg)
		}

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
