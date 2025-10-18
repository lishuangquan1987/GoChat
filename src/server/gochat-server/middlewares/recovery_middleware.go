package middlewares

import (
	"fmt"
	"gochat_server/dto"
	"log"
	"net/http"
	"runtime/debug"

	"github.com/gin-gonic/gin"
)

// RecoveryMiddleware 恢复中间件，捕获panic
func RecoveryMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// 打印错误堆栈
				log.Printf("Panic recovered: %v\n%s", err, debug.Stack())

				// 返回统一错误响应
				c.JSON(http.StatusInternalServerError, dto.ErrorResponse{
					Code:    500,
					Message: fmt.Sprintf("服务器内部错误: %v", err),
				})
				c.Abort()
			}
		}()
		c.Next()
	}
}
