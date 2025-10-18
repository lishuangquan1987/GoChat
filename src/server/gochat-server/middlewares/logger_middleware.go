package middlewares

import (
	"bytes"
	"io"
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// LoggerMiddleware 日志中间件 - 记录请求和响应信息
func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 开始时间
		startTime := time.Now()

		// 读取请求体（用于日志记录）
		var requestBody []byte
		if c.Request.Body != nil {
			requestBody, _ = io.ReadAll(c.Request.Body)
			// 重新设置请求体，以便后续处理器可以读取
			c.Request.Body = io.NopCloser(bytes.NewBuffer(requestBody))
		}

		// 处理请求
		c.Next()

		// 结束时间
		endTime := time.Now()

		// 执行时间
		latencyTime := endTime.Sub(startTime)

		// 请求方式
		reqMethod := c.Request.Method

		// 请求路由
		reqUri := c.Request.RequestURI

		// 状态码
		statusCode := c.Writer.Status()

		// 请求IP
		clientIP := c.ClientIP()

		// User-Agent
		userAgent := c.Request.UserAgent()

		// 响应大小
		responseSize := c.Writer.Size()

		// 构建日志信息
		if statusCode >= 400 {
			// 错误请求，记录更详细的信息
			log.Printf("[ERROR] %s | %3d | %13v | %15s | %-7s %s | Size: %d | UA: %s",
				startTime.Format("2006/01/02 15:04:05"),
				statusCode,
				latencyTime,
				clientIP,
				reqMethod,
				reqUri,
				responseSize,
				userAgent,
			)
			// 如果有错误，记录错误信息
			if len(c.Errors) > 0 {
				log.Printf("  └─ Errors: %s", c.Errors.String())
			}
		} else {
			// 正常请求
			log.Printf("[INFO] %s | %3d | %13v | %15s | %-7s %s | Size: %d",
				startTime.Format("2006/01/02 15:04:05"),
				statusCode,
				latencyTime,
				clientIP,
				reqMethod,
				reqUri,
				responseSize,
			)
		}
	}
}
