package submodule

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/go-kit/log"
	v1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/yaml"
)

type repoType int

const (
	gitHub repoType = iota
	gitLab
)

type Info struct {
	Branch        string
	Commit        string // Optional: if specified, use this commit instead of parsing from branch
	SubmodulePath string
	URL           string
	PathToYAMLS   string
}

type info struct {
	Path   string
	URL    string
	Commit string
}

// Parse the Info into a git hash for the submodule
func (i Info) Parse() (string, error) {
	// Use commit if specified, otherwise fall back to branch
	ref := i.Commit
	if ref == "" {
		ref = i.Branch
	}

	// Always parse submodule commits to get the actual submodule commit hash
	infos, err := getSubmoduleCommits(i.URL, ref)
	if err != nil {
		return "", fmt.Errorf("failed to parse submodule commits: %w", err)
	}

	for _, index := range infos {
		if index.Path == i.SubmodulePath {
			return index.Commit, nil
		}
	}
	return "", fmt.Errorf("failed to find submodule commit for %s", i.SubmodulePath)
}

// FetchYAMLs fetches YAML files from the specified directory in the submodule commit and prints them
func (i Info) FetchYAMLs() ([]runtime.Object, error) {
	if i.PathToYAMLS == "" {
		return nil, fmt.Errorf("PathToYAMLS is required")
	}

	// First get the submodule commit hash
	commit, err := i.Parse()
	if err != nil {
		return nil, fmt.Errorf("failed to get submodule commit: %w", err)
	}
	logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	logger.Log("msg", "Got submodule commit", "commit", commit)

	// Get the submodule URL from .gitmodules
	submoduleURL, err := i.getSubmoduleURL()
	if err != nil {
		return nil, fmt.Errorf("failed to get submodule URL: %w", err)
	}
	logger.Log("msg", "Got submodule URL", "url", submoduleURL)

	// First check root directory to see what's in the repo
	rootFiles, err := i.fetchDirectoryContents(submoduleURL, commit, "")
	if err != nil {
		logger.Log("msg", "Failed to fetch root directory", "error", err)
	} else {
		logger.Log("msg", "Found items in root directory", "count", len(rootFiles))
		limit := len(rootFiles)
		if limit > 10 {
			limit = 10
		}
		for _, f := range rootFiles[:limit] { // limit to first 10
			logger.Log("msg", "Root directory item", "name", f.Name, "type", f.Type)
		}
	}

	// First check if operator directory exists
	operatorFiles, err := i.fetchDirectoryContents(submoduleURL, commit, "operator")
	if err != nil {
		logger.Log("msg", "Failed to fetch operator directory", "error", err)
	} else {
		logger.Log("msg", "Found items in operator directory", "count", len(operatorFiles))
		for _, f := range operatorFiles {
			logger.Log("msg", "Operator directory item", "name", f.Name, "type", f.Type)
		}
	}

	// Fetch directory contents from the submodule repository
	files, err := i.fetchDirectoryContents(submoduleURL, commit, i.PathToYAMLS)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch directory contents: %w", err)
	}
	logger.Log("msg", "Found files in directory", "count", len(files), "directory", i.PathToYAMLS)

	var objs []runtime.Object
	for _, file := range files {
		if strings.HasSuffix(strings.ToLower(file.Name), ".yaml") || strings.HasSuffix(strings.ToLower(file.Name), ".yml") {
			content, err := i.fetchFileContent(submoduleURL, commit, file.Path)
			if err != nil {
				logger.Log("msg", "Error fetching file", "file", file.Name, "error", err)
				continue
			}
			// todo we can pass specific types and filenames if needed
			var obj v1.CustomResourceDefinition
			decoder := yaml.NewYAMLOrJSONDecoder(bytes.NewBuffer(content), 100000)
			err = decoder.Decode(&obj)
			if err != nil {
				return nil, fmt.Errorf("failed to decode %s: %w", file.Name, err)
			}

			objs = append(objs, &obj)
		}
	}

	return objs, nil
}

func buildRawURL(repoURL, branch, filePath string) (string, int) {
	rt := gitHub
	if strings.Contains(repoURL, "gitlab") {
		rt = gitLab
	}

	switch rt {
	case gitHub:
		return fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s", extractRepoPath(repoURL), branch, filePath), int(gitHub)
	case gitLab:
		return fmt.Sprintf("%s/-/raw/%s/%s", repoURL, branch, filePath), int(gitLab)
	default:
		return "", 0
	}
}

