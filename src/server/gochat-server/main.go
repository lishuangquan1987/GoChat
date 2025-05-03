package main

import (
	wsmanager "gochat-server/ws_manager"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	r.GET("/ws", func(c *gin.Context) {
		// 处理 WebSocket 连接
		wsmanager.HandleWebSocketConnection(c.Writer, c.Request)
	})
	
}
