{
  groups: [
    {
      name: 'test-recording-rule-via-ci',
      interval: '30s',
      rules: [
        {
          record: 'TestRecordingRuleCI',
          expr: 'vector(1)',
        },
      ],
    },
  ],
}
