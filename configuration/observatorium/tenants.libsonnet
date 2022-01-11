{
  tenants: [
    {
      name: 'rhobs',
      id: '770c1124-6ae8-4324-a9d4-9ce08590094b',
      oidc: {
        clientID: 'test',
        clientSecret: 'ZXhhbXBsZS1hcHAtc2VjcmV0',
        issuerURL: 'http://dex.dex.svc.cluster.local:5556/dex',
        usernameClaim: 'email',
      },
    },
    {
      name: 'telemeter',
      id: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
      oidc: {
        clientID: 'test',
        clientSecret: 'ZXhhbXBsZS1hcHAtc2VjcmV0',
        issuerURL: 'http://dex.dex.svc.cluster.local:5556/dex',
        usernameClaim: 'email',
      },
    },
  ],
  // Collect all tenants in a map for convenient access.
  map:: {
    [tenant.name]: tenant
    for tenant in self.tenants
  },
}
