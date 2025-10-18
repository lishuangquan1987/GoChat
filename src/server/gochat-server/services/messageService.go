package services

import (
	"context"
	"errors"
	"fmt"
	"gochat_server/dto"
	"gochat_server/ent"
	"gochat_server/ent/chatrecord"
	"time"

	"github.com/google/uuid"
)

// SendMessage 发送消息
func SendMessage(fromUserId, toUserId int, msgType int, content string, groupId *int) (string, error) {
	// 生成消息ID
	msgId := uuid.New().String()

	// 判断是否为群聊
	isGroup := groupId != nil && *groupId > 0

	// 如果是私聊，检查是否是好友关系
	if !isGroup {
		isFriend, err := IsFriend(fromUserId, toUserId)
		if err != nil {
			return "", err
		}
		if !isFriend {
			return "", errors.New("只能给好友发送消息")
		}
	}

	// 根据消息类型存储消息内容
	switch msgType {
	case dto.TEXT_MESSAGE:
		_, err := db.TextMessage.Create().
			SetMsgId(msgId).
			SetText(content).
			Save(context.TODO())
		if err != nil {
			return "", errors.New("保存文本消息失败")
		}

	case dto.IMAGE_MESSAGE:
		_, err := db.ImageMessage.Create().
			SetMsgId(msgId).
			SetImageUrl(content).
			Save(context.TODO())
		if err != nil {
			return "", errors.New("保存图片消息失败")
		}

	case dto.VIDEO_MESSAGE:
		_, err := db.VideoMessage.Create().
			SetMsgId(msgId).
			SetVideoUrl(content).
			Save(context.TODO())
		if err != nil {
			return "", errors.New("保存视频消息失败")
		}

	default:
		return "", errors.New("不支持的消息类型")
	}

	// 创建聊天记录
	chatRecordBuilder := db.ChatRecord.Create().
		SetMsgId(msgId).
		SetFromUserId(fromUserId).
		SetToUserId(toUserId).
		SetMsgType(msgType).
		SetIsGroup(isGroup)

	if isGroup {
		chatRecordBuilder.SetGroupId(*groupId)
	}

	_, err := chatRecordBuilder.Save(context.TODO())
	if err != nil {
		return "", errors.New("保存聊天记录失败")
	}

	return msgId, nil
}

// GetChatHistory 获取私聊历史记录
func GetChatHistory(userId, friendId int, page, pageSize int) ([]map[string]interface{}, int, error) {
	// 检查是否是好友
	isFriend, err := IsFriend(userId, friendId)
	if err != nil {
		return nil, 0, err
	}
	if !isFriend {
		return nil, 0, errors.New("不是好友关系")
	}

	// 计算偏移量
	offset := (page - 1) * pageSize

	// 查询聊天记录（双向查询）
	records, err := db.ChatRecord.Query().
		Where(
			chatrecord.Or(
				chatrecord.And(
					chatrecord.FromUserId(userId),
					chatrecord.ToUserId(friendId),
					chatrecord.IsGroup(false),
				),
				chatrecord.And(
					chatrecord.FromUserId(friendId),
					chatrecord.ToUserId(userId),
					chatrecord.IsGroup(false),
				),
			),
		).
		Order(ent.Desc(chatrecord.FieldCreateTime)).
		Limit(pageSize).
		Offset(offset).
		All(context.TODO())

	if err != nil {
		return nil, 0, errors.New("查询聊天记录失败")
	}

	// 查询总数
	total, err := db.ChatRecord.Query().
		Where(
			chatrecord.Or(
				chatrecord.And(
					chatrecord.FromUserId(userId),
					chatrecord.ToUserId(friendId),
					chatrecord.IsGroup(false),
				),
				chatrecord.And(
					chatrecord.FromUserId(friendId),
					chatrecord.ToUserId(userId),
					chatrecord.IsGroup(false),
				),
			),
		).
		Count(context.TODO())

	if err != nil {
		return nil, 0, errors.New("查询聊天记录总数失败")
	}

	// 组装消息详情
	messages := make([]map[string]interface{}, 0, len(records))
	for _, record := range records {
		message := map[string]interface{}{
			"msgId":      record.MsgId,
			"fromUserId": record.FromUserId,
			"toUserId":   record.ToUserId,
			"msgType":    record.MsgType,
			"createTime": record.CreateTime,
		}

		// 根据消息类型获取消息内容
		content, err := getMessageContent(record.MsgId, record.MsgType)
		if err == nil {
			message["content"] = content
		}

		messages = append(messages, message)
	}

	return messages, total, nil
}