func extractRepoPath(repoURL string) string {
	repoURL = strings.TrimPrefix(repoURL, "https://")
	repoURL = strings.TrimPrefix(repoURL, "http://")
	parts := strings.Split(repoURL, "/")
	if len(parts) >= 3 {
		return strings.Join(parts[1:], "/")
	}
	return repoURL
}

func fetchGitModules(repoURL, branch string) (string, int, error) {
	url, rt := buildRawURL(repoURL, branch, ".gitmodules")
	resp, err := http.Get(url)
	if err != nil {
		return "", 0, fmt.Errorf("failed to fetch .gitmodules: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", 0, fmt.Errorf("failed to fetch .gitmodules: status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", 0, fmt.Errorf("failed to read .gitmodules: %w", err)
	}

	return string(body), rt, nil
}

func parseGitModules(content string) ([]info, error) {
	var submodules []info
	var current info

	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(line, "[submodule ") {
			if current.Path != "" {
				submodules = append(submodules, current)
			}
			current = info{}
		} else if strings.Contains(line, "path = ") {
			current.Path = strings.TrimSpace(strings.Split(line, "=")[1])
		} else if strings.Contains(line, "url = ") {
			current.URL = strings.TrimSpace(strings.Split(line, "=")[1])
		}
	}

	if current.Path != "" {
		submodules = append(submodules, current)
	}

	return submodules, scanner.Err()
}

func fetchSubmoduleCommit(repoType repoType, repoURL, branch, submodulePath string) (string, error) {
	var url string

	switch repoType {
	case gitHub:
		url = fmt.Sprintf("https://api.github.com/repos/%s/contents/%s?ref=%s", extractRepoPath(repoURL), submodulePath, branch)
		resp, err := http.Get(url)
		if err != nil {
			return "", fmt.Errorf("failed to fetch submodule info: %w", err)
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", fmt.Errorf("failed to read submodule info: %w", err)
		}

		commitRegex := regexp.MustCompile(`"sha":\s*"([a-f0-9]{40})"`)
		matches := commitRegex.FindStringSubmatch(string(body))
		if len(matches) > 1 {
			return matches[1], nil
		}

	case gitLab:
		// Use GitLab API to get repository tree
		repoPath := extractRepoPath(repoURL)
		// Extract GitLab base URL from the repository URL
		gitlabBaseURL := strings.Split(repoURL, "/")[0] + "//" + strings.Split(repoURL, "/")[2]
		apiURL := fmt.Sprintf("%s/api/v4/projects/%s/repository/tree?ref=%s",
			gitlabBaseURL,
			strings.ReplaceAll(repoPath, "/", "%2F"),
			branch)

		resp, err := http.Get(apiURL)
		if err != nil {
			return "", fmt.Errorf("failed to fetch submodule info: %w", err)
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", fmt.Errorf("failed to read submodule info: %w", err)
		}

		// Look for submodule entry with type "commit" in tree API response
		submodulePattern := fmt.Sprintf(`"id":"([a-f0-9]{40})"[^}]*"name":"%s"[^}]*"type":"commit"`, regexp.QuoteMeta(submodulePath))
		commitRegex := regexp.MustCompile(submodulePattern)
		matches := commitRegex.FindStringSubmatch(string(body))
		if len(matches) > 1 {
			return matches[1], nil
		}
	}

	return "unknown", nil
}

func getSubmoduleCommits(repoURL, branch string) ([]info, error) {
	gitmodulesContent, rt, err := fetchGitModules(repoURL, branch)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch .gitmodules: %w", err)
	}

	submodules, err := parseGitModules(gitmodulesContent)
	if err != nil {
		return nil, fmt.Errorf("failed to parse .gitmodules: %w", err)
	}

	for i := range submodules {
		commit, err := fetchSubmoduleCommit(repoType(rt), repoURL, branch, submodules[i].Path)
		if err != nil {
			logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
			logger.Log("msg", "Warning: failed to get commit for submodule", "path", submodules[i].Path, "error", err)
			commit = "unknown"
		}
		submodules[i].Commit = commit
	}

	return submodules, nil
}

