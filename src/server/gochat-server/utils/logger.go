package utils

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"
)

// LogLevel 日志级别
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
	FATAL
)

var (
	logLevelNames = map[LogLevel]string{
		DEBUG: "DEBUG",
		INFO:  "INFO",
		WARN:  "WARN",
		ERROR: "ERROR",
		FATAL: "FATAL",
	}

	// 当前日志级别
	currentLogLevel = INFO

	// 日志文件
	logFile *os.File
)

// InitLogger 初始化日志系统
func InitLogger(logDir string, level LogLevel) error {
	currentLogLevel = level

	// 创建日志目录
	if logDir != "" {
		if err := os.MkdirAll(logDir, 0755); err != nil {
			return fmt.Errorf("创建日志目录失败: %v", err)
		}

		// 创建日志文件（按日期命名）
		logFileName := fmt.Sprintf("gochat_%s.log", time.Now().Format("2006-01-02"))
		logFilePath := filepath.Join(logDir, logFileName)

		file, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			return fmt.Errorf("打开日志文件失败: %v", err)
		}

		logFile = file
		log.SetOutput(file)
	}

	return nil
}

// CloseLogger 关闭日志文件
func CloseLogger() {
	if logFile != nil {
		logFile.Close()
	}
}

// logMessage 记录日志消息
func logMessage(level LogLevel, format string, args ...interface{}) {
	if level < currentLogLevel {
		return
	}

	timestamp := time.Now().Format("2006/01/02 15:04:05")
	levelName := logLevelNames[level]
	message := fmt.Sprintf(format, args...)

	logLine := fmt.Sprintf("[%s] [%s] %s", timestamp, levelName, message)
	log.Println(logLine)
}

// Debug 调试日志
func Debug(format string, args ...interface{}) {
	logMessage(DEBUG, format, args...)
}

// Info 信息日志
func Info(format string, args ...interface{}) {
	logMessage(INFO, format, args...)
}

// Warn 警告日志
func Warn(format string, args ...interface{}) {
	logMessage(WARN, format, args...)
}

// Error 错误日志
func Error(format string, args ...interface{}) {
	logMessage(ERROR, format, args...)
}

// Fatal 致命错误日志（会退出程序）
func Fatal(format string, args ...interface{}) {
	logMessage(FATAL, format, args...)
	os.Exit(1)
}

// LogRequest 记录HTTP请求
func LogRequest(method, uri, clientIP string, statusCode int, latency time.Duration) {
	Info("HTTP Request: %s %s | IP: %s | Status: %d | Latency: %v",
		method, uri, clientIP, statusCode, latency)
}

// LogError 记录错误信息
func LogError(context string, err error) {
	if err != nil {
		Error("%s: %v", context, err)
	}
}

// LogWebSocket 记录WebSocket事件
func LogWebSocket(event string, userId int, details string) {
	Info("WebSocket [%s] UserID: %d | %s", event, userId, details)
}

// LogDatabase 记录数据库操作
func LogDatabase(operation string, table string, duration time.Duration, err error) {
	if err != nil {
		Error("Database [%s] Table: %s | Duration: %v | Error: %v",
			operation, table, duration, err)
	} else {
		Debug("Database [%s] Table: %s | Duration: %v",
			operation, table, duration)
	}
}
