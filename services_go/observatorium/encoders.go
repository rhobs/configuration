package observatorium

import (
	"bytes"
	"fmt"
	"io"
	"regexp"
	"strconv"

	"github.com/bwplotka/mimic/encoding"
	templatev1 "github.com/openshift/api/template/v1"
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
	encoder           encoding.Encoder
	reader            io.Reader
	replacements      [][]string // regexp, replace tuples
	resourceName      string
	templateVarPrefix string
	templateParams    []templatev1.Parameter
}

func NewStdTemplateYAML(resourceName, templateVarPrefix string) *templateYAML {
	prefix := fmt.Sprintf(`kind: (Deployment|StatefulSet).*? name: %s\n.*?`, resourceName)
	ret := &templateYAML{
		replacements: [][]string{
			// (?s) is a flag that allows . to match newlines
			// .*? is a non-greedy match of any character
			// these matchers assume that the main container is the first container in the pod
			{fmt.Sprintf(`(?s)(%scontainers:\n.*? limits:.*? memory: )(?P<value>\S+)`, prefix), templateVarPrefix + "_MEMORY_LIMIT"},      // replace memory limit
			{fmt.Sprintf(`(?s)(%s containers:\n.*? requests:.*? memory: )(?P<value>\S+)`, prefix), templateVarPrefix + "_MEMORY_REQUEST"}, // replace memory request
			{fmt.Sprintf(`(?s)(%s containers:\n.*? requests:.*? cpu: )(?P<value>\S+)`, prefix), templateVarPrefix + "_CPU_REQUEST"},       // replace cpu request
			{fmt.Sprintf(`(?s)(%s replicas: )(?P<value>\S+)`, prefix), templateVarPrefix + "_REPLICAS"},                                   // replace replicas
		},
		resourceName:      resourceName,
		templateVarPrefix: templateVarPrefix,
	}
	ret.templateParams = []templatev1.Parameter{
		{
			Name: fmt.Sprintf("%s_MEMORY_LIMIT", templateVarPrefix),
		},
		{
			Name: fmt.Sprintf("%s_MEMORY_REQUEST", templateVarPrefix),
		},
		{
			Name: fmt.Sprintf("%s_CPU_REQUEST", templateVarPrefix),
		},
		{
			Name: fmt.Sprintf("%s_REPLICAS", templateVarPrefix),
		},
	}
	return ret
}

func (c *templateYAML) WithLogLevel() *templateYAML {
	prefix := fmt.Sprintf(`kind: (Deployment|StatefulSet).*? name: %s\n.*?`, c.resourceName)
	c.replacements = append(c.replacements, []string{fmt.Sprintf(`(?s)(%s containers:\n.*?\s+--log\.level=)(?P<value>\w+)`, prefix), c.templateVarPrefix + "_LOG_LEVEL"})
	c.templateParams = append(c.templateParams, templatev1.Parameter{
		Name: fmt.Sprintf("%s_LOG_LEVEL", c.templateVarPrefix),
	})
	return c
}

func (c *templateYAML) TemplateParams() []templatev1.Parameter {
	return c.templateParams
}

func (c *templateYAML) Wrap(encoder encoding.Encoder) encoding.Encoder {
	c.encoder = encoder
	return c
}

func (c *templateYAML) Read(p []byte) (n int, err error) {
	if c.reader == nil {
		yamlData, err := io.ReadAll(c.encoder)
		if err != nil {
			panic(err)
		}

		for _, r := range c.replacements {
			replRegex := regexp.MustCompile(r[0])

			// extract the value from the match that we want to replace
			// the value is named "value" in the regex
			// it will be injected into the template paramter's value
			valueMatch := replRegex.FindStringSubmatch(string(yamlData))
			if valueMatch == nil {
				panic(fmt.Sprintf("replacement not found: %s\n", r[0]))
			}

			var value string
			names := replRegex.SubexpNames()
			for i, v := range names {
				if v == "value" {
					if i != 3 {
						panic("value is not the third subexpression")
					}
					value = valueMatch[i]
				}
			}

			if value == "" {
				panic(fmt.Sprintf("replacement value not found: %s\n", r[0]))
			}

			// if the value is a number, replace it with a string
			// because the template engine expects string values
			dataReplace := fmt.Sprintf("${1}$${%s}", r[1])
			if _, err := strconv.Atoi(value); err == nil {
				value = fmt.Sprintf(`"%s"`, value)
				dataReplace = fmt.Sprintf("${1}$${{%s}}", r[1])
			}

			// replace the template parameter's value
			paramMatch := regexp.MustCompile(fmt.Sprintf(`(?s)(\nparameters:\n.*? name: %s)`, r[1]))
			yamlData = paramMatch.ReplaceAll(yamlData, []byte(fmt.Sprintf("${1}\n  value: %s", value)))

			// replace the value in the manifest with the template parameter
			yamlData = replRegex.ReplaceAll(yamlData, []byte(dataReplace))
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
