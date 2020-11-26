{
  tenants: [
    {
      name: 'rhobs',
      id: '770c1124-6ae8-4324-a9d4-9ce08590094b',
      oidc: {
        clientID: 'id',
        clientSecret: 'secret',
        issuerURL: 'https://rhobs.tenants.observatorium.io',
        usernameClaim: 'preferred_username',
        groupClaim: 'groups',
      },
    },
    {
      name: 'telemeter',
      id: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
      oidc: {
        clientID: 'id',
        clientSecret: 'secret',
        issuerURL: 'https://sso.redhat.com/auth/realms/redhat-external',
        usernameClaim: 'preferred_username',
      },
    },
    {
      name: 'dptp',
      id: 'AC879303-C60F-4D0D-A6D5-A485CFD638B8',
      oidc: {
        clientID: 'id',
        clientSecret: 'secret',
        issuerURL: 'https://sso.redhat.com/auth/realms/redhat-external',
        usernameClaim: 'preferred_username',
      },
    },
  ],
}
