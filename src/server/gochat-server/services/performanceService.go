package services

import (
	"context"
	"database/sql"
	"fmt"
	"gochat_server/configs"
	"gochat_server/ent"
	"gochat_server/utils"
	"runtime"
	"time"
)

// PerformanceStats 性能统计信息
type PerformanceStats struct {
	DatabaseStats DatabaseStats `json:"database"`
	CacheStats    interface{}   `json:"cache"`
	SystemStats   SystemStats   `json:"system"`
	Timestamp     time.Time     `json:"timestamp"`
}

// DatabaseStats 数据库统计信息
type DatabaseStats struct {
	MaxOpenConns    int           `json:"maxOpenConns"`
	OpenConns       int           `json:"openConns"`
	InUse           int           `json:"inUse"`
	Idle            int           `json:"idle"`
	WaitCount       int64         `json:"waitCount"`
	WaitDuration    time.Duration `json:"waitDuration"`
	MaxIdleConns    int           `json:"maxIdleConns"`
	MaxLifetime     time.Duration `json:"maxLifetime"`
	MaxIdleTime     time.Duration `json:"maxIdleTime"`
}

// SystemStats 系统统计信息
type SystemStats struct {
	NumGoroutine int     `json:"numGoroutine"`
	MemAlloc     uint64  `json:"memAlloc"`     // 当前分配的内存 (bytes)
	TotalAlloc   uint64  `json:"totalAlloc"`   // 累计分配的内存 (bytes)
	Sys          uint64  `json:"sys"`          // 系统内存 (bytes)
	NumGC        uint32  `json:"numGC"`        // GC次数
	GCCPUFraction float64 `json:"gcCPUFraction"` // GC占用的CPU时间比例
}

// GetPerformanceStats 获取性能统计信息
func GetPerformanceStats() *PerformanceStats {
	stats := &PerformanceStats{
		Timestamp: time.Now(),
	}

	// 获取数据库统计信息
	stats.DatabaseStats = getDatabaseStats()

	// 获取缓存统计信息
	stats.CacheStats = GetCacheStats()

	// 获取系统统计信息
	stats.SystemStats = getSystemStats()

	return stats
}

// getDatabaseStats 获取数据库连接池统计信息
func getDatabaseStats() DatabaseStats {
	stats := DatabaseStats{}

	// 获取底层的 sql.DB 实例
	if sqlDB := getSQLDB(); sqlDB != nil {
		dbStats := sqlDB.Stats()
		
		stats.MaxOpenConns = dbStats.MaxOpenConnections
		stats.OpenConns = dbStats.OpenConnections
		stats.InUse = dbStats.InUse
		stats.Idle = dbStats.Idle
		stats.WaitCount = dbStats.WaitCount
		stats.WaitDuration = dbStats.WaitDuration
		stats.MaxIdleConns = configs.Cfg.DBPool.MaxIdleConns
		stats.MaxLifetime = time.Duration(configs.Cfg.DBPool.ConnMaxLifetime) * time.Second
		stats.MaxIdleTime = time.Duration(configs.Cfg.DBPool.ConnMaxIdleTime) * time.Second
	}

	return stats
}

// getSQLDB 获取底层的 sql.DB 实例
func getSQLDB() *sql.DB {
	// 这里需要从 Ent 客户端获取底层的 sql.DB
	// 由于 Ent 的设计，我们需要通过反射或其他方式获取
	// 简化处理，直接创建一个新的连接来获取统计信息
	sqlDB, err := sql.Open(configs.Cfg.DBType, configs.Cfg.ConnectionString)
	if err != nil {
		utils.Warn("Failed to get SQL DB for stats: %v", err)
		return nil
	}
	return sqlDB
}

// getSystemStats 获取系统统计信息
func getSystemStats() SystemStats {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	return SystemStats{
		NumGoroutine:  runtime.NumGoroutine(),
		MemAlloc:      m.Alloc,
		TotalAlloc:    m.TotalAlloc,
		Sys:           m.Sys,
		NumGC:         m.NumGC,
		GCCPUFraction: m.GCCPUFraction,
	}
}

// LogPerformanceStats 记录性能统计信息
func LogPerformanceStats() {
	stats := GetPerformanceStats()
	
	utils.Info("=== Performance Stats ===")
	utils.Info("Database - Open: %d/%d, InUse: %d, Idle: %d, Wait: %d (%.2fms avg)",
		stats.DatabaseStats.OpenConns,
		stats.DatabaseStats.MaxOpenConns,
		stats.DatabaseStats.InUse,
		stats.DatabaseStats.Idle,
		stats.DatabaseStats.WaitCount,
		float64(stats.DatabaseStats.WaitDuration.Nanoseconds())/1000000.0)
	
	utils.Info("System - Goroutines: %d, Memory: %.2fMB, GC: %d (%.2f%% CPU)",
		stats.SystemStats.NumGoroutine,
		float64(stats.SystemStats.MemAlloc)/1024/1024,
		stats.SystemStats.NumGC,
		stats.SystemStats.GCCPUFraction*100)
	
	if cacheStats, ok := stats.CacheStats.(map[string]interface{}); ok {
		if enabled, ok := cacheStats["enabled"].(bool); ok && enabled {
			utils.Info("Cache - Keys: %v, TTL: %vs",
				cacheStats["total_keys"],
				cacheStats["cache_ttl"])
		}
	}
}

