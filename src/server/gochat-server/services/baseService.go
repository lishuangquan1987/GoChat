package services

import (
	"context"
	"gochat_server/configs"
	"gochat_server/ent"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
	_ "github.com/mattn/go-sqlite3"
)

var db *ent.Client

func init() {
	var err error
	db, err = ent.Open(configs.Cfg.DBType, configs.Cfg.ConnectionString)
	if err != nil {
		panic("failed to open connection to database: " + err.Error())
	}
	//同步结构
	err = db.Schema.Create(context.Background())
	if err != nil {
		panic("failed creating schema resources: " + err.Error())
	}
}
