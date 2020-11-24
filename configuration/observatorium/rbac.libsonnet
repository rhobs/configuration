{
  roles: [
    {
      name: 'rhobs',
      resources: [
        'metrics',
        'logs',
      ],
      tenants: [
        'rhobs',
      ],
      permissions: [
        'read',
        'write',
      ],
    },
    {
      name: 'telemeter-write',
      resources: [
        'metrics',
      ],
      tenants: [
        'telemeter',
      ],
      permissions: [
        'write',
      ],
    },
    {
      name: 'dptp-write',
      resources: [
        'logs',
      ],
      tenants: [
        'dptp',
      ],
      permissions: [
        'write',
      ],
    },
    {
      name: 'dptp-read',
      resources: [
        'logs',
      ],
      tenants: [
        'dptp',
      ],
      permissions: [
        'read',
      ],
    },
  ],
  roleBindings: [
    {
      name: 'rhobs',
      roles: [
        'rhobs',
      ],
      subjects: [
        {
          name: 'rhobs',
          kind: 'group',
        },
      ],
    },
    {
      name: 'telemeter-server',
      roles: [
        'telemeter-write',
      ],
      subjects: [
        {
          name: 'service-account-telemeter-service-staging',
          kind: 'user',
        },
        {
          name: 'service-account-telemeter-service',
          kind: 'user',
        },
      ],
    },
    {
      name: 'dptp-collector',
      roles: [
        'dptp-write',
      ],
      subjects: [
        {
          name: 'service-account-observatorium-dptp-collector',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-dptp-collector-staging',
          kind: 'user',
        },
      ],
    },
    {
      name: 'dptp-reader',
      roles: [
        'dptp-read',
      ],
      subjects: [
        {
          name: 'service-account-observatorium-dptp-reader',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-dptp-reader-staging',
          kind: 'user',
        },
      ],
    },
  ],
}
