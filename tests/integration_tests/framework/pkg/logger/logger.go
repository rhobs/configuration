package logger

import (
	"log"
	"os"
	"path/filepath"
	"runtime"
	// "strings"
	// "golang.org/x/term"
)

type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarning
	LevelError
	LevelFatal
)

type CustomLogger struct {
	Debug     *log.Logger
	Info      *log.Logger
	Warning   *log.Logger
	Error     *log.Logger
	Fatal     *log.Logger
	Separator *log.Logger
	List      *log.Logger
	Startup   *log.Logger
	LogLevel  Level
}

var AppLog = &CustomLogger{}

func NewLogger(logLevel Level) {
	AppLog = &CustomLogger{
		Debug:     log.New(os.Stdout, "🛠️ DEBUG: ", log.Ldate|log.Ltime),
		Info:      log.New(os.Stdout, "ℹ️ INFO: ", log.Ldate|log.Ltime),
		Warning:   log.New(os.Stdout, "⚠️  WARNING: ", log.Ldate|log.Ltime),
		Error:     log.New(os.Stdout, "❗️ERROR: ", log.Ldate|log.Ltime),
		Fatal:     log.New(os.Stdout, "💀 FATAL: ", log.Ldate|log.Ltime),
		Separator: log.New(os.Stdout, "", 0),
		List:      log.New(os.Stdout, "", 0),
		Startup:   log.New(os.Stdout, "", 0),
		LogLevel:  logLevel,
	}
}

func (c *CustomLogger) LogInfo(format string, v ...interface{}) {
	if c.LogLevel <= LevelInfo {
		_, file, line, _ := runtime.Caller(1)
		c.Info.Printf("%s:%d "+format, append([]interface{}{filepath.Base(file), line}, v...)...)
	}
}

func (c *CustomLogger) LogWarning(format string, v ...interface{}) {
	if c.LogLevel <= LevelWarning {
		_, file, line, _ := runtime.Caller(1)
		c.Warning.Printf("%s:%d "+format, append([]interface{}{filepath.Base(file), line}, v...)...)
	}
}
func (c *CustomLogger) LogError(format string, v ...interface{}) {
	if c.LogLevel <= LevelError {
		_, file, line, _ := runtime.Caller(1)
		c.Error.Printf("%s:%d "+format, append([]interface{}{filepath.Base(file), line}, v...)...)
	}
}
func (c *CustomLogger) LogDebug(format string, v ...interface{}) {
	if c.LogLevel <= LevelDebug {
		_, file, line, _ := runtime.Caller(1)
		c.Debug.Printf("%s:%d "+format, append([]interface{}{filepath.Base(file), line}, v...)...)
	}
}
func (c *CustomLogger) LogFatal(format string, v ...interface{}) {
	if c.LogLevel <= LevelFatal {
		_, file, line, _ := runtime.Caller(1)
		c.Fatal.Fatalf("%s:%d "+format, append([]interface{}{filepath.Base(file), line}, v...)...)
		os.Exit(1)
	}
}
func (c *CustomLogger) LogSeperator() {
	// TODO: Implement auto line separator
	// width, _, _ := term.GetSize(int(os.Stdout.Fd()))
	// separator := strings.Repeat("▁", width)
	separator := "\n---------------------------------------------------\n"
	c.Separator.Printf(separator)
}
func (c *CustomLogger) LogStartup(cfgs ...interface{}) {
	c.Startup.Printf("🧪 RHOBS Integration-Test's\n")
	c.Startup.Printf("📇 Namespaces: %v", cfgs[0])
	if cfgs[1] != nil {
		c.Startup.Printf("👷‍♂️ Client established: True")
	} else {
		c.Startup.Printf("👷‍♂️ Client established: False")
	}
	if cfgs[2] != "" {
		c.Startup.Printf("📁 KubeConfig: %v", cfgs[2])
	}
	c.Startup.Printf("✏️ Log Level: %v", cfgs[3])
	c.Startup.Printf("⏳ Interval: %v", cfgs[4])
	c.Startup.Printf("⏳ Timeout: %v", cfgs[5])

}
func (c *CustomLogger) LogErrList(errList []error) {
	for i, err := range errList {
		c.List.Printf("➡️ Error %d: %v\n", i, err)
	}
}
