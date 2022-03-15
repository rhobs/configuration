function(params) {
  assert std.isString(params.url),

  remote_write: [
    {
      url: params.url,
      name: 'receive-rhobs',
      headers: {
        'THANOS-TENANT': '0fc2b00e-201b-4c17-b9f2-19d91adc4fd2',
      },
      write_relabel_configs: [
        {
          source_labels: ['tenant_id'],
          regex: '0fc2b00e-201b-4c17-b9f2-19d91adc4fd2',
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
    {
      url: params.url,
      name: 'receive-dptp',
      headers: {
        'THANOS-TENANT': 'AC879303-C60F-4D0D-A6D5-A485CFD638B8',
      },
      write_relabel_configs: [
        {
          source_labels: ['tenant_id'],
          regex: 'AC879303-C60F-4D0D-A6D5-A485CFD638B8',
          action: 'keep',
        },
      ],
    },
    {
      url: params.url,
      name: 'receive-osd',
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
      name: 'receive-managedkafka',
      headers: {
        'THANOS-TENANT': '63e320cd-622a-4d05-9585-ffd48342633e',
      },
      write_relabel_configs: [
        {
          source_labels: ['tenant_id'],
          regex: '63e320cd-622a-4d05-9585-ffd48342633e',
          action: 'keep',
        },
      ],
    },
  ],
}
