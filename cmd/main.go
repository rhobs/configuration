package main

import (
	"fmt"

	"github.com/rhobs/configuration/internal/submodule"
)

func main() {
	repoURL := "https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage"
	branch := "release-6.3"
	submodulePath := "loki-operator"

	fmt.Printf("Fetching submodule information from: %s (branch: %s)\n", repoURL, branch)

	// Use the Info struct and Parse method from fetch.go
	info := submodule.Info{
		Branch:        branch,
		Commit:        "7d0d587f542079fca8e2dd5dbd6e9e47bbad50ab", // Use specific commit instead of parsing from branch
		SubmodulePath: submodulePath,
		URL:           repoURL,
		PathToYAMLS:   "operator/config/crd/bases",
	}

	commit, err := info.Parse()
	if err != nil {
		fmt.Printf("Error getting submodule commit: %v\n", err)
		return
	}

	fmt.Printf("Submodule SubmodulePath: %s\n", info.SubmodulePath)
	fmt.Printf("Repository URL: %s\n", info.URL)
	fmt.Printf("Branch: %s\n", info.Branch)
	fmt.Printf("Commit Hash: %s\n", commit)

	// Fetch and print YAML files from the specified directory
	fmt.Printf("\nFetching YAML files from %s...\n", info.PathToYAMLS)
}