// GetGroupChatHistory 获取群聊历史记录
func GetGroupChatHistory(groupId, page, pageSize int) ([]map[string]interface{}, int, error) {
	// 计算偏移量
	offset := (page - 1) * pageSize

	// 查询群聊记录
	records, err := db.ChatRecord.Query().
		Where(
			chatrecord.GroupId(groupId),
			chatrecord.IsGroup(true),
		).
		Order(ent.Desc(chatrecord.FieldCreateTime)).
		Limit(pageSize).
		Offset(offset).
		All(context.TODO())

	if err != nil {
		return nil, 0, errors.New("查询群聊记录失败")
	}

	// 查询总数
	total, err := db.ChatRecord.Query().
		Where(
			chatrecord.GroupId(groupId),
			chatrecord.IsGroup(true),
		).
		Count(context.TODO())

	if err != nil {
		return nil, 0, errors.New("查询群聊记录总数失败")
	}

	// 组装消息详情
	messages := make([]map[string]interface{}, 0, len(records))
	for _, record := range records {
		message := map[string]interface{}{
			"msgId":      record.MsgId,
			"fromUserId": record.FromUserId,
			"groupId":    record.GroupId,
			"msgType":    record.MsgType,
			"createTime": record.CreateTime,
		}

		// 根据消息类型获取消息内容
		content, err := getMessageContent(record.MsgId, record.MsgType)
		if err == nil {
			message["content"] = content
		}

		messages = append(messages, message)
	}

	return messages, total, nil
}

// GetOfflineMessages 获取离线消息
func GetOfflineMessages(userId int) ([]map[string]interface{}, error) {
	// 获取用户最后一次在线时间（这里简化处理，获取最近的消息）
	// 实际应该记录用户的最后在线时间
	lastOnlineTime := time.Now().Add(-24 * time.Hour) // 假设获取最近24小时的消息

	// 查询发给该用户的消息
	records, err := db.ChatRecord.Query().
		Where(
			chatrecord.ToUserId(userId),
			chatrecord.CreateTimeGT(lastOnlineTime),
		).
		Order(ent.Asc(chatrecord.FieldCreateTime)).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询离线消息失败")
	}

	// 组装消息详情
	messages := make([]map[string]interface{}, 0, len(records))
	for _, record := range records {
		message := map[string]interface{}{
			"msgId":      record.MsgId,
			"fromUserId": record.FromUserId,
			"toUserId":   record.ToUserId,
			"msgType":    record.MsgType,
			"isGroup":    record.IsGroup,
			"createTime": record.CreateTime,
		}

		if record.IsGroup {
			message["groupId"] = record.GroupId
		}

		// 根据消息类型获取消息内容
		content, err := getMessageContent(record.MsgId, record.MsgType)
		if err == nil {
			message["content"] = content
		}

		messages = append(messages, message)
	}

	return messages, nil
}

