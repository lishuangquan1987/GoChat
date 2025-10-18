package main

import (
	"gochat_server/configs"
	"gochat_server/routers"
	"gochat_server/services"
	"gochat_server/utils"
	wsmanager "gochat_server/ws_manager"
	"log"

	"github.com/gin-gonic/gin"
)

func main() {
	// 初始化日志系统
	// 可以配置日志目录和级别，例如: utils.InitLogger("logs", utils.INFO)
	// 这里使用默认配置（输出到标准输出）
	utils.Info("GoChat Server starting...")

	// 初始化 MinIO
	err := services.InitMinIO()
	if err != nil {
		utils.Warn("MinIO initialization failed: %v", err)
		utils.Warn("File upload功能将不可用")
	} else {
		utils.Info("MinIO initialized successfully")
	}

	// 初始化 Redka 缓存
	err = services.InitCache()
	if err != nil {
		utils.Warn("Redka cache initialization failed: %v", err)
		utils.Warn("Cache功能将不可用")
	} else {
		utils.Info("Redka cache initialized successfully")
	}

	// 确保程序退出时关闭缓存连接
	defer func() {
		if err := services.CloseCache(); err != nil {
			utils.Error("Failed to close cache: %v", err)
		}
	}()

	// 创建Gin引擎（不使用默认中间件）
	r := gin.New()

	// WebSocket路由（不需要经过所有中间件）
	r.GET("/ws", func(c *gin.Context) {
		// 处理 WebSocket 连接
		wsmanager.HandleWebSocketConnection(c.Writer, c.Request)
	})

	// 注册所有路由和中间件
	routers.RegisterRoutes(r)

	port := ":" + configs.Cfg.Server.Port
	utils.Info("Server starting on port %s", configs.Cfg.Server.Port)
	log.Printf("Server starting on %s\n", port)

	// 启动服务
	if err := r.Run(port); err != nil {
		utils.Fatal("Failed to start server: %v", err)
	}
}
