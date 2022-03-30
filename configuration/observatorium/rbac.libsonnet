{
  roles: [
    {
      name: 'rhacs-metrics-read',
      resources: [
        'metrics',
      ],
      tenants: [
        'rhacs',
      ],
      permissions: [
        'read',
      ],
    },
    {
      name: 'rhacs-metrics-write',
      resources: [
        'metrics',
      ],
      tenants: [
        'rhacs',
      ],
      permissions: [
        'write',
      ],
    },
    {
      name: 'rhacs-logs-write',
      resources: [
        'logs',
      ],
      tenants: [
        'rhacs',
      ],
      permissions: [
        'write',
      ],
    },
    {
      name: 'rhacs-logs-read',
      resources: [
        'logs',
      ],
      tenants: [
        'rhacs',
      ],
      permissions: [
        'read',
      ],
    },
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
      name: 'rhacs-metrics',
      roles: [
        'rhacs-metrics-write',
        'rhacs-metrics-read',
      ],
      subjects: [
        {
          name: 'service-account-observatorium-rhacs-metrics-staging',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-rhacs-metrics',
          kind: 'user',
        },
      ],
    },
    {
      name: 'rhacs-metrics-grafana',
      roles: [
        'rhacs-metrics-read',
      ],
      subjects: [
        {
          name: 'service-account-observatorium-rhacs-grafana-staging',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-rhacs-grafana',
          kind: 'user',
        },
      ],
    },
    {
      name: 'rhacs-logs',
      roles: [
        'rhacs-logs-read',
        'rhacs-logs-write',
      ],
      subjects: [
        {
          name: 'service-account-observatorium-rhacs-logs-staging',
          kind: 'user',
        },
        {
          name: 'service-account-observatorium-rhacs-logs',
          kind: 'user',
        },
      ],
    },
    {
      name: 'rhobs',
      roles: [
        'rhobs-write',
        'rhobs-read',
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
