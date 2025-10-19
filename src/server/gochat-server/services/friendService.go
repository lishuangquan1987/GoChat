package services

import (
	"context"
	"errors"
	"gochat_server/ent"
	"gochat_server/ent/friendrelationship"
	"gochat_server/ent/friendrequest"
	"gochat_server/ent/user"
	"log"
	"strconv"
)

// SendFriendRequest 发送好友请求
func SendFriendRequest(fromUserId, toUserId int, remark string) error {
	// 检查发送者是否存在
	_, err := db.User.Get(context.TODO(), fromUserId)
	if err != nil {
		return errors.New("发送者不存在")
	}

	// 检查接收者是否存在
	_, err = db.User.Get(context.TODO(), toUserId)
	if err != nil {
		return errors.New("接收者不存在")
	}

	// 不能给自己发送好友请求
	if fromUserId == toUserId {
		return errors.New("不能给自己发送好友请求")
	}

	// 检查是否已经是好友
	isFriend, err := IsFriend(fromUserId, toUserId)
	if err != nil {
		return err
	}
	if isFriend {
		return errors.New("已经是好友关系")
	}

	// 检查是否已经发送过请求（待处理状态）
	existingRequest, _ := db.FriendRequest.Query().
		Where(
			friendrequest.FromUserId(fromUserId),
			friendrequest.ToUserId(toUserId),
			friendrequest.Status(0),
		).
		First(context.TODO())

	if existingRequest != nil {
		return errors.New("已经发送过好友请求，请等待对方处理")
	}

	// 创建好友请求
	request, err := db.FriendRequest.Create().
		SetFromUserId(fromUserId).
		SetToUserId(toUserId).
		SetRemark(remark).
		SetStatus(0).
		Save(context.TODO())

	if err != nil {
		return errors.New("发送好友请求失败")
	}

	// 发送实时通知给接收者
	go func() {
		err := SendFriendRequestNotification(request)
		if err != nil {
			log.Printf("Failed to send friend request notification: %v", err)
		}
	}()

	return nil
}

// AcceptFriendRequest 接受好友请求
func AcceptFriendRequest(requestId int) error {
	// 查询好友请求
	request, err := db.FriendRequest.Get(context.TODO(), requestId)
	if err != nil {
		return errors.New("好友请求不存在")
	}

	// 检查请求状态
	if request.Status != 0 {
		return errors.New("该请求已被处理")
	}

	// 更新请求状态为已接受
	_, err = db.FriendRequest.UpdateOneID(requestId).
		SetStatus(1).
		Save(context.TODO())
	if err != nil {
		return errors.New("更新请求状态失败")
	}

	// 创建双向好友关系
	// 关系1: fromUser -> toUser
	_, err = db.FriendRelationship.Create().
		SetUserId(request.FromUserId).
		SetFriendId(request.ToUserId).
		Save(context.TODO())
	if err != nil {
		return errors.New("创建好友关系失败")
	}

	// 关系2: toUser -> fromUser
	_, err = db.FriendRelationship.Create().
		SetUserId(request.ToUserId).
		SetFriendId(request.FromUserId).
		Save(context.TODO())
	if err != nil {
		// 如果第二个关系创建失败，删除第一个关系
		db.FriendRelationship.Delete().
			Where(
				friendrelationship.UserId(request.FromUserId),
				friendrelationship.FriendId(request.ToUserId),
			).
			Exec(context.TODO())
		return errors.New("创建好友关系失败")
	}

	// 使好友列表缓存失效
	_ = InvalidateFriendListCache(request.FromUserId)
	_ = InvalidateFriendListCache(request.ToUserId)

	// 发送好友请求被接受的通知给发送者
	go func() {
		accepter, err := db.User.Get(context.TODO(), request.ToUserId)
		if err == nil {
			err = SendFriendRequestAcceptedNotification(strconv.Itoa(request.FromUserId), accepter.Nickname)
			if err != nil {
				log.Printf("Failed to send friend request accepted notification: %v", err)
			}
		}
	}()

	return nil
}

// RejectFriendRequest 拒绝好友请求
func RejectFriendRequest(requestId int) error {
	// 查询好友请求
	request, err := db.FriendRequest.Get(context.TODO(), requestId)
	if err != nil {
		return errors.New("好友请求不存在")
	}

	// 检查请求状态
	if request.Status != 0 {
		return errors.New("该请求已被处理")
	}

	// 更新请求状态为已拒绝
	_, err = db.FriendRequest.UpdateOneID(requestId).
		SetStatus(2).
		Save(context.TODO())
	if err != nil {
		return errors.New("更新请求状态失败")
	}

	return nil
}

// GetFriendList 获取好友列表（带缓存）
func GetFriendList(userId int) ([]*ent.User, error) {
	// 尝试从缓存获取
	friends, found := GetCachedFriendList(userId)
	if found {
		return friends, nil
	}

	// 查询用户的所有好友关系
	relationships, err := db.FriendRelationship.Query().
		Where(friendrelationship.UserId(userId)).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询好友关系失败")
	}

	// 提取好友ID列表
	friendIds := make([]int, len(relationships))
	for i, rel := range relationships {
		friendIds[i] = rel.FriendId
	}

	// 如果没有好友，返回空列表
	if len(friendIds) == 0 {
		return []*ent.User{}, nil
	}

	// 查询好友用户信息
	friends, err = db.User.Query().
		Where(user.IDIn(friendIds...)).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询好友信息失败")
	}

	// 写入缓存
	_ = CacheFriendList(userId, friends)

	return friends, nil
}

