function(params) {
  assert std.isString(params.url),

  remote_write: [
    {
      url: params.url,
      name: 'receive-rhobs',
      headers: {
        'THANOS-TENANT': '770c1124-6ae8-4324-a9d4-9ce08590094b',
      },
      write_relabel_configs: [
        {
          source_labels: ['tenant_id'],
          regex: '770c1124-6ae8-4324-a9d4-9ce08590094b',
          action: 'keep',
        },
      ],
    },
    {
      url: params.url,
      name: 'receive-telemeter',
      headers: {
        'THANOS-TENANT': 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
      },
      write_relabel_configs: [
        {
          source_labels: ['tenant_id'],
          regex: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
          action: 'keep',
        },
      ],
    },
  ],
}
