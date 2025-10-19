package controllers

import (
	"gochat_server/services"
	"gochat_server/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

// GetPerformanceStats 获取性能统计信息
func GetPerformanceStats(c *gin.Context) {
	stats := services.GetPerformanceStats()
	
	utils.RespondSuccess(c, stats)
}

// GetDatabaseOptimizationSuggestions 获取数据库优化建议
func GetDatabaseOptimizationSuggestions(c *gin.Context) {
	suggestions := services.OptimizeDatabase()
	indexSuggestions := services.GetDatabaseIndexSuggestions()
	
	response := map[string]interface{}{
		"connection_pool_suggestions": suggestions,
		"index_suggestions":          indexSuggestions,
	}
	
	utils.RespondSuccess(c, response)
}

// WarmupCache 预热缓存
func WarmupCache(c *gin.Context) {
	err := services.WarmupCache()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "缓存预热失败: " + err.Error()})
		return
	}
	
	utils.RespondSuccess(c, map[string]string{
		"message": "缓存预热完成",
	})
}

// GetCacheStats 获取缓存统计信息
func GetCacheStats(c *gin.Context) {
	stats := services.GetCacheStats()
	utils.RespondSuccess(c, stats)
}