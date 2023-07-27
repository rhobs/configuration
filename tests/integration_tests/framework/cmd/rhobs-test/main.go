package main

import (
	"strings"

	"flag"
	"time"

	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/client"
	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/deployment"
	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"
	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/service"
	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/statefulset"
	"k8s.io/client-go/kubernetes"
)

const (
	defaultInterval  = 1 * time.Minute
	defaultTimeout   = 5 * time.Minute
	defaultNamespace = "default"
)

var (
	namespace  string
	kubeconfig string
	loglevel   string
	interval   time.Duration
	timeout    time.Duration
	errList    []error
)

type Config struct {
	NsList     []string
	KubeConfig string
	ClientSet  kubernetes.Interface
	LogLevel   string
	Interval   time.Duration
	Timeout    time.Duration
}

func init() {
	flag.StringVar(&namespace, "namespaces", defaultNamespace, "Namespace to be monitored")
	flag.StringVar(&kubeconfig, "kubeconfig", "", "path of kubeconfig file")
	flag.DurationVar(&interval, "interval", defaultInterval, "Wait before retry status check again")
	flag.DurationVar(&timeout, "timeout", defaultTimeout, "Timeout for retry")
	flag.StringVar(&loglevel, "loglevel", "", "log level")
	flag.Parse()
	if loglevel == "" {
		loglevel = "info"
		logger.NewLogger(logger.LevelInfo)
	} else if loglevel == "debug" {
		logger.NewLogger(logger.LevelDebug)
	} else if loglevel == "error" {
		logger.NewLogger(logger.LevelError)
	} else if loglevel == "info" {
		logger.NewLogger(logger.LevelInfo)
	} else if loglevel == "warn" {
		logger.NewLogger(logger.LevelWarning)
	} else {
		logger.NewLogger(logger.LevelFatal)
		logger.AppLog.LogFatal("invalid log level. supported levels are warn, info, error, debug")
	}
}

func main() {
	cfg := &Config{
		NsList:     strings.Split(namespace, ","),
		ClientSet:  client.GetClient(kubeconfig),
		KubeConfig: kubeconfig,
		LogLevel:   loglevel,
		Interval:   interval,
		Timeout:    timeout,
	}
	logger.AppLog.LogStartup(cfg.NsList, cfg.ClientSet, cfg.KubeConfig, cfg.LogLevel, cfg.Interval, cfg.Timeout)
	err := deployment.CheckDeployments(cfg.NsList, cfg.ClientSet, interval, timeout)
	if err != nil {
		logger.AppLog.LogError("cannot validate deployements. reason: %v\n", err)
		errList = append(errList, err)
	}
	err = statefulset.CheckStatefulSets(cfg.NsList, cfg.ClientSet, interval, timeout)
	if err != nil {
		logger.AppLog.LogError("cannot validate statefulsets. reason: %v\n", err)
		errList = append(errList, err)
	}
	err = service.CheckServices(cfg.NsList, cfg.ClientSet, interval, timeout)
	if err != nil {
		logger.AppLog.LogError("cannot validate services. reason: %v\n", err)
		errList = append(errList, err)
	}
	if len(errList) > 0 {
		//TODO: Print out the list of errors
		logger.AppLog.LogFatal("integration-tests failed. See the above list of errors")
	}
}