// getMessageContent 根据消息ID和类型获取消息内容
func getMessageContent(msgId string, msgType int) (string, error) {
	switch msgType {
	case dto.TEXT_MESSAGE:
		// 查询所有文本消息并过滤
		msgs, err := db.TextMessage.Query().All(context.TODO())
		if err != nil {
			return "", err
		}
		for _, m := range msgs {
			if m.MsgId == msgId {
				return m.Text, nil
			}
		}
		return "", errors.New("消息不存在")

	case dto.IMAGE_MESSAGE:
		msgs, err := db.ImageMessage.Query().All(context.TODO())
		if err != nil {
			return "", err
		}
		for _, m := range msgs {
			if m.MsgId == msgId {
				return m.ImageUrl, nil
			}
		}
		return "", errors.New("消息不存在")

	case dto.VIDEO_MESSAGE:
		msgs, err := db.VideoMessage.Query().All(context.TODO())
		if err != nil {
			return "", err
		}
		for _, m := range msgs {
			if m.MsgId == msgId {
				return m.VideoUrl, nil
			}
		}
		return "", errors.New("消息不存在")

	default:
		return "", errors.New("不支持的消息类型")
	}
}

// MessageDetail 消息详情结构
type MessageDetail struct {
	MsgId      string                 `json:"msgId"`
	FromUserId int                    `json:"fromUserId"`
	ToUserId   int                    `json:"toUserId"`
	MsgType    int                    `json:"msgType"`
	Content    string                 `json:"content"`
	IsGroup    bool                   `json:"isGroup"`
	GroupId    *int                   `json:"groupId,omitempty"`
	CreateTime time.Time              `json:"createTime"`
	Extra      map[string]interface{} `json:"extra,omitempty"`
}

// GetMessageDetail 获取消息详情
func GetMessageDetail(msgId string) (*MessageDetail, error) {
	// 查询聊天记录
	record, err := db.ChatRecord.Query().
		Where(chatrecord.MsgId(msgId)).
		First(context.TODO())

	if err != nil {
		return nil, errors.New("消息不存在")
	}

	// 获取消息内容
	content, err := getMessageContent(record.MsgId, record.MsgType)
	if err != nil {
		return nil, err
	}

	detail := &MessageDetail{
		MsgId:      record.MsgId,
		FromUserId: record.FromUserId,
		ToUserId:   record.ToUserId,
		MsgType:    record.MsgType,
		Content:    content,
		IsGroup:    record.IsGroup,
		CreateTime: record.CreateTime,
	}

	if record.IsGroup {
		detail.GroupId = &record.GroupId
	}

	return detail, nil
}

// GetConversationList 获取会话列表
func GetConversationList(userId int) ([]map[string]interface{}, error) {
	// 查询用户参与的所有会话（最后一条消息）
	// 这里简化处理，实际应该使用更复杂的查询或缓存

	// 获取私聊会话
	privateRecords, err := db.ChatRecord.Query().
		Where(
			chatrecord.Or(
				chatrecord.FromUserId(userId),
				chatrecord.ToUserId(userId),
			),
			chatrecord.IsGroup(false),
		).
		Order(ent.Desc(chatrecord.FieldCreateTime)).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询会话失败")
	}

	// 去重并获取每个好友的最后一条消息
	conversationMap := make(map[int]*ent.ChatRecord)
	for _, record := range privateRecords {
		friendId := record.FromUserId
		if friendId == userId {
			friendId = record.ToUserId
		}

		if _, exists := conversationMap[friendId]; !exists {
			conversationMap[friendId] = record
		}
	}

	// 组装会话列表
	conversations := make([]map[string]interface{}, 0)
	for friendId, record := range conversationMap {
		friend, err := GetUserByID(friendId)
		if err != nil {
			continue
		}

		content, _ := getMessageContent(record.MsgId, record.MsgType)

		conversation := map[string]interface{}{
			"type":        "private",
			"friendId":    friendId,
			"friendName":  friend.Nickname,
			"lastMessage": content,
			"lastTime":    record.CreateTime,
			"unreadCount": 0, // TODO: 实现未读消息计数
		}

		conversations = append(conversations, conversation)
	}

	// TODO: 添加群聊会话

	return conversations, nil
}

// MarkMessageAsRead 标记消息为已读（预留接口）
func MarkMessageAsRead(userId int, msgId string) error {
	// TODO: 实现消息已读状态管理
	fmt.Printf("User %d marked message %s as read\n", userId, msgId)
	return nil
}
