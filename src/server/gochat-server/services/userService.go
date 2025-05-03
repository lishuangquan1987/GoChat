package services

import (
	"context"
	"errors"
	"gochat_server/ent"
	"gochat_server/ent/user"
)

func Register(username, password, nickname string, sex int) (*ent.User, error) {
	// 检查用户名是否已存在
	existingUser, err := db.User.Query().
		Where(user.Username(username)).
		First(context.TODO())
	if err == nil && existingUser != nil {
		return nil, errors.New("用户名已存在")
	}

	// 创建新用户
	newUser, err := db.User.Create().
		SetUsername(username).
		SetPassword(password).
		SetNickname(nickname).
		SetSex(sex).
		Save(context.TODO())
	if err != nil {
		return nil, err
	}
	if newUser == nil {
		return nil, errors.New("注册失败")
	}
	return newUser, nil
}

func Login(username, password string) (*ent.User, error) {
	user, err := db.User.Query().
		Where(user.Username(username)).
		First(context.TODO())
	if err != nil {
		return nil, err
	}
	if user.Password != password {
		return nil, errors.New("密码错误")
	}
	return user, nil
}

// func AddFriendRequest(userId, friendId int, remark string) (bool, error) {
// 	// 检查用户是否存在
// 	user, err := db.User.Get(context.TODO(), userId)
// 	if err != nil {
// 		return false, err
// 	}
// 	if user == nil {
// 		return false, errors.New("用户不存在")
// 	}

// 	// 检查好友是否存在
// 	friend, err := db.User.Get(context.TODO(), friendId)
// 	if err != nil {
// 		return false, err
// 	}
// 	if friend == nil {
// 		return false, errors.New("好友不存在")
// 	}

// 	// 添加好友请求逻辑（例如，存储在数据库中）

// 	return true, nil
// }
