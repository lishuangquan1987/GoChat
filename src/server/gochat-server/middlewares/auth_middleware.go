package middlewares

import (
	"net/http"
	"strings"

	authmanager "gochat_server/auth_manager"
	"gochat_server/dto"

	"github.com/gin-gonic/gin"
)

// AuthMiddleware JWT认证中间件
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 从 Header 中获取 token
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
				Code:    401,
				Message: "未提供认证token",
			})
			c.Abort()
			return
		}

		// 检查 Bearer 前缀
		parts := strings.SplitN(authHeader, " ", 2)
		if !(len(parts) == 2 && parts[0] == "Bearer") {
			c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
				Code:    401,
				Message: "token格式错误",
			})
			c.Abort()
			return
		}

		token := parts[1]

		// 解析 token
		claims, err := authmanager.ParseToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
				Code:    401,
				Message: "无效的token",
			})
			c.Abort()
			return
		}

		// 将用户信息存储到上下文中
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)

		c.Next()
	}
}

// GetUserID 从上下文中获取用户ID
func GetUserID(c *gin.Context) (int, bool) {
	userID, exists := c.Get("user_id")
	if !exists {
		return 0, false
	}
	id, ok := userID.(int)
	return id, ok
}
