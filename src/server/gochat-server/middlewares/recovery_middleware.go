package middlewares

import (
	"fmt"
	"gochat_server/dto"
	"log"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/gin-gonic/gin"
)

// RecoveryMiddleware 恢复中间件，捕获panic并记录详细信息
func RecoveryMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// 记录panic发生的时间
				timestamp := time.Now().Format("2006/01/02 15:04:05")

				// 获取堆栈信息
				stack := debug.Stack()

				// 记录详细的panic信息
				log.Printf("[PANIC RECOVERED] %s\n", timestamp)
				log.Printf("Request: %s %s\n", c.Request.Method, c.Request.RequestURI)
				log.Printf("Client IP: %s\n", c.ClientIP())
				log.Printf("User-Agent: %s\n", c.Request.UserAgent())
				log.Printf("Error: %v\n", err)
				log.Printf("Stack Trace:\n%s\n", stack)

				// 构建错误响应
				errorMsg := "服务器内部错误"
				errorDetail := fmt.Sprintf("%v", err)

				// 返回统一错误响应
				c.JSON(http.StatusInternalServerError, dto.NewErrorResponse(
					dto.CodeInternalError,
					errorMsg,
					fmt.Errorf("%s", errorDetail),
				))

				// 终止后续处理
				c.Abort()
			}
		}()
		c.Next()
	}
}
