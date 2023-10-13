package observatorium

import (
	"bytes"
	"io"
	"regexp"

	"github.com/bwplotka/mimic/encoding"
)

// statusRemoveEncoder is a YAML encoder wrapper that allows cleaning of the output.
// Wihtout this, the manifests would contain a status section that is not needed.
type statusRemoveEncoder struct {
	encoder encoding.Encoder
	reader  io.Reader
}

func (c *statusRemoveEncoder) Read(p []byte) (n int, err error) {
	if c.reader == nil {
		yamlData, err := io.ReadAll(c.encoder)
		if err != nil {
			panic(err)
		}

		// Remove status sections from manifests
		yamlData = regexp.MustCompile(`(?m)^( {2})status:\n( {4}.*\n)+`).ReplaceAll(yamlData, []byte{})
		yamlData = regexp.MustCompile(`(?m)^ +status: \{\}\n`).ReplaceAll(yamlData, []byte{})
		c.reader = bytes.NewBuffer(yamlData)
	}

	return c.reader.Read(p)
}

func (c *statusRemoveEncoder) EncodeComment(lines string) []byte {
	return c.encoder.EncodeComment(lines)
}

// templateYAML is a YAML encoder wrapper that allows templating of the output.
// This is used when the target value is not typed as a string in Go.
type templateYAML struct {
	encoder      encoding.Encoder
	reader       io.Reader
	replacements [][]string // regexp, replace tuples
}

func NewDefaultTemplateYAML(encoder encoding.Encoder) *templateYAML {
	return &templateYAML{
		encoder: encoder,
		replacements: [][]string{
			// (?s) is a flag that allows . to match newlines
			// .*? is a non-greedy match of any character
			// these matchers assume that the main container (thanos) is the first container in the pod
			{`(?s)(containers:\n.*?limits:.*?memory: )\S+`, "${1}$${THANOS_MEMORY_LIMIT}"},        // replace memory limit
			{`(?s)(containers:\n.*?requests:.*?memory: )\S+`, "${1}$${THANOS_MEMORY_REQUEST}"},    // replace memory request
			{`(?s)(containers:\n.*?limits:.*?cpu: )\S+`, "${1}$${THANOS_CPU_REQUEST}"},            // replace cpu request
			{`(?s)(kind: (Deployment|StatefulSet).*?replicas: )\d+`, "${1}$${{THANOS_REPLICAS}}"}, // replace replicas
			{`(?s)(containers:\n.*?\s+--log\.level=)\w+`, "${1}$${THANOS_LOG_LEVEL}"},             // replace thanos log level
		},
	}
}

func (c *templateYAML) Read(p []byte) (n int, err error) {
	if c.reader == nil {
		yamlData, err := io.ReadAll(c.encoder)
		if err != nil {
			panic(err)
		}

		for _, r := range c.replacements {
			yamlData = regexp.MustCompile(r[0]).ReplaceAll(yamlData, []byte(r[1]))
		}

		c.reader = bytes.NewBuffer(yamlData)
	}

	return c.reader.Read(p)
}

func (c *templateYAML) EncodeComment(lines string) []byte {
	return c.encoder.EncodeComment(lines)
}

func (c *templateYAML) AddReplacement(reg, replace string) {
	c.replacements = append(c.replacements, []string{reg, replace})
}
