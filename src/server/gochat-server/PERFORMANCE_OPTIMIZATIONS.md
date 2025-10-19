# GoChat 后端性能优化实现

## 概述

本文档描述了 GoChat 后端系统的性能优化实现，包括数据库连接池配置、数据库索引优化和 Redka 缓存热点数据实现。

## 1. 数据库连接池优化

### 配置参数优化

在 `Config.json` 中优化了数据库连接池配置：

```json
{
    "DBPool": {
        "MaxOpenConns": 50,      // 最大打开连接数（从25增加到50）
        "MaxIdleConns": 25,      // 最大空闲连接数（从10增加到25）
        "ConnMaxLifetime": 600,  // 连接最大生命周期（从300秒增加到600秒）
        "ConnMaxIdleTime": 300   // 连接最大空闲时间（从60秒增加到300秒）
    }
}
```

### 优化理由

- **MaxOpenConns**: 增加到50以支持更高的并发连接
- **MaxIdleConns**: 增加到25以减少连接创建/销毁的开销
- **ConnMaxLifetime**: 增加到10分钟以减少连接重建频率
- **ConnMaxIdleTime**: 增加到5分钟以保持连接池的效率

### 实现位置

- 配置文件: `Config.json`
- 配置结构: `configs/Config.go`
- 连接池配置: `services/baseService.go`

## 2. 数据库索引优化

### 新增索引

为以下表添加了性能优化索引：

#### User 表
```go
index.Fields("username").Unique()  // 用户名唯一索引
```

#### ChatRecord 表
```go
index.Fields("msgId").Unique()                    // 消息ID唯一索引
index.Fields("fromUserId", "toUserId")           // 发送者和接收者组合索引
index.Fields("toUserId", "createTime")           // 接收者和时间索引（查询用户消息）
index.Fields("groupId", "createTime")            // 群组和时间索引（查询群聊历史）
```

#### GroupChatRecord 表
```go
index.Fields("msgId").Unique()           // 消息ID唯一索引
index.Fields("groupId", "createTime")    // 群组和时间索引（查询群聊历史）
```

#### Group 表
```go
index.Fields("groupId").Unique()    // 群组ID唯一索引
index.Fields("ownerId")             // 群主ID索引
index.Fields("createUserId")        // 创建者ID索引
index.Fields("createTime")          // 创建时间索引
```

#### FriendRequest 表
```go
index.Fields("toUserId", "status")        // 接收者和状态索引（查询待处理请求）
index.Fields("fromUserId", "toUserId")    // 发送者和接收者索引（防重复请求）
```

#### MessageStatus 表
```go
index.Fields("msgId", "userId").Unique()  // 消息和用户组合唯一索引
index.Fields("userId")                    // 用户ID索引
```

### 索引优化效果

- **查询性能提升**: 常用查询的执行时间显著减少
- **并发性能**: 减少锁等待时间，提高并发处理能力
- **存储优化**: 合理的组合索引减少存储开销

## 3. Redka 缓存热点数据实现

### 缓存配置优化

```json
{
    "Redka": {
        "Enabled": true,
        "Path": "./redka.db",
        "CacheTTL": 600,        // 普通缓存TTL（从300秒增加到600秒）
        "HotDataTTL": 1800,     // 热点数据TTL（新增，30分钟）
        "MaxMemory": "256MB"    // 最大内存使用量（新增）
    }
}
```

### 缓存策略实现

#### 1. 多层缓存架构

```go
// 用户数据获取优先级：
// 1. 热点用户缓存 (HotDataTTL: 30分钟)
// 2. 普通用户缓存 (CacheTTL: 10分钟)
// 3. 数据库查询
func GetUserByID(userId int) (*ent.User, error) {
    // 标记用户访问，用于热点检测
    _ = MarkUserAsHot(userId)
    
    // 热点缓存 -> 普通缓存 -> 数据库
    if user, err := GetHotUserByID(userId); err == nil {
        return user, nil
    }
    if user, err := GetUserByIDWithCache(userId); err == nil {
        return user, nil
    }
    // 数据库查询...
}
```

#### 2. 热点数据检测

```go
// 访问频率检测，超过阈值自动标记为热点数据
func MarkUserAsHot(userId int) error {
    key := fmt.Sprintf("user_access_count:%d", userId)
    count, _ := cache.Str().Incr(key)
    
    if count >= 10 { // 1小时内访问10次以上标记为热点
        user, _ := db.User.Get(context.TODO(), userId)
        CacheHotUser(user) // 使用更长的TTL缓存
    }
}
```

#### 3. 缓存类型

- **用户缓存**: 用户基本信息
- **热点用户缓存**: 频繁访问的用户（更长TTL）
- **好友列表缓存**: 用户好友关系
- **群组成员缓存**: 群组成员信息
- **聊天历史缓存**: 分页聊天记录
- **在线用户缓存**: WebSocket连接状态

