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
        // OpenShift Logging Team
        {
          name: 'rhn-engineering-aconway',
          kind: 'user',
        },
        {
          name: 'brejones',
          kind: 'user',
        },
        {
          name: 'cvogel1',
          kind: 'user',
        },
        {
          name: 'ewolinet@redhat.com',
          kind: 'user',
        },
        {
          name: 'jcantril@redhat.com',
          kind: 'user',
        },
        {
          name: 'ptsiraki@redhat.com',
          kind: 'user',
        },
        {
          name: 'vparfono',
          kind: 'user',
        },
        {
          name: 'vimalkum',
          kind: 'user',
        },
        {
          name: 'sasagarw',
          kind: 'user',
        },
        {
          name: 'ikarpukh',
          kind: 'user',
        },
        {
          name: 'eraichst',
          kind: 'user',
        },
        // OpenShift DPTP team
        {
          name: 'dmace@redhat.com',
          kind: 'user',
        },
        {
          name: 'sbatsche@redhat.com',
          kind: 'user',
        },
        {
          name: 'vrutkovs@redhat.com',
          kind: 'user',
        },
        {
          name: 'trking',
          kind: 'user',
        },
      ],
    },
  ],
}
