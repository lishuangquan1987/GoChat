package services

import (
	"log"
	"time"
)

// NotificationSender 通知发送器接口，避免循环依赖
type NotificationSender interface {
	IsUserOnline(userId string) bool
	SendMessageToUser(userId string, message interface{}) error
}

var notificationSender NotificationSender

// SetNotificationSender 设置通知发送器
func SetNotificationSender(sender NotificationSender) {
	notificationSender = sender
}

// SendNotificationToUser 向指定用户发送通知
func SendNotificationToUser(userId string, notification map[string]interface{}) error {
	if notificationSender == nil {
		log.Printf("Notification sender not set, notification not sent to user %s", userId)
		return nil
	}

	// 检查用户是否在线
	if !notificationSender.IsUserOnline(userId) {
		log.Printf("User %s is offline, notification not sent", userId)
		return nil // 用户不在线，不发送通知
	}

	// 发送通知
	err := notificationSender.SendMessageToUser(userId, notification)
	if err != nil {
		log.Printf("Failed to send notification to user %s: %v", userId, err)
		return err
	}

	log.Printf("Notification sent to user %s: %s", userId, notification["type"])
	return nil
}

// SendChatMessageNotification 发送聊天消息通知
func SendChatMessageNotification(toUserId string, fromUserId int, fromUserNickname string, msgId string, content string, isGroup bool, groupName string) error {
	var message string
	var notificationType string

	if isGroup {
		message = fromUserNickname + " 在群 " + groupName + " 中发送了消息"
		notificationType = "group_message"
	} else {
		message = fromUserNickname + " 发送了消息"
		notificationType = "private_message"
	}

	notification := map[string]interface{}{
		"type": notificationType,
		"data": map[string]interface{}{
			"msgId":            msgId,
			"fromUserId":       fromUserId,
			"fromUserNickname": fromUserNickname,
			"content":          content,
			"isGroup":          isGroup,
			"groupName":        groupName,
		},
		"message": message,
		"time":    getCurrentTimestamp(),
	}

	return SendNotificationToUser(toUserId, notification)
}

// SendFriendRequestAcceptedNotification 发送好友请求被接受的通知
func SendFriendRequestAcceptedNotification(toUserId string, accepterNickname string) error {
	notification := map[string]interface{}{
		"type": "friend_request_accepted",
		"data": map[string]interface{}{
			"accepterNickname": accepterNickname,
		},
		"message": accepterNickname + " 接受了您的好友请求",
		"time":    getCurrentTimestamp(),
	}

	return SendNotificationToUser(toUserId, notification)
}

// getCurrentTimestamp 获取当前时间戳
func getCurrentTimestamp() int64 {
	return time.Now().Unix()
}