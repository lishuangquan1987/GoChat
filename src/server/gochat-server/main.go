package main

import (
	"gochat_server/configs"
	"gochat_server/routers"
	"gochat_server/services"
	wsmanager "gochat_server/ws_manager"
	"log"

	"github.com/gin-gonic/gin"
)

func main() {
	// 初始化 MinIO
	err := services.InitMinIO()
	if err != nil {
		log.Printf("Warning: MinIO initialization failed: %v", err)
		log.Println("File upload功能将不可用")
	} else {
		log.Println("MinIO initialized successfully")
	}

	r := gin.Default()
	r.GET("/ws", func(c *gin.Context) {
		// 处理 WebSocket 连接
		wsmanager.HandleWebSocketConnection(c.Writer, c.Request)
	})

	routers.RegisterRoutes(r)

	port := ":" + configs.Cfg.Server.Port
	log.Printf("Server starting on %s\n", port)
	r.Run(port) // 启动服务
}
