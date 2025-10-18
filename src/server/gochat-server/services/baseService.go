package services

import (
	"gochat_server/configs"
	"gochat_server/ent"
	"log"

	_ "github.com/lib/pq"
)

var db *ent.Client

func init() {
	var err error
	db, err = ent.Open(configs.Cfg.DBType, configs.Cfg.ConnectionString)
	if err != nil {
		log.Fatalf("failed opening connection to database: %v", err)
	}
}
