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
	} else {
		// 如果是群聊，检查用户是否是群成员
		isMember, err := IsGroupMember(*groupId, fromUserId)
		if err != nil {
			return "", err
		}
		if !isMember {
			return "", errors.New("只有群成员才能发送群消息")
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
	if isGroup {
		// 群聊消息：存储到 GroupChatRecord
		_, err := db.GroupChatRecord.Create().
			SetMsgId(msgId).
			SetFromUserId(fmt.Sprintf("%d", fromUserId)).
			SetGroupId(fmt.Sprintf("%d", *groupId)).
			SetMsgType(fmt.Sprintf("%d", msgType)).
			Save(context.TODO())
		if err != nil {
			return "", errors.New("保存群聊记录失败")
		}

		// 为所有群成员创建消息状态记录（除了发送者）
		members, err := GetGroupMembers(*groupId)
		if err == nil {
			for _, member := range members {
				if member.ID != fromUserId {
					CreateMessageStatus(msgId, member.ID)
				}
			}
		}
	} else {
		// 私聊消息：存储到 ChatRecord
		_, err := db.ChatRecord.Create().
			SetMsgId(msgId).
			SetFromUserId(fromUserId).
			SetToUserId(toUserId).
			SetMsgType(msgType).
			SetIsGroup(false).
			Save(context.TODO())
		if err != nil {
			return "", errors.New("保存聊天记录失败")
		}

		// 为接收者创建消息状态记录
		CreateMessageStatus(msgId, toUserId)

		// 使私聊历史缓存失效
		_ = InvalidateChatHistoryCache(fromUserId, toUserId)
	}

	// 如果是群聊，使群聊历史缓存失效
	if isGroup {
		_ = InvalidateGroupChatHistoryCache(*groupId)
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

	// 尝试从缓存获取
	if cachedMessages, found := GetCachedChatHistory(userId, friendId, page); found {
		// 从缓存获取总数（简化处理，实际应该单独缓存总数）
		total, _ := db.ChatRecord.Query().
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
		return cachedMessages, total, nil
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

	// 缓存查询结果
	_ = CacheChatHistory(userId, friendId, page, messages)

	return messages, total, nil
}

// GetGroupChatHistory 获取群聊历史记录
func GetGroupChatHistory(groupId, page, pageSize int) ([]map[string]interface{}, int, error) {
	// 尝试从缓存获取
	if cachedMessages, found := GetCachedGroupChatHistory(groupId, page); found {
		// 从缓存获取总数（简化处理）
		allRecords, _ := db.GroupChatRecord.Query().All(context.TODO())
		groupIdStr := fmt.Sprintf("%d", groupId)
		total := 0
		for _, record := range allRecords {
			if record.GroupId == groupIdStr {
				total++
			}
		}
		return cachedMessages, total, nil
	}

	// 查询所有群聊记录，然后在代码中过滤
	allRecords, err := db.GroupChatRecord.Query().
		Order(ent.Desc("create_time")).
		All(context.TODO())

	if err != nil {
		return nil, 0, errors.New("查询群聊记录失败")
	}

	// 过滤出指定群组的记录
	groupIdStr := fmt.Sprintf("%d", groupId)
	filteredRecords := make([]*ent.GroupChatRecord, 0)
	for _, record := range allRecords {
		if record.GroupId == groupIdStr {
			filteredRecords = append(filteredRecords, record)
		}
	}

	// 计算总数
	total := len(filteredRecords)

	// 应用分页
	offset := (page - 1) * pageSize
	end := offset + pageSize
	if offset > len(filteredRecords) {
		offset = len(filteredRecords)
	}
	if end > len(filteredRecords) {
		end = len(filteredRecords)
	}
	
	pagedRecords := filteredRecords[offset:end]

	// 组装消息详情
	messages := make([]map[string]interface{}, 0, len(pagedRecords))
	for _, record := range pagedRecords {
		// 解析 fromUserId 和 msgType
		fromUserId := 0
		fmt.Sscanf(record.FromUserId, "%d", &fromUserId)
		
		msgType := 0
		fmt.Sscanf(record.MsgType, "%d", &msgType)

		message := map[string]interface{}{
			"msgId":      record.MsgId,
			"fromUserId": fromUserId,
			"groupId":    groupId,
			"msgType":    msgType,
			"createTime": record.CreateTime,
		}

		// 根据消息类型获取消息内容
		content, err := getMessageContent(record.MsgId, msgType)
		if err == nil {
			message["content"] = content
		}

		messages = append(messages, message)
	}

	// 缓存查询结果
	_ = CacheGroupChatHistory(groupId, page, messages)

	return messages, total, nil
}

// GetOfflineMessages 获取离线消息
func GetOfflineMessages(userId int) ([]map[string]interface{}, error) {
	// 获取用户最后一次在线时间（这里简化处理，获取最近的消息）
	// 实际应该记录用户的最后在线时间
	lastOnlineTime := time.Now().Add(-24 * time.Hour) // 假设获取最近24小时的消息

	messages := make([]map[string]interface{}, 0)

	// 1. 查询私聊离线消息
	privateRecords, err := db.ChatRecord.Query().
		Where(
			chatrecord.ToUserId(userId),
			chatrecord.CreateTimeGT(lastOnlineTime),
			chatrecord.IsGroup(false),
		).
		Order(ent.Asc(chatrecord.FieldCreateTime)).
		All(context.TODO())

	if err != nil {
		return nil, errors.New("查询私聊离线消息失败")
	}

	// 组装私聊消息详情
	for _, record := range privateRecords {
		message := map[string]interface{}{
			"msgId":      record.MsgId,
			"fromUserId": record.FromUserId,
			"toUserId":   record.ToUserId,
			"msgType":    record.MsgType,
			"isGroup":    false,
			"createTime": record.CreateTime,
		}

		// 根据消息类型获取消息内容
		content, err := getMessageContent(record.MsgId, record.MsgType)
		if err == nil {
			message["content"] = content
		}

		messages = append(messages, message)
	}

	// 2. 查询群聊离线消息
	// 获取用户所在的所有群组
	userGroups, err := GetUserGroups(userId)
	if err == nil {
		// 查询所有群聊消息
		groupRecords, err := db.GroupChatRecord.Query().
			Order(ent.Asc("create_time")).
			All(context.TODO())

		if err == nil {
			// 过滤出用户所在群组的消息
			for _, record := range groupRecords {
				if record.CreateTime.After(lastOnlineTime) {
					// 检查是否是用户所在的群组
					for _, group := range userGroups {
						if fmt.Sprintf("%d", group.ID) == record.GroupId {
							// 解析 fromUserId 和 msgType
							fromUserId := 0
							fmt.Sscanf(record.FromUserId, "%d", &fromUserId)
							
							msgType := 0
							fmt.Sscanf(record.MsgType, "%d", &msgType)

							// 不推送自己发送的消息
							if fromUserId != userId {
								groupId := 0
								fmt.Sscanf(record.GroupId, "%d", &groupId)

								message := map[string]interface{}{
									"msgId":      record.MsgId,
									"fromUserId": fromUserId,
									"groupId":    groupId,
									"msgType":    msgType,
									"isGroup":    true,
									"createTime": record.CreateTime,
								}

								// 根据消息类型获取消息内容
								content, err := getMessageContent(record.MsgId, msgType)
								if err == nil {
									message["content"] = content
								}

								messages = append(messages, message)
							}
							break
						}
					}
				}
			}
		}
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
	// 先尝试查询私聊记录
	record, err := db.ChatRecord.Query().
		Where(chatrecord.MsgId(msgId)).
		First(context.TODO())

	if err == nil {
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

	// 如果私聊记录中没有找到，尝试查询群聊记录
	groupRecords, err := db.GroupChatRecord.Query().All(context.TODO())
	if err != nil {
		return nil, errors.New("查询群聊记录失败")
	}

	for _, groupRecord := range groupRecords {
		if groupRecord.MsgId == msgId {
			// 解析 fromUserId 和 msgType
			fromUserId := 0
			fmt.Sscanf(groupRecord.FromUserId, "%d", &fromUserId)
			
			msgType := 0
			fmt.Sscanf(groupRecord.MsgType, "%d", &msgType)

			groupId := 0
			fmt.Sscanf(groupRecord.GroupId, "%d", &groupId)

			// 获取消息内容
			content, err := getMessageContent(groupRecord.MsgId, msgType)
			if err != nil {
				return nil, err
			}

			detail := &MessageDetail{
				MsgId:      groupRecord.MsgId,
				FromUserId: fromUserId,
				ToUserId:   0, // 群聊消息没有特定的接收者
				MsgType:    msgType,
				Content:    content,
				IsGroup:    true,
				GroupId:    &groupId,
				CreateTime: groupRecord.CreateTime,
			}

			return detail, nil
		}
	}

	return nil, errors.New("消息不存在")
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

// CreateMessageStatus 创建消息状态记录
func CreateMessageStatus(msgId string, userId int) error {
	_, err := db.MessageStatus.Create().
		SetMsgId(msgId).
		SetUserId(userId).
		SetIsDelivered(false).
		SetIsRead(false).
		Save(context.TODO())
	
	if err != nil {
		return errors.New("创建消息状态失败")
	}
	return nil
}

// MarkMessageAsDelivered 标记消息为已送达
func MarkMessageAsDelivered(msgId string, userId int) error {
	// 查询所有消息状态并过滤
	allStatus, err := db.MessageStatus.Query().
		All(context.TODO())
	
	if err != nil {
		return errors.New("查询消息状态失败")
	}

	// 过滤出匹配的状态
	var targetStatus *ent.MessageStatus
	for _, s := range allStatus {
		if s.MsgId == msgId && s.UserId == userId {
			targetStatus = s
			break
		}
	}

	if targetStatus == nil {
		return errors.New("消息状态不存在")
	}

	// 更新为已送达
	now := time.Now()
	_, err = targetStatus.Update().
		SetIsDelivered(true).
		SetDeliveredTime(now).
		Save(context.TODO())
	
	if err != nil {
		return errors.New("更新消息送达状态失败")
	}

	return nil
}

// MarkMessageAsRead 标记消息为已读
func MarkMessageAsRead(msgId string, userId int) error {
	// 查询消息状态
	status, err := db.MessageStatus.Query().
		All(context.TODO())
	
	if err != nil {
		return errors.New("查询消息状态失败")
	}

	// 过滤出匹配的状态
	var targetStatus *ent.MessageStatus
	for _, s := range status {
		if s.MsgId == msgId && s.UserId == userId {
			targetStatus = s
			break
		}
	}

	if targetStatus == nil {
		return errors.New("消息状态不存在")
	}

	// 更新为已读
	now := time.Now()
	updateQuery := targetStatus.Update().
		SetIsRead(true).
		SetReadTime(now)
	
	// 如果还未送达，同时标记为已送达
	if !targetStatus.IsDelivered {
		updateQuery = updateQuery.
			SetIsDelivered(true).
			SetDeliveredTime(now)
	}

	_, err = updateQuery.Save(context.TODO())
	
	if err != nil {
		return errors.New("更新消息已读状态失败")
	}

	return nil
}

// GetMessageStatus 获取消息状态
func GetMessageStatus(msgId string, userId int) (*ent.MessageStatus, error) {
	// 查询所有消息状态
	allStatus, err := db.MessageStatus.Query().
		All(context.TODO())
	
	if err != nil {
		return nil, errors.New("查询消息状态失败")
	}

	// 过滤出匹配的状态
	for _, s := range allStatus {
		if s.MsgId == msgId && s.UserId == userId {
			return s, nil
		}
	}

	return nil, errors.New("消息状态不存在")
}

// BuildGroupMessageDetail 构建群聊消息详情
func BuildGroupMessageDetail(msgId string, fromUserId, groupId, msgType int, content string) map[string]interface{} {
	return map[string]interface{}{
		"msgId":      msgId,
		"fromUserId": fromUserId,
		"groupId":    groupId,
		"msgType":    msgType,
		"content":    content,
		"isGroup":    true,
		"createTime": time.Now(),
	}
}