// StartPerformanceMonitoring 启动性能监控
func StartPerformanceMonitoring(interval time.Duration) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				LogPerformanceStats()
				
				// 检查数据库连接池健康状态
				checkDatabaseHealth()
				
				// 检查内存使用情况
				checkMemoryUsage()
			}
		}
	}()
	
	utils.Info("Performance monitoring started with interval: %v", interval)
}

// checkDatabaseHealth 检查数据库连接池健康状态
func checkDatabaseHealth() {
	stats := getDatabaseStats()
	
	// 检查连接池使用率
	if stats.MaxOpenConns > 0 {
		usageRate := float64(stats.OpenConns) / float64(stats.MaxOpenConns)
		if usageRate > 0.8 {
			utils.Warn("Database connection pool usage high: %.1f%% (%d/%d)",
				usageRate*100, stats.OpenConns, stats.MaxOpenConns)
		}
	}
	
	// 检查等待时间
	if stats.WaitCount > 0 {
		avgWaitTime := stats.WaitDuration / time.Duration(stats.WaitCount)
		if avgWaitTime > 100*time.Millisecond {
			utils.Warn("Database connection wait time high: %.2fms average",
				float64(avgWaitTime.Nanoseconds())/1000000.0)
		}
	}
}

// checkMemoryUsage 检查内存使用情况
func checkMemoryUsage() {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	// 检查内存使用量
	memUsageMB := float64(m.Alloc) / 1024 / 1024
	if memUsageMB > 512 { // 超过512MB警告
		utils.Warn("High memory usage: %.2fMB", memUsageMB)
	}
	
	// 检查GC频率
	if m.GCCPUFraction > 0.1 { // GC占用超过10%CPU时间
		utils.Warn("High GC CPU usage: %.2f%%", m.GCCPUFraction*100)
	}
}

// OptimizeDatabase 数据库优化建议
func OptimizeDatabase() []string {
	suggestions := []string{}
	stats := getDatabaseStats()
	
	// 连接池优化建议
	if stats.MaxOpenConns > 0 {
		usageRate := float64(stats.OpenConns) / float64(stats.MaxOpenConns)
		if usageRate > 0.9 {
			suggestions = append(suggestions, "Consider increasing MaxOpenConns in database pool")
		}
		if usageRate < 0.3 && stats.MaxOpenConns > 10 {
			suggestions = append(suggestions, "Consider decreasing MaxOpenConns to save resources")
		}
	}
	
	// 等待时间优化建议
	if stats.WaitCount > 0 {
		avgWaitTime := stats.WaitDuration / time.Duration(stats.WaitCount)
		if avgWaitTime > 50*time.Millisecond {
			suggestions = append(suggestions, "High connection wait time detected, consider increasing connection pool size")
		}
	}
	
	// 空闲连接优化建议
	if stats.Idle > stats.MaxIdleConns {
		suggestions = append(suggestions, "Consider increasing MaxIdleConns to reduce connection overhead")
	}
	
	return suggestions
}

// GetDatabaseIndexSuggestions 获取数据库索引建议
func GetDatabaseIndexSuggestions() []string {
	suggestions := []string{
		"Ensure indexes exist on frequently queried columns:",
		"- users.username (unique index already exists)",
		"- chat_records.from_user_id, to_user_id (composite index recommended)",
		"- chat_records.to_user_id, create_time (for message history queries)",
		"- group_chat_records.group_id, create_time (for group message queries)",
		"- friend_requests.to_user_id, status (for pending requests)",
		"- message_status.msg_id, user_id (composite unique index)",
		"Consider adding partial indexes for frequently filtered data",
		"Monitor slow query log to identify missing indexes",
	}
	
	return suggestions
}

// WarmupCache 预热缓存
func WarmupCache() error {
	if cache == nil {
		return fmt.Errorf("cache not available")
	}
	
	utils.Info("Starting cache warmup...")
	
	// 预热热门用户数据
	// 这里可以根据实际业务逻辑预热最活跃的用户
	ctx := context.TODO()
	
	// 获取最近活跃的用户（简化处理，获取最近注册的用户）
	users, err := db.User.Query().
		Order(ent.Desc("id")).
		Limit(100).
		All(ctx)
	
	if err != nil {
		return fmt.Errorf("failed to fetch users for cache warmup: %w", err)
	}
	
	// 预热用户缓存
	for _, user := range users {
		_ = CacheHotUser(user)
	}
	
	utils.Info("Cache warmup completed: %d users cached", len(users))
	return nil
}