package routers

import (
	"gochat_server/controllers"
	"gochat_server/middlewares"

	"github.com/gin-gonic/gin"
)

// RegisterRoutes 注册所有路由
func RegisterRoutes(r *gin.Engine) {
	// 应用全局中间件（按顺序）
	r.Use(middlewares.RecoveryMiddleware()) // 1. 恢复panic
	r.Use(middlewares.CORSMiddleware())     // 2. 跨域处理
	r.Use(middlewares.LoggerMiddleware())   // 3. 日志记录

	// API 路由组
	api := r.Group("/api")
	{
		// 用户相关路由（无需认证）
		user := api.Group("/user")
		{
			user.POST("/register", controllers.Register)
			user.POST("/login", controllers.Login)
		}

		// 需要认证的用户路由
		userAuth := api.Group("/user")
		userAuth.Use(middlewares.AuthMiddleware())
		{
			userAuth.GET("/profile", controllers.GetProfile)
			userAuth.PUT("/profile", controllers.UpdateProfile)
			userAuth.POST("/logout", controllers.Logout)
		}

		// 好友相关路由（需要认证）
		friends := api.Group("/friends")
		friends.Use(middlewares.AuthMiddleware())
		{
			friends.GET("", controllers.GetFriendList)
			friends.POST("/request", controllers.SendFriendRequest)
			friends.POST("/accept", controllers.AcceptFriendRequest)
			friends.POST("/reject", controllers.RejectFriendRequest)
			friends.GET("/requests", controllers.GetFriendRequests)
			friends.GET("/requests/sent", controllers.GetSentFriendRequests)
			friends.DELETE("/:friendId", controllers.DeleteFriend)
		}

		// 消息相关路由（需要认证）
		messages := api.Group("/messages")
		messages.Use(middlewares.AuthMiddleware())
		{
			messages.POST("/send", controllers.SendMessage)
			messages.GET("/history", controllers.GetChatHistory)
			messages.GET("/conversations", controllers.GetConversationList)
			messages.GET("/offline", controllers.GetOfflineMessages)
			messages.POST("/upload", controllers.UploadFile)
			messages.POST("/delivered", controllers.MarkMessageDelivered)
			messages.POST("/read", controllers.MarkMessageRead)
			messages.GET("/status", controllers.GetMessageStatus)
		}

		// 群组相关路由（需要认证）
		groups := api.Group("/groups")
		groups.Use(middlewares.AuthMiddleware())
		{
			groups.POST("", controllers.CreateGroup)
			groups.GET("", controllers.GetGroupList)
			groups.GET("/:groupId", controllers.GetGroupDetail)
			groups.POST("/:groupId/members", controllers.AddGroupMembers)
			groups.DELETE("/:groupId/members/:userId", controllers.RemoveGroupMember)
			groups.GET("/:groupId/members", controllers.GetGroupMembers)
		}

		// 性能监控相关路由（需要认证）
		performance := api.Group("/performance")
		performance.Use(middlewares.AuthMiddleware())
		{
			performance.GET("/stats", controllers.GetPerformanceStats)
			performance.GET("/optimization", controllers.GetDatabaseOptimizationSuggestions)
			performance.POST("/cache/warmup", controllers.WarmupCache)
			performance.GET("/cache/stats", controllers.GetCacheStats)
		}

		// 免打扰相关路由（需要认证）
		dnd := api.Group("/donotdisturb")
		dnd.Use(middlewares.AuthMiddleware())
		{
			dnd.POST("/private", controllers.SetPrivateDoNotDisturb)
			dnd.POST("/group", controllers.SetGroupDoNotDisturb)
			dnd.POST("/global", controllers.SetGlobalDoNotDisturb)
			dnd.DELETE("/private/:targetUserId", controllers.RemovePrivateDoNotDisturb)
			dnd.DELETE("/group/:targetGroupId", controllers.RemoveGroupDoNotDisturb)
			dnd.DELETE("/global", controllers.RemoveGlobalDoNotDisturb)
			dnd.GET("/settings", controllers.GetDoNotDisturbSettings)
			dnd.GET("/status", controllers.CheckDoNotDisturbStatus)
		}
	}
}
