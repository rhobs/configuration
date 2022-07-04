{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: { name: 'observatorium' },
  objects: [
      {
          apiVersion: 'v1',
          kind: 'Secret',
          metadata+: {
            name: 'observatorium-observatorium-mst-api',
          },
          type: 'Opaque',
          data: {
            'client-id': "${CLIENT_ID}",
            'client-secret': "${CLIENT_SECRET}",
            'issuer-url': "https://sso.redhat.com/auth/realms/redhat-external",
            'tenants.yaml': {
                tenants: [
                    { "id": "0fc2b00e-201b-4c17-b9f2-19d91adc4fd2"
                      "name": "rhobs"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/rhobs/callback"
                        "usernameClaim": "preferred_username"
                        "groupClaim": "email"
                    },
                    { "id": "770c1124-6ae8-4324-a9d4-9ce08590094b"
                      "name": "osd"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/osd/callback"
                        "usernameClaim": "preferred_username"
                      "opa":
                        "url": "http://127.0.0.1:8082/v1/data/observatorium/allow"
                      "rateLimits":
                      - "endpoint": "/api/metrics/v1/.+/api/v1/receive"
                        "limit": 10000
                        "window": "30s"
                    - "id": "63e320cd-622a-4d05-9585-ffd48342633e"
                      "name": "managedkafka"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/managedkafka/callback"
                        "usernameClaim": "preferred_username"
                      "opa":
                        "url": "http://127.0.0.1:8082/v1/data/observatorium/allow"
                    - "id": "1b9b6e43-9128-4bbf-bfff-3c120bbe6f11"
                      "name": "rhacs"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/rhacs/callback"
                        "usernameClaim": "preferred_username"
                    - "id": "9ca26972-4328-4fe3-92db-31302013d03f"
                      "name": "cnvqe"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/cnvqe/callback"
                        "usernameClaim": "preferred_username"
                    - "id": "37b8fd3f-56ff-4b64-8272-917c9b0d1623"
                      "name": "psiocp"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/psiocp/callback"
                        "usernameClaim": "preferred_username"
                    - "id": "8ace13a2-1c72-4559-b43d-ab43e32a255a"
                      "name": "rhods"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/rhods/callback"
                        "usernameClaim": "preferred_username"
                    - "id": "2dd839e2-cf2b-424a-add4-2e826b7541ee"
                      "name": "rhoc"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/rhoc/callback"
                        "usernameClaim": "preferred_username"
                    - "id": "99c885bc-2d64-4c4d-b55e-8bf30d98c657"
                      "name": "odfms"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/odfms/callback"
                        "usernameClaim": "preferred_username"
                    - "id": "d17ea8ce-d4c6-42ef-b259-7d10c9227e93"
                      "name": "reference-addon"
                      "oidc":
                        "clientID": "${CLIENT_ID}"
                        "clientSecret": "${CLIENT_SECRET}"
                        "issuerURL": "https://sso.redhat.com/auth/realms/redhat-external"
                        "redirectURL": "https://observatorium-mst.api.stage.openshift.com/oidc/reference-addon/callback"
                        "usernameClaim": "preferred_username"
                ]
            },
          },
      },
  ],
  parameters: [
      { name: "CLIENT_ID" },
      { name: "CLIENT_SECRET" },
  ]
}