type FileInfo struct {
	Name string
	Path string
	Type string
}

// getSubmoduleURL gets the URL for the specified submodule from .gitmodules
func (i Info) getSubmoduleURL() (string, error) {
	// Use commit if specified, otherwise fall back to branch
	ref := i.Commit
	if ref == "" {
		if i.Branch == "" {
			return "", fmt.Errorf("either commit or branch is required to fetch .gitmodules file")
		}
		ref = i.Branch
	}

	infos, err := getSubmoduleCommits(i.URL, ref)
	if err != nil {
		return "", fmt.Errorf("failed to get submodule commits: %w", err)
	}

	for _, submodule := range infos {
		if submodule.Path == i.SubmodulePath {
			return submodule.URL, nil
		}
	}
	return "", fmt.Errorf("submodule %s not found", i.SubmodulePath)
}

// fetchDirectoryContents fetches the contents of a directory from a repository
func (i Info) fetchDirectoryContents(repoURL, commit, path string) ([]FileInfo, error) {
	var files []FileInfo
	var apiURL string

	repoPath := extractRepoPath(repoURL)

	if strings.Contains(repoURL, "github.com") {
		apiURL = fmt.Sprintf("https://api.github.com/repos/%s/contents/%s?ref=%s", repoPath, path, commit)
	} else if strings.Contains(repoURL, "gitlab") {
		gitlabBaseURL := strings.Split(repoURL, "/")[0] + "//" + strings.Split(repoURL, "/")[2]
		apiURL = fmt.Sprintf("%s/api/v4/projects/%s/repository/tree?ref=%s&path=%s",
			gitlabBaseURL,
			strings.ReplaceAll(repoPath, "/", "%2F"),
			commit,
			path)
	} else {
		return nil, fmt.Errorf("unsupported repository type")
	}

	resp, err := http.Get(apiURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch directory contents: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory contents: %w", err)
	}

	if strings.Contains(repoURL, "github.com") {
		// GitHub API returns array of objects with "name", "path", "type"
		nameRegex := regexp.MustCompile(`"name":\s*"([^"]+)"`)
		pathRegex := regexp.MustCompile(`"path":\s*"([^"]+)"`)
		typeRegex := regexp.MustCompile(`"type":\s*"([^"]+)"`)

		names := nameRegex.FindAllStringSubmatch(string(body), -1)
		paths := pathRegex.FindAllStringSubmatch(string(body), -1)
		types := typeRegex.FindAllStringSubmatch(string(body), -1)

		for i := 0; i < len(names) && i < len(paths) && i < len(types); i++ {
			files = append(files, FileInfo{
				Name: names[i][1],
				Path: paths[i][1],
				Type: types[i][1],
			})
		}
	} else {
		// GitLab API returns array of objects with "name", "path", "type"
		nameRegex := regexp.MustCompile(`"name":\s*"([^"]+)"`)
		pathRegex := regexp.MustCompile(`"path":\s*"([^"]+)"`)
		typeRegex := regexp.MustCompile(`"type":\s*"([^"]+)"`)

		names := nameRegex.FindAllStringSubmatch(string(body), -1)
		paths := pathRegex.FindAllStringSubmatch(string(body), -1)
		types := typeRegex.FindAllStringSubmatch(string(body), -1)

		for i := 0; i < len(names) && i < len(paths) && i < len(types); i++ {
			files = append(files, FileInfo{
				Name: names[i][1],
				Path: paths[i][1],
				Type: types[i][1],
			})
		}
	}

	return files, nil
}

// fetchFileContent fetches the content of a specific file from a repository
func (i Info) fetchFileContent(repoURL, commit, filePath string) ([]byte, error) {
	var rawURL string

	repoPath := extractRepoPath(repoURL)

	if strings.Contains(repoURL, "github.com") {
		rawURL = fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s", repoPath, commit, filePath)
	} else if strings.Contains(repoURL, "gitlab") {
		rawURL = fmt.Sprintf("%s/-/raw/%s/%s", repoURL, commit, filePath)
	} else {
		return nil, fmt.Errorf("unsupported repository type")
	}

	resp, err := http.Get(rawURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch file content: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read file content: %w", err)
	}
	return body, nil
}
