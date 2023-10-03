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
		ret, err := io.ReadAll(c.encoder)
		if err != nil {
			panic(err)
		}

		// Remove status sections from manifests
		c.reader = bytes.NewBuffer(regexp.MustCompile(`(?m)^( {2})status:\n( {4}.*\n)+`).ReplaceAll(ret, []byte{}))
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

func (c *templateYAML) Read(p []byte) (n int, err error) {
	if c.reader == nil {
		ret, err := io.ReadAll(c.encoder)
		if err != nil {
			panic(err)
		}

		for _, r := range c.replacements {
			ret = regexp.MustCompile(r[0]).ReplaceAll(ret, []byte(r[1]))
		}

		c.reader = bytes.NewBuffer(ret)
	}

	return c.reader.Read(p)
}

func (c *templateYAML) EncodeComment(lines string) []byte {
	return c.encoder.EncodeComment(lines)
}

func (c *templateYAML) AddReplacement(reg, replace string) {
	c.replacements = append(c.replacements, []string{reg, replace})
}
