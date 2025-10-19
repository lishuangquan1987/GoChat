package services

import (
	"context"
	"errors"
	authmanager "gochat_server/auth_manager"
	"gochat_server/ent"
	"gochat_server/ent/user"
	"strconv"
)

// LoginResponse 登录响应结构
type LoginResponse struct {
	User  *ent.User `json:"user"`
	Token string    `json:"token"`
}

// Register 用户注册
func Register(username, password, nickname string, sex int) (*ent.User, error) {
	// 检查用户名是否已存在
	existingUser, err := db.User.Query().
		Where(user.Username(username)).
		First(context.TODO())
	if err == nil && existingUser != nil {
		return nil, errors.New("用户名已存在")
	}

	// 加密密码
	hashedPassword, err := authmanager.HashPassword(password)
	if err != nil {
		return nil, errors.New("密码加密失败")
	}

	// 创建新用户
	newUser, err := db.User.Create().
		SetUsername(username).
		SetPassword(hashedPassword).
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

// Login 用户登录
func Login(username, password string) (*LoginResponse, error) {
	// 查询用户
	user, err := db.User.Query().
		Where(user.Username(username)).
		First(context.TODO())
	if err != nil {
		return nil, errors.New("用户名或密码错误")
	}

	// 验证密码
	if !authmanager.CheckPassword(user.Password, password) {
		return nil, errors.New("用户名或密码错误")
	}

	// 生成 token
	token, err := authmanager.GenerateToken(user.ID, user.Username)
	if err != nil {
		return nil, errors.New("生成token失败")
	}

	return &LoginResponse{
		User:  user,
		Token: token,
	}, nil
}

// GetUserByID 根据ID获取用户信息（带缓存）
func GetUserByID(userId int) (*ent.User, error) {
	// 标记用户访问，用于热点数据检测
	_ = MarkUserAsHot(userId)

	// 首先尝试从热点用户缓存获取
	user, err := GetHotUserByID(userId)
	if err == nil {
		return user, nil
	}

	// 尝试从普通缓存获取
	user, err = GetUserByIDWithCache(userId)
	if err == nil {
		return user, nil
	}

	// 缓存未命中，从数据库获取
	user, err = db.User.Get(context.TODO(), userId)
	if err != nil {
		return nil, errors.New("用户不存在")
	}

	// 写入缓存
	_ = CacheUser(user)

	return user, nil
}

// UpdateUser 更新用户信息
func UpdateUser(userId int, nickname string, sex int) (*ent.User, error) {
	user, err := db.User.UpdateOneID(userId).
		SetNickname(nickname).
		SetSex(sex).
		Save(context.TODO())
	if err != nil {
		return nil, errors.New("更新用户信息失败")
	}

	// 使缓存失效
	_ = InvalidateUserCache(userId)

	return user, nil
}

// Logout 用户登出
func Logout(userId int) error {
	// 删除 token
	if !authmanager.DeleteToken(strconv.Itoa(userId)) {
		return errors.New("登出失败")
	}
	return nil
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
