package msgsendhandler

import (
	"gochat_server/services"
	wsmanager "gochat_server/ws_manager"
	"log"
	"strconv"
)

// DispatchMessage 分发消息给接收者
// 用于在消息保存到数据库后，将消息实时推送给在线用户
func DispatchMessage(msgId string, toUserId int, groupId *int) error {
	// 获取消息详情
	messageDetail, err := services.GetMessageDetail(msgId)
	if err != nil {
		log.Printf("Error getting message detail: %v", err)
		return err
	}

	// 判断是否为群聊
	isGroup := groupId != nil && *groupId > 0

	if !isGroup {
		// 私聊消息 - 推送给接收者
		if wsmanager.IsUserOnline(strconv.Itoa(toUserId)) {
			// 构建正确的消息格式
			messageToSend := map[string]interface{}{
				"type": "message",
				"data": messageDetail,
			}
			err := wsmanager.SendMessageToUser(strconv.Itoa(toUserId), messageToSend)
			if err != nil {
				log.Printf("Error sending message to user %d: %v", toUserId, err)
				return err
			}
			log.Printf("Message %s dispatched to user %d", msgId, toUserId)

			// 发送消息通知
			go func() {
				fromUser, err := services.GetUserById(messageDetail.FromUserId)
				if err == nil {
					err = services.SendChatMessageNotification(
						strconv.Itoa(toUserId),
						messageDetail.FromUserId,
						fromUser.Nickname,
						msgId,
						messageDetail.Content,
						false,
						"",
					)
					if err != nil {
						log.Printf("Failed to send chat message notification: %v", err)
					}
				}
			}()
		} else {
			log.Printf("User %d is offline, message %s will be delivered later", toUserId, msgId)
		}
	} else {
		// 群聊消息 - 推送给所有在线群成员
		members, err := services.GetGroupMembers(*groupId)
		if err != nil {
			log.Printf("Error getting group members: %v", err)
			return err
		}

		onlineCount := 0
		groupInfo, _ := services.GetGroupById(*groupId)
		groupName := ""
		if groupInfo != nil {
			groupName = groupInfo.GroupName
		}

		fromUser, _ := services.GetUserById(messageDetail.FromUserId)
		fromUserNickname := ""
		if fromUser != nil {
			fromUserNickname = fromUser.Nickname
		}

		for _, member := range members {
			// 不发送给发送者自己
			if member.ID == messageDetail.FromUserId {
				continue
			}

			if wsmanager.IsUserOnline(strconv.Itoa(member.ID)) {
				// 构建正确的消息格式
				messageToSend := map[string]interface{}{
					"type": "message",
					"data": messageDetail,
				}
				err := wsmanager.SendMessageToUser(strconv.Itoa(member.ID), messageToSend)
				if err != nil {
					log.Printf("Error sending group message to user %d: %v", member.ID, err)
				} else {
					onlineCount++
				}

				// 发送群消息通知
				go func(memberId int) {
					err = services.SendChatMessageNotification(
						strconv.Itoa(memberId),
						messageDetail.FromUserId,
						fromUserNickname,
						msgId,
						messageDetail.Content,
						true,
						groupName,
					)
					if err != nil {
						log.Printf("Failed to send group message notification: %v", err)
					}
				}(member.ID)
			}
		}
		log.Printf("Group message %s dispatched to %d online members", msgId, onlineCount)
	}

	return nil
}

// SendSystemMessage 发送系统消息给指定用户
func SendSystemMessage(userId int, message string) error {
	systemMsg := map[string]interface{}{
		"type":    "system",
		"message": message,
	}

	if wsmanager.IsUserOnline(strconv.Itoa(userId)) {
		return wsmanager.SendMessageToUser(strconv.Itoa(userId), systemMsg)
	}

	return nil
}

// BroadcastSystemMessage 广播系统消息给所有在线用户
func BroadcastSystemMessage(message string) {
	systemMsg := map[string]interface{}{
		"type":    "system",
		"message": message,
	}

	wsmanager.BroadcastMessage(systemMsg)
}

// SendMessageStatusUpdate 发送消息状态更新
func SendMessageStatusUpdate(msgId string, fromUserId int, status string, userId int) error {
	// 构建状态更新消息
	statusMsg := map[string]interface{}{
		"type":   "message_status",
		"msgId":  msgId,
		"userId": userId,
		"status": status,
	}

	// 发送给消息发送者
	if wsmanager.IsUserOnline(strconv.Itoa(fromUserId)) {
		err := wsmanager.SendMessageToUser(strconv.Itoa(fromUserId), statusMsg)
		if err != nil {
			log.Printf("Error sending status update to user %d: %v", fromUserId, err)
			return err
		}
		log.Printf("Status update sent: message %s is %s by user %d", msgId, status, userId)
	}

	return nil
}