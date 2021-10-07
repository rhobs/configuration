{
  roles: [
    {
      name: 'rhobs-read',
      resources: [
        'metrics',
        'logs',
      ],
      tenants: [
        'rhobs',
      ],
      permissions: [
        'read',
      ],
    },
    {
      name: 'rhobs-write',
      resources: [
        'metrics',
        'logs',
      ],
      tenants: [
        'rhobs',
      ],
      permissions: [
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
          name: 'service-account-observatorium-rhobs-staging',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-rhobs',
          kind: 'user',
        },
      ],
    },
    {
      name: 'rhobs-admin',
      roles: [
        'telemeter-read',
        'rhobs-read',
      ],
      subjects: [
        {
          name: 'team-observability-platform@redhat.com',
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
