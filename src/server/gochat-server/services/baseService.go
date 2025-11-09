package services

import (
	"context"
	"database/sql"
	"gochat_server/configs"
	"gochat_server/ent"
	"gochat_server/utils"
	"log"
	"strings"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "github.com/lib/pq"
)

var db *ent.Client

func init() {
	var err error

	// 首先创建标准的 sql.DB 连接以配置连接池
	sqlDB, err := sql.Open(configs.Cfg.DBType, configs.Cfg.ConnectionString)
	if err != nil {
		log.Fatalf("failed opening connection to database: %v", err)
	}

	// 配置数据库连接池
	configureDBPool(sqlDB)

	// 使用配置好的 sql.DB 创建 Ent 客户端
	drv := ent.Driver(entsql.OpenDB(configs.Cfg.DBType, sqlDB))
	db = ent.NewClient(drv)

	utils.Info("Database connection pool configured: MaxOpen=%d, MaxIdle=%d",
		configs.Cfg.DBPool.MaxOpenConns, configs.Cfg.DBPool.MaxIdleConns)
}

// RunMigrations 运行数据库迁移
func RunMigrations() error {
	ctx := context.Background()

	// 检查并添加缺失的列到 users 表
	sqlDB, err := sql.Open(configs.Cfg.DBType, configs.Cfg.ConnectionString)
	if err != nil {
		return err
	}
	defer sqlDB.Close()

	// 添加新列（如果不存在）
	migrations := []struct {
		table  string
		column string
		sql    string
	}{
		{
			table:  "users",
			column: "avatar",
			sql:    "ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar VARCHAR(255)",
		},
		{
			table:  "users",
			column: "signature",
			sql:    "ALTER TABLE users ADD COLUMN IF NOT EXISTS signature VARCHAR(500)",
		},
		{
			table:  "users",
			column: "region",
			sql:    "ALTER TABLE users ADD COLUMN IF NOT EXISTS region VARCHAR(100)",
		},
		{
			table:  "users",
			column: "birthday",
			sql:    "ALTER TABLE users ADD COLUMN IF NOT EXISTS birthday TIMESTAMP",
		},
		{
			table:  "users",
			column: "last_seen",
			sql:    "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP",
		},
		{
			table:  "users",
			column: "status",
			sql:    "ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'online'",
		},
		{
			table:  "messages",
			column: "is_revoked",
			sql:    "ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_revoked BOOLEAN DEFAULT false",
		},
		{
			table:  "messages",
			column: "revoke_time",
			sql:    "ALTER TABLE messages ADD COLUMN IF NOT EXISTS revoke_time TIMESTAMP",
		},
		{
			table:  "friend_relationships",
			column: "remark_name",
			sql:    "ALTER TABLE friend_relationships ADD COLUMN IF NOT EXISTS remark_name VARCHAR(100)",
		},
		{
			table:  "friend_relationships",
			column: "category",
			sql:    "ALTER TABLE friend_relationships ADD COLUMN IF NOT EXISTS category VARCHAR(50)",
		},
		{
			table:  "friend_relationships",
			column: "tags",
			sql:    "ALTER TABLE friend_relationships ADD COLUMN IF NOT EXISTS tags TEXT",
		},
	}

	for _, migration := range migrations {
		if _, err := sqlDB.ExecContext(ctx, migration.sql); err != nil {
			// PostgreSQL 的 IF NOT EXISTS 应该会处理列已存在的情况
			// 但如果仍然出错，记录警告（可能是其他问题）
			errMsg := strings.ToLower(err.Error())
			if !strings.Contains(errMsg, "already exists") &&
				!strings.Contains(errMsg, "duplicate column name") {
				// 只有真正的错误才记录
				utils.Warn("Migration warning for %s.%s: %v", migration.table, migration.column, err)
			}
		}
	}

	utils.Info("Database migrations completed")
	return nil
}

// configureDBPool 配置数据库连接池参数
func configureDBPool(sqlDB *sql.DB) {
	// 设置最大打开连接数
	sqlDB.SetMaxOpenConns(configs.Cfg.DBPool.MaxOpenConns)

	// 设置最大空闲连接数
	sqlDB.SetMaxIdleConns(configs.Cfg.DBPool.MaxIdleConns)

	// 设置连接最大生命周期
	sqlDB.SetConnMaxLifetime(time.Duration(configs.Cfg.DBPool.ConnMaxLifetime) * time.Second)

	// 设置连接最大空闲时间
	sqlDB.SetConnMaxIdleTime(time.Duration(configs.Cfg.DBPool.ConnMaxIdleTime) * time.Second)
}
