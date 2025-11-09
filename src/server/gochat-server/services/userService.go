package services

import (
	"context"
	"errors"
	authmanager "gochat_server/auth_manager"
	"gochat_server/ent"
	"gochat_server/ent/user"
	"strconv"
	"time"
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

// UpdateUserProfile 更新用户详细资料
func UpdateUserProfile(userId int, nickname *string, sex *int, avatar *string, signature *string, region *string, birthday *time.Time, status *string) (*ent.User, error) {
	update := db.User.UpdateOneID(userId)

	if nickname != nil {
		update = update.SetNickname(*nickname)
	}
	if sex != nil {
		update = update.SetSex(*sex)
	}
	if avatar != nil {
		update = update.SetAvatar(*avatar)
	}
	if signature != nil {
		update = update.SetSignature(*signature)
	}
	if region != nil {
		update = update.SetRegion(*region)
	}
	if birthday != nil {
		update = update.SetBirthday(*birthday)
	}
	if status != nil {
		update = update.SetStatus(*status)
	}

	user, err := update.Save(context.TODO())
	if err != nil {
		return nil, errors.New("更新用户信息失败")
	}

	// 使缓存失效
	_ = InvalidateUserCache(userId)

	return user, nil
}

// UpdateUserLastSeen 更新用户最后在线时间
func UpdateUserLastSeen(userId int) error {
	_, err := db.User.UpdateOneID(userId).
		SetLastSeen(time.Now()).
		Save(context.TODO())
	if err != nil {
		return err
	}
	// 使缓存失效
	_ = InvalidateUserCache(userId)
	return nil
}

// Logout 用户登出
func Logout(userId int) error {
	// 删除 token
	if !authmanager.DeleteToken(strconv.Itoa(userId)) {
		return errors.New("登出失败")
	}
	return nil
}

// SearchUsers 搜索用户
func SearchUsers(keyword string, excludeFriends bool, userId int, limit int) ([]*ent.User, error) {
	if limit <= 0 || limit > 100 {
		limit = 20 // 默认返回20条
	}

	// 判断是否为数字（用户ID精确搜索）
	if userIdInt, err := strconv.Atoi(keyword); err == nil {
		// 精确搜索用户ID
		user, err := db.User.Get(context.TODO(), userIdInt)
		if err != nil {
			return []*ent.User{}, nil // 用户不存在，返回空列表
		}
		// 排除自己
		if user.ID == userId {
			return []*ent.User{}, nil
		}
		// 如果要求排除好友，需要检查
		if excludeFriends {
			isFriend, err := IsFriend(userId, user.ID)
			if err == nil && isFriend {
				return []*ent.User{}, nil
			}
		}
		return []*ent.User{user}, nil
	}

	// 模糊搜索用户名或昵称
	// 注意：ent 不支持 OR 条件的模糊搜索，需要分别查询后合并
	usersByUsername, _ := db.User.Query().
		Where(user.UsernameContains(keyword)).
		Limit(limit).
		All(context.TODO())

	usersByNickname, _ := db.User.Query().
		Where(user.NicknameContains(keyword)).
		Limit(limit).
		All(context.TODO())

	// 合并结果并去重
	userMap := make(map[int]*ent.User)
	for _, u := range usersByUsername {
		userMap[u.ID] = u
	}
	for _, u := range usersByNickname {
		userMap[u.ID] = u
	}

	// 转换为切片
	users := make([]*ent.User, 0, len(userMap))
	for _, u := range userMap {
		// 排除自己
		if u.ID == userId {
			continue
		}
		users = append(users, u)
	}

	// 如果要求排除好友，需要过滤
	if excludeFriends {
		// 获取用户的好友列表
		friends, err := GetFriendList(userId)
		if err == nil {
			friendMap := make(map[int]bool)
			for _, f := range friends {
				friendMap[f.ID] = true
			}
			// 过滤掉已经是好友的用户
			filteredUsers := make([]*ent.User, 0)
			for _, u := range users {
				if !friendMap[u.ID] {
					filteredUsers = append(filteredUsers, u)
				}
			}
			users = filteredUsers
		}
	}

	// 限制返回数量
	if len(users) > limit {
		users = users[:limit]
	}

	return users, nil
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
