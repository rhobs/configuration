package observatorium

import (
	"bytes"
	"fmt"
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

func NewDefaultTemplateYAML(encoder encoding.Encoder, resourceName string) *templateYAML {
	prefix := fmt.Sprintf(`kind: (Deployment|StatefulSet).*?name: %s.*?`, resourceName)
	return &templateYAML{
		encoder: encoder,
		replacements: [][]string{
			// (?s) is a flag that allows . to match newlines
			// .*? is a non-greedy match of any character
			// these matchers assume that the main container (thanos) is the first container in the pod
			{fmt.Sprintf(`(?s)(%scontainers:\n.*?limits:.*?memory: )\S+`, prefix), "${1}$${MEMORY_LIMIT}"},     // replace memory limit
			{fmt.Sprintf(`(?s)(%scontainers:\n.*?requests:.*?memory: )\S+`, prefix), "${1}$${MEMORY_REQUEST}"}, // replace memory request
			{fmt.Sprintf(`(?s)(%scontainers:\n.*?limits:.*?cpu: )\S+`, prefix), "${1}$${CPU_REQUEST}"},         // replace cpu request
			{fmt.Sprintf(`(?s)(%sreplicas: )\d+`, prefix), "${1}$${{REPLICAS}}"},                               // replace replicas
			{fmt.Sprintf(`(?s)(%scontainers:\n.*?\s+--log\.level=)\w+`, prefix), "${1}$${LOG_LEVEL}"},          // replace thanos log level
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
