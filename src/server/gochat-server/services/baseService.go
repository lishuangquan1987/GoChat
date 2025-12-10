package services

import (
	"context"
	"database/sql"
	"gochat_server/configs"
	"gochat_server/ent"
	"gochat_server/utils"
	"log"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
	_ "github.com/mattn/go-sqlite3"
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

// RunEntMigrations 使用 Ent 自动迁移功能同步数据库结构
// 这会根据 Schema 定义自动创建或更新数据库表结构
func RunEntMigrations() error {
	ctx := context.Background()

	utils.Info("Running Ent schema migration...")

	// 使用 Ent 的 Schema.Create 方法自动同步数据库结构
	// 这会根据 ent/schema 目录下的定义自动创建或更新表结构
	if err := db.Schema.Create(ctx); err != nil {
		utils.Error("Ent schema migration failed: %v", err)
		return err
	}

	utils.Info("Ent schema migration completed successfully")
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
