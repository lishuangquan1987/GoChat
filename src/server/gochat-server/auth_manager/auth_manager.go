package authmanager

import (
	"errors"
	"log"

	"github.com/nalgeon/redka"
)

const AuthDB = "auth.db"

func ValidateToken(userId, token string) bool {
	db, err := redka.Open(AuthDB, nil)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	tokenInDb, err := db.Str().Get(userId)
	if err != nil {
		if errors.Is(err, redka.ErrNotFound) {
			return false
		} else {
			log.Fatal(err)
		}
	}
	if tokenInDb.String() != token {
		return false
	}
	return true
}

func AddToken(userId, token string) bool {
	db, err := redka.Open(AuthDB, nil)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	err = db.Str().Set(userId, token)
	if err != nil {
		log.Fatal(err)
	}
	return true
}
func DeleteToken(userId string) bool {
	db, err := redka.Open(AuthDB, nil)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	err = db.Key().Expire(userId, 0) // 设置过期时间为0，表示立即删除
	if err != nil {
		if errors.Is(err, redka.ErrNotFound) {
			// 如果键不存在，可以选择记录日志或直接返回 true
			log.Printf("键 %s 不存在", userId)
			return true
		} else {
			log.Fatal(err)
		}
	}
	return true
}