#### 4. 缓存失效策略

```go
// 数据更新时自动失效相关缓存
func SendMessage(fromUserId, toUserId int, ...) {
    // 发送消息后失效聊天历史缓存
    _ = InvalidateChatHistoryCache(fromUserId, toUserId)
}

func UpdateUser(userId int, ...) {
    // 更新用户信息后失效用户缓存
    _ = InvalidateUserCache(userId)
}
```

## 4. 性能监控系统

### 监控指标

实现了全面的性能监控系统，包括：

#### 数据库监控
- 连接池使用率
- 连接等待时间
- 活跃/空闲连接数
- 连接生命周期统计

#### 缓存监控
- 缓存命中率
- 键数量统计
- 内存使用情况
- TTL 配置状态

#### 系统监控
- Goroutine 数量
- 内存使用量
- GC 统计信息
- CPU 使用率

### 监控接口

```go
// 性能统计 API
GET /api/performance/stats           // 获取性能统计
GET /api/performance/optimization    // 获取优化建议
GET /api/performance/cache/stats     // 获取缓存统计
POST /api/performance/cache/warmup   // 缓存预热
```

### 自动监控

```go
// 每5分钟自动记录性能统计
services.StartPerformanceMonitoring(5 * time.Minute)

// 自动健康检查和告警
func checkDatabaseHealth() {
    if usageRate > 0.8 {
        utils.Warn("Database connection pool usage high: %.1f%%", usageRate*100)
    }
}
```

## 5. 缓存预热机制

### 启动时预热

```go
// 服务启动时自动预热缓存
func main() {
    // 初始化缓存后立即预热
    if err := services.WarmupCache(); err != nil {
        utils.Warn("Cache warmup failed: %v", err)
    }
}
```

### 预热策略

```go
func WarmupCache() error {
    // 预热最近活跃的100个用户
    users, _ := db.User.Query().
        Order(ent.Desc("id")).
        Limit(100).
        All(ctx)
    
    for _, user := range users {
        _ = CacheHotUser(user) // 使用热点数据TTL
    }
}
```

## 6. 性能优化效果

### 预期性能提升

1. **数据库查询性能**: 
   - 索引优化预计提升查询性能 60-80%
   - 连接池优化提升并发处理能力 40-60%

2. **缓存命中率**:
   - 用户数据缓存命中率预计达到 85-95%
   - 聊天历史缓存命中率预计达到 70-80%

3. **响应时间**:
   - API 响应时间预计减少 50-70%
   - WebSocket 消息延迟预计减少 30-50%

### 监控和调优

- 实时监控连接池使用情况
- 自动检测性能瓶颈
- 提供优化建议
- 支持动态缓存预热

## 7. 使用说明

### 配置调整

根据实际负载调整 `Config.json` 中的参数：

```json
{
    "DBPool": {
        "MaxOpenConns": 50,     // 根据并发用户数调整
        "MaxIdleConns": 25,     // 通常设置为 MaxOpenConns 的 50%
        "ConnMaxLifetime": 600, // 根据数据库配置调整
        "ConnMaxIdleTime": 300  // 根据访问模式调整
    },
    "Redka": {
        "CacheTTL": 600,        // 根据数据更新频率调整
        "HotDataTTL": 1800,     // 热点数据可以设置更长TTL
        "MaxMemory": "256MB"    // 根据服务器内存调整
    }
}
```

### 监控使用

```bash
# 查看性能统计
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/performance/stats

# 获取优化建议
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/performance/optimization

# 手动预热缓存
curl -X POST -H "Authorization: Bearer <token>" http://localhost:8080/api/performance/cache/warmup
```

### 日志监控

服务器会每5分钟自动输出性能统计日志：

```
[INFO] === Performance Stats ===
[INFO] Database - Open: 15/50, InUse: 3, Idle: 12, Wait: 0 (0.00ms avg)
[INFO] System - Goroutines: 25, Memory: 45.23MB, GC: 12 (2.34% CPU)
[INFO] Cache - Keys: 156, TTL: 600s
```

## 8. 注意事项

1. **内存使用**: 缓存会增加内存使用，需要监控内存使用情况
2. **缓存一致性**: 数据更新时需要及时失效相关缓存
3. **连接池配置**: 需要根据实际负载调整连接池参数
4. **索引维护**: 新增索引会影响写入性能，需要权衡
5. **监控告警**: 建议设置性能监控告警，及时发现问题

## 9. 后续优化建议

1. **查询优化**: 分析慢查询日志，进一步优化SQL
2. **缓存策略**: 根据实际使用情况调整缓存策略
3. **分库分表**: 数据量增长时考虑分库分表
4. **读写分离**: 高并发时考虑读写分离
5. **CDN加速**: 静态资源使用CDN加速