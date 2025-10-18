package msgrecvhandler

import (
	"encoding/json"
	"gochat_server/dto"
	"gochat_server/services"
	msgsendhandler "gochat_server/msg_send_handler"
	"log"
	"strconv"
)

// WSMessageType WebSocket消息类型
const (
	MessageTypeChat      = "chat"      // 聊天消息
	MessageTypeHeartbeat = "heartbeat" // 心跳
	MessageTypeAck       = "ack"       // 消息确认
	MessageTypeDelivered = "delivered" // 消息送达确认
	MessageTypeRead      = "read"      // 消息已读确认
	MessageTypeTyping    = "typing"    // 正在输入
)

// WSMessage WebSocket消息结构
type WSMessage struct {
	Type    string                 `json:"type"`
	Data    map[string]interface{} `json:"data"`
	MsgId   string                 `json:"msgId,omitempty"`
	Time    int64                  `json:"time,omitempty"`
}

// HandleIncomingMessage 处理从客户端接收到的WebSocket消息
func HandleIncomingMessage(userId string, messageData []byte) error {
	var wsMsg WSMessage
	err := json.Unmarshal(messageData, &wsMsg)
	if err != nil {
		log.Printf("Error unmarshaling message from user %s: %v", userId, err)
		return err
	}

	log.Printf("Received message type '%s' from user %s", wsMsg.Type, userId)

	switch wsMsg.Type {
	case MessageTypeChat:
		return handleChatMessage(userId, wsMsg)
	case MessageTypeHeartbeat:
		return handleHeartbeat(userId, wsMsg)
	case MessageTypeAck:
		return handleAck(userId, wsMsg)
	case MessageTypeDelivered:
		return handleDelivered(userId, wsMsg)
	case MessageTypeRead:
		return handleRead(userId, wsMsg)
	case MessageTypeTyping:
		return handleTyping(userId, wsMsg)
	default:
		log.Printf("Unknown message type: %s", wsMsg.Type)
	}

	return nil
}

// handleChatMessage 处理聊天消息
func handleChatMessage(userId string, wsMsg WSMessage) error {
	// 从消息数据中提取必要字段
	toUserIdFloat, ok := wsMsg.Data["toUserId"].(float64)
	if !ok {
		log.Printf("Invalid toUserId in message")
		return nil
	}
	toUserId := int(toUserIdFloat)

	msgTypeFloat, ok := wsMsg.Data["msgType"].(float64)
	if !ok {
		log.Printf("Invalid msgType in message")
		return nil
	}
	msgType := int(msgTypeFloat)

	content, ok := wsMsg.Data["content"].(string)
	if !ok {
		log.Printf("Invalid content in message")
		return nil
	}

	// 检查是否为群聊
	var groupId *int
	if groupIdFloat, ok := wsMsg.Data["groupId"].(float64); ok && groupIdFloat > 0 {
		gid := int(groupIdFloat)
		groupId = &gid
	}

	// 转换userId为int
	fromUserId, err := strconv.Atoi(userId)
	if err != nil {
		log.Printf("Invalid userId: %s", userId)
		return err
	}

	// 保存消息到数据库
	msgId, err := services.SendMessage(fromUserId, toUserId, msgType, content, groupId)
	if err != nil {
		log.Printf("Error saving message: %v", err)
		// 发送错误响应给发送者
		errorMsg := map[string]interface{}{
			"type":    "error",
			"message": err.Error(),
			"refMsgId": wsMsg.MsgId,
		}
		// 这里需要通过ws_manager发送错误消息
		return err
	}

	log.Printf("Message saved with ID: %s", msgId)

	// 分发消息给接收者
	err = msgsendhandler.DispatchMessage(msgId, toUserId, groupId)
	if err != nil {
		log.Printf("Error dispatching message: %v", err)
	}

	// 发送确认消息给发送者
	ackMsg := map[string]interface{}{
		"type":     "ack",
		"msgId":    msgId,
		"refMsgId": wsMsg.MsgId,
		"status":   "sent",
	}
	
	// 注意：这里需要通过ws_manager发送确认消息
	// 由于循环依赖问题，实际发送会在ws_manager中处理
	log.Printf("Message %s acknowledged", msgId)

	return nil
}

// handleHeartbeat 处理心跳消息
func handleHeartbeat(userId string, wsMsg WSMessage) error {
	log.Printf("Heartbeat from user %s", userId)
	// 心跳响应会在ws_manager中自动处理
	return nil
}

