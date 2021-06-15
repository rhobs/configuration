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
      name: 'telemeter-read',
      resources: [
        'metrics',
      ],
      tenants: [
        'telemeter',
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
        'telemeter-read',
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
      name: 'subwatch',
      roles: [
        'telemeter-read',
      ],
      subjects: [
        {
          name: 'service-account-observatorium-subwatch-staging',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-subwatch',
          kind: 'user',
        },
      ],
    },
  ],
}
