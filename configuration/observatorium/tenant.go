package cfgobservatorium

import (
	"fmt"
	"io/ioutil"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
)

const (
	opaURL        = "http://127.0.0.1:8082/v1/data/observatorium/allow"
	usernameClaim = "preferred_username"
)

type tenant struct {
	Name string
	ID   string
	OPA  bool
}

var (
	rhobsTenant = tenant{
		ID:   "0fc2b00e-201b-4c17-b9f2-19d91adc4fd2",
		Name: "rhobs",
	}
	osdTenant = tenant{
		ID:   "770c1124-6ae8-4324-a9d4-9ce08590094b",
		Name: "osd",
	}
	managedKafkaTenant = tenant{
		ID:   "63e320cd-622a-4d05-9585-ffd48342633",
		Name: "managedkafka",
	}
	rhacsTenant = tenant{
		ID:   "1b9b6e43-9128-4bbf-bfff-3c120bbe6f11",
		Name: "rhacs",
	}
	cnvqeTenant = tenant{
		ID:   "9ca26972-4328-4fe3-92db-31302013d03f",
		Name: "cnvqe",
	}
	odfmsTenant = tenant{
		ID:   "99c885bc-2d64-4c4d-b55e-8bf30d98c657",
		Name: "odfms",
	}
)

func redirectMSTURL(t tenant) string {
	return fmt.Sprintf("https://observatorium-mst.api.openshift.com/oidc/%s/callback", t.Name)
}

// GenerateTenantSecret generates secret we store in Vault for tenants.yaml purposes.
// See https://gitlab.cee.redhat.com/service/app-interface/-/merge_requests/38074/diffs
// This generates it to tmp location, for manual copy and update in Vault.
// TODO(bwplotka): Use it for Philip's change to template secret in AppInterface.
// TODO(bwplotka): Add support for staging and testing YAMLs (instead of tenants.libsonnet).
// NOTE(bwplotka): Replace <SECRET> with proper client secret.
func GenerateTenantSecret(gen *mimic.Generator) {
	prod := tenantsVaultSecret{
		ClientID:     "observatorium-osd",
		ClientSecret: "<SECRET>",
		IssuerURL:    "https://sso.redhat.com/auth/realms/redhat-external",
	}

	var prodTenants tenantsConfig
	prodTenants.Tenants = append(prodTenants.Tenants,
		apiTenant{
			ID: rhobsTenant.ID, Name: rhobsTenant.Name,
			OIDC: &apiTenantOIDC{
				ClientID:      prod.ClientID,
				ClientSecret:  prod.ClientSecret,
				IssuerURL:     prod.IssuerURL,
				RedirectURL:   redirectMSTURL(rhobsTenant),
				UsernameClaim: usernameClaim,
				GroupClaim:    "email",
			},
		},
		apiTenant{
			ID: osdTenant.ID, Name: osdTenant.Name,
			OIDC: &apiTenantOIDC{
				ClientID:      prod.ClientID,
				ClientSecret:  prod.ClientSecret,
				IssuerURL:     prod.IssuerURL,
				RedirectURL:   redirectMSTURL(osdTenant),
				UsernameClaim: usernameClaim,
			},
			OPA: &apiTenantOPA{
				URL: opaURL,
			},
			RateLimits: []apiTenantRateLimits{
				{
					Endpoint: "/api/metrics/v1/.+/api/v1/receive",
					Limit:    100,
					Window:   "30s",
				},
			},
		},
		apiTenant{
			ID: managedKafkaTenant.ID, Name: managedKafkaTenant.Name,
			OIDC: &apiTenantOIDC{
				// Weird it does not have redirect URL and secret, but that's what was on prod.
				ClientID:      prod.ClientID,
				IssuerURL:     prod.IssuerURL,
				UsernameClaim: usernameClaim,
			},
			OPA: &apiTenantOPA{
				URL: opaURL,
			},
		},
	)

	for _, t := range []tenant{rhacsTenant, cnvqeTenant, odfmsTenant} {
		prodTenants.Tenants = append(prodTenants.Tenants, apiTenant{
			ID: t.ID, Name: t.Name,
			OIDC: &apiTenantOIDC{
				ClientID:      prod.ClientID,
				ClientSecret:  prod.ClientSecret,
				IssuerURL:     prod.IssuerURL,
				RedirectURL:   redirectMSTURL(t),
				UsernameClaim: usernameClaim,
			},
		})
	}
	tenantsYAML, err := ioutil.ReadAll(encoding.GhodssYAML(prodTenants))
	mimic.PanicOnErr(err)

	prod.TenantsYAML = string(tenantsYAML)

	gen.Add("secret-vault.json", encoding.JSON(prod))
}

type tenantsVaultSecret struct {
	ClientID     string `json:"client-id"`
	ClientSecret string `json:"client-secret"`
	IssuerURL    string `json:"issuer-url"`
	TenantsYAML  string `json:"tenants.yaml"` // Vault wants stringified YAML.
}

type tenantsConfig struct {
	Tenants []apiTenant `json:"tenants"`
}

type apiTenantOIDC struct {
	ClientID     string `json:"clientID,omitempty"`
	ClientSecret string `json:"clientSecret,omitempty"`
	IssuerRawCA  []byte `json:"issuerCA,omitempty"`
	IssuerCAPath string `json:"issuerCAPath,omitempty"`
	IssuerURL    string `json:"issuerURL,omitempty"`
	// RedirectURL optional - fallback if tenant has not token.
	RedirectURL   string `json:"redirectURL,omitempty"`
	UsernameClaim string `json:"usernameClaim,omitempty"`
	GroupClaim    string `json:"groupClaim,omitempty"`
}

type apiTenantOPA struct {
	URL string `json:"url"`
}

type apiTenantRateLimits struct {
	Endpoint string `json:"endpoint"`
	Limit    int    `json:"limit"`
	Window   string `json:"window"`
}

// Exact copy of main.go tenat struct.
type apiTenant struct {
	Name       string                `json:"name"`
	ID         string                `json:"id"`
	OIDC       *apiTenantOIDC        `json:"oidc,omitempty"`
	OPA        *apiTenantOPA         `json:"opa,omitempty"`
	RateLimits []apiTenantRateLimits `json:"rateLimits,omitempty"`
}