// GetFriendRequests 获取收到的好友请求列表
func GetFriendRequests(userId int) ([]*ent.FriendRequest, error) {
	requests, err := db.FriendRequest.Query().
		Where(
			friendrequest.ToUserId(userId),
			friendrequest.Status(0), // 只查询待处理的请求
		).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询好友请求失败")
	}

	return requests, nil
}

// GetSentFriendRequests 获取发送的好友请求列表
func GetSentFriendRequests(userId int) ([]*ent.FriendRequest, error) {
	requests, err := db.FriendRequest.Query().
		Where(friendrequest.FromUserId(userId)).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询好友请求失败")
	}

	return requests, nil
}

// DeleteFriend 删除好友
func DeleteFriend(userId, friendId int) error {
	// 检查是否是好友关系
	isFriend, err := IsFriend(userId, friendId)
	if err != nil {
		return err
	}
	if !isFriend {
		return errors.New("不是好友关系")
	}

	// 删除双向好友关系
	// 删除关系1: userId -> friendId
	_, err = db.FriendRelationship.Delete().
		Where(
			friendrelationship.UserId(userId),
			friendrelationship.FriendId(friendId),
		).
		Exec(context.TODO())
	if err != nil {
		return errors.New("删除好友关系失败")
	}

	// 删除关系2: friendId -> userId
	_, err = db.FriendRelationship.Delete().
		Where(
			friendrelationship.UserId(friendId),
			friendrelationship.FriendId(userId),
		).
		Exec(context.TODO())
	if err != nil {
		return errors.New("删除好友关系失败")
	}

	// 使好友列表缓存失效
	_ = InvalidateFriendListCache(userId)
	_ = InvalidateFriendListCache(friendId)

	return nil
}

// IsFriend 检查两个用户是否是好友
func IsFriend(userId, friendId int) (bool, error) {
	count, err := db.FriendRelationship.Query().
		Where(
			friendrelationship.UserId(userId),
			friendrelationship.FriendId(friendId),
		).
		Count(context.TODO())

	if err != nil {
		return false, errors.New("查询好友关系失败")
	}

	return count > 0, nil
}

// FriendRequestResponse 好友请求响应结构（符合客户端期望）
type FriendRequestResponse struct {
	ID               int    `json:"id"`
	FromUserId       int    `json:"fromUserId"`
	ToUserId         int    `json:"toUserId"`
	Remark           string `json:"remark"`
	Status           int    `json:"status"`
	CreateTime       string `json:"createTime"`
	FromUserNickname string `json:"fromUserNickname"`
	FromUserAvatar   string `json:"fromUserAvatar"`
}

func GetFriendRequestsWithUsers(userId int) ([]*FriendRequestResponse, error) {
	requests, err := GetFriendRequests(userId)
	if err != nil {
		return nil, err
	}

	result := make([]*FriendRequestResponse, 0, len(requests))
	for _, req := range requests {
		fromUser, err := db.User.Get(context.TODO(), req.FromUserId)
		if err != nil {
			continue // 跳过无法获取用户信息的请求
		}

		response := &FriendRequestResponse{
			ID:               req.ID,
			FromUserId:       req.FromUserId,
			ToUserId:         req.ToUserId,
			Remark:           req.Remark,
			Status:           req.Status,
			CreateTime:       req.CreateTime.Format("2006-01-02T15:04:05Z07:00"),
			FromUserNickname: fromUser.Nickname,
			FromUserAvatar:   "", // 暂时为空，后续可以添加头像功能
		}

		result = append(result, response)
	}

	return result, nil
}

// GetUserById 根据ID获取用户信息
func GetUserById(userId int) (*ent.User, error) {
	return db.User.Get(context.TODO(), userId)
}

// SendFriendRequestNotification 发送好友请求通知
func SendFriendRequestNotification(request *ent.FriendRequest) error {
	// 获取发送者信息
	fromUser, err := db.User.Get(context.TODO(), request.FromUserId)
	if err != nil {
		return err
	}

	// 构造通知消息
	notification := map[string]interface{}{
		"type": "friend_request",
		"data": map[string]interface{}{
			"id":               request.ID,
			"fromUserId":       request.FromUserId,
			"fromUserNickname": fromUser.Nickname,
			"fromUserAvatar":   "", // 暂时为空
			"remark":           request.Remark,
			"createTime":       request.CreateTime.Format("2006-01-02T15:04:05Z07:00"),
		},
		"message": fromUser.Nickname + " 请求添加您为好友",
		"time":    request.CreateTime.Unix(),
	}

	// 发送通知给接收者
	return SendNotificationToUser(strconv.Itoa(request.ToUserId), notification)
}