// handleAck 处理消息确认（保留兼容性）
func handleAck(userId string, wsMsg WSMessage) error {
	msgId, ok := wsMsg.Data["msgId"].(string)
	if !ok {
		return nil
	}

	log.Printf("User %s acknowledged message %s", userId, msgId)
	
	userIdInt, err := strconv.Atoi(userId)
	if err != nil {
		return err
	}

	// 默认标记为已读
	err = services.MarkMessageAsRead(msgId, userIdInt)
	if err != nil {
		log.Printf("Error marking message as read: %v", err)
	}

	return nil
}

// handleDelivered 处理消息送达确认
func handleDelivered(userId string, wsMsg WSMessage) error {
	msgId, ok := wsMsg.Data["msgId"].(string)
	if !ok {
		log.Printf("Invalid msgId in delivered confirmation")
		return nil
	}

	userIdInt, err := strconv.Atoi(userId)
	if err != nil {
		log.Printf("Invalid userId: %s", userId)
		return err
	}

	log.Printf("User %s received message %s (delivered)", userId, msgId)

	// 标记消息为已送达
	err = services.MarkMessageAsDelivered(msgId, userIdInt)
	if err != nil {
		log.Printf("Error marking message as delivered: %v", err)
		return err
	}

	// 通知发送者消息已送达
	err = notifyMessageStatus(msgId, userIdInt, "delivered")
	if err != nil {
		log.Printf("Error notifying message status: %v", err)
	}

	return nil
}

// handleRead 处理消息已读确认
func handleRead(userId string, wsMsg WSMessage) error {
	msgId, ok := wsMsg.Data["msgId"].(string)
	if !ok {
		log.Printf("Invalid msgId in read confirmation")
		return nil
	}

	userIdInt, err := strconv.Atoi(userId)
	if err != nil {
		log.Printf("Invalid userId: %s", userId)
		return err
	}

	log.Printf("User %s read message %s", userId, msgId)

	// 标记消息为已读
	err = services.MarkMessageAsRead(msgId, userIdInt)
	if err != nil {
		log.Printf("Error marking message as read: %v", err)
		return err
	}

	// 通知发送者消息已读
	err = notifyMessageStatus(msgId, userIdInt, "read")
	if err != nil {
		log.Printf("Error notifying message status: %v", err)
	}

	return nil
}

// notifyMessageStatus 通知消息状态更新
func notifyMessageStatus(msgId string, userId int, status string) error {
	// 获取消息详情以找到发送者
	messageDetail, err := services.GetMessageDetail(msgId)
	if err != nil {
		log.Printf("Error getting message detail for status notification: %v", err)
		return err
	}

	// 通过msg_send_handler发送状态更新给发送者
	err = msgsendhandler.SendMessageStatusUpdate(msgId, messageDetail.FromUserId, status, userId)
	if err != nil {
		log.Printf("Error sending status update: %v", err)
		return err
	}

	log.Printf("Message status notification sent: %s - %s by user %d to sender %d", msgId, status, userId, messageDetail.FromUserId)

	return nil
}

// handleTyping 处理正在输入状态
func handleTyping(userId string, wsMsg WSMessage) error {
	toUserIdFloat, ok := wsMsg.Data["toUserId"].(float64)
	if !ok {
		return nil
	}
	toUserId := int(toUserIdFloat)

	isTyping, ok := wsMsg.Data["isTyping"].(bool)
	if !ok {
		isTyping = true
	}

	log.Printf("User %s typing status to user %d: %v", userId, toUserId, isTyping)

	// 转发正在输入状态给接收者
	typingMsg := map[string]interface{}{
		"type":      "typing",
		"fromUserId": userId,
		"isTyping":  isTyping,
	}

	// 注意：这里需要通过ws_manager发送
	// 由于循环依赖问题，实际发送会在ws_manager中处理
	
	return nil
}

// CreateMessageResponse 创建消息响应
func CreateMessageResponse(msgType string, data interface{}) []byte {
	response := map[string]interface{}{
		"type": msgType,
		"data": data,
	}

	jsonData, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling response: %v", err)
		return nil
	}

	return jsonData
}

// SendErrorResponse 发送错误响应
func SendErrorResponse(errorMsg string, refMsgId string) []byte {
	return CreateMessageResponse("error", map[string]interface{}{
		"message":  errorMsg,
		"refMsgId": refMsgId,
	})
}

// SendAckResponse 发送确认响应
func SendAckResponse(msgId string, refMsgId string) []byte {
	return CreateMessageResponse("ack", map[string]interface{}{
		"msgId":    msgId,
		"refMsgId": refMsgId,
		"status":   "sent",
	})
}
