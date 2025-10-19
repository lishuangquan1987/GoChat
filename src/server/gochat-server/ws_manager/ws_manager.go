package wsmanager

import (
	authmanager "gochat_server/auth_manager"
	"gochat_server/services"
	"gochat_server/utils"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var dic map[string]*websocket.Conn
var mu sync.Mutex

func init() {
	// 初始化连接池
	dic = make(map[string]*websocket.Conn)

	//保持心跳连接
	go checkHeartbeat()
}

// 定义 WebSocket 升级器
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// 允许所有来源连接（生产环境中应限制来源）
		return true
	},
}

func checkHeartbeat() {
	for {
		mu.Lock()
		for userId, conn := range dic {
			if err := conn.WriteMessage(websocket.PingMessage, []byte{}); err != nil {
				log.Println("Error sending ping:", err)
				conn.Close()
				delete(dic, userId)
			}
		}
		mu.Unlock()
		// 每隔 30 秒发送一次心跳
		time.Sleep(30 * time.Second)
	}
}

func HandleWebSocketConnection(w http.ResponseWriter, r *http.Request) {

	// 获取 token 参数
	userId := r.URL.Query().Get("userId")
	token := r.URL.Query().Get("token")
	if !authmanager.ValidateToken(userId, token) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	//升级http连接为websocket连接
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Error while upgrading connection:", err)
		return
	}

	//将连接添加到连接池中
	addConnection(userId, conn)

	// 将用户标记为在线（缓存）
	if userIdInt, err := strconv.Atoi(userId); err == nil {
		if err := services.CacheOnlineUser(userIdInt); err != nil {
			utils.Warn("Failed to cache online user %s: %v", userId, err)
		}
	}

	log.Printf("User %s connected", userId)

	// 发送欢迎消息
	welcomeMsg := map[string]interface{}{
		"type":    "system",
		"message": "连接成功",
		"time":    time.Now().Unix(),
	}
	conn.WriteJSON(welcomeMsg)

	// 推送离线消息
	go pushOfflineMessages(userId, conn)

	//处理消息接收和发送
	go handleMessages(userId, conn)

}

func addConnection(userId string, conn *websocket.Conn) {
	mu.Lock()
	defer mu.Unlock()
	dic[userId] = conn
}

// handleMessages 处理WebSocket消息
func handleMessages(userId string, conn *websocket.Conn) {
	defer func() {
		mu.Lock()
		delete(dic, userId)
		mu.Unlock()
		conn.Close()
		
		// 从在线用户缓存中移除
		if userIdInt, err := strconv.Atoi(userId); err == nil {
			if err := services.RemoveOnlineUser(userIdInt); err != nil {
				utils.Warn("Failed to remove online user %s: %v", userId, err)
			}
		}
		
		log.Printf("User %s disconnected", userId)
	}()

	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error for user %s: %v", userId, err)
			}
			break
		}

		// 只处理文本消息
		if messageType == websocket.TextMessage {
			log.Printf("Received message from user %s: %s", userId, string(message))
			
			// 使用消息接收处理器处理消息
			// 注意：为避免循环依赖，这里直接处理简单逻辑
			// 复杂的消息处理应该通过HTTP API完成
			
			// 这里可以处理心跳、确认等简单消息
			// 实际的聊天消息发送应该通过 /api/messages/send 接口
			
			// 处理消息状态更新（delivered, read等）
			handleIncomingMessage(userId, message, conn)
		} else if messageType == websocket.PingMessage {
			// 响应Ping消息
			if err := conn.WriteMessage(websocket.PongMessage, nil); err != nil {
				log.Printf("Error sending pong to user %s: %v", userId, err)
				break
			}
		}
	}
}

// GetConnection 获取用户的WebSocket连接
func GetConnection(userId string) (*websocket.Conn, bool) {
	mu.Lock()
	defer mu.Unlock()
	conn, exists := dic[userId]
	return conn, exists
}

// IsUserOnline 检查用户是否在线
func IsUserOnline(userId string) bool {
	mu.Lock()
	defer mu.Unlock()
	_, exists := dic[userId]
	return exists
}

// SendMessageToUser 向指定用户发送消息
func SendMessageToUser(userId string, message interface{}) error {
	conn, exists := GetConnection(userId)
	if !exists {
		return nil // 用户不在线，不发送
	}

	err := conn.WriteJSON(message)
	if err != nil {
		log.Printf("Error sending message to user %s: %v", userId, err)
		return err
	}

	return nil
}

// BroadcastMessage 广播消息给所有在线用户
func BroadcastMessage(message interface{}) {
	mu.Lock()
	defer mu.Unlock()

	for userId, conn := range dic {
		err := conn.WriteJSON(message)
		if err != nil {
			log.Printf("Error broadcasting message to user %s: %v", userId, err)
		}
	}
}

// WSManager 实现 NotificationSender 接口
type WSManager struct{}

// IsUserOnline 实现接口方法
func (w *WSManager) IsUserOnline(userId string) bool {
	return IsUserOnline(userId)
}

// SendMessageToUser 实现接口方法
func (w *WSManager) SendMessageToUser(userId string, message interface{}) error {
	return SendMessageToUser(userId, message)
}

// GetWSManager 获取 WSManager 实例
func GetWSManager() *WSManager {
	return &WSManager{}
}

// pushOfflineMessages 推送离线消息
func pushOfflineMessages(userId string, conn *websocket.Conn) {
	// 为了避免循环依赖，离线消息推送通过HTTP API获取
	// 客户端在连接建立后应该调用 /api/messages/offline 接口获取离线消息
	
	// 发送通知告诉客户端有离线消息
	notification := map[string]interface{}{
		"type":    "notification",
		"message": "请获取离线消息",
		"action":  "fetch_offline_messages",
	}
	
	err := conn.WriteJSON(notification)
	if err != nil {
		log.Printf("Error sending offline message notification to user %s: %v", userId, err)
	}
	
	log.Printf("Offline message notification sent to user %s", userId)
}

// handleIncomingMessage 处理接收到的WebSocket消息
func handleIncomingMessage(userId string, messageData []byte, conn *websocket.Conn) {
	var wsMsg map[string]interface{}
	err := json.Unmarshal(messageData, &wsMsg)
	if err != nil {
		log.Printf("Error unmarshaling message from user %s: %v", userId, err)
		return
	}

	msgType, ok := wsMsg["type"].(string)
	if !ok {
		log.Printf("Invalid message type from user %s", userId)
		return
	}

	log.Printf("Received message type '%s' from user %s", msgType, userId)

	switch msgType {
	case "heartbeat":
		handleHeartbeat(userId, conn)
	case "delivered":
		handleDelivered(userId, wsMsg, conn)
	case "read":
		handleRead(userId, wsMsg, conn)
	default:
		log.Printf("Unknown message type: %s", msgType)
	}
}

// handleHeartbeat 处理心跳消息
func handleHeartbeat(userId string, conn *websocket.Conn) {
	log.Printf("Heartbeat from user %s", userId)
	// 发送心跳响应
	response := map[string]interface{}{
		"type": "heartbeat",
		"time": time.Now().Unix(),
	}
	conn.WriteJSON(response)
}

// handleDelivered 处理消息送达确认
func handleDelivered(userId string, wsMsg map[string]interface{}, conn *websocket.Conn) {
	data, ok := wsMsg["data"].(map[string]interface{})
	if !ok {
		log.Printf("Invalid data in delivered message from user %s", userId)
		return
	}

	msgId, ok := data["msgId"].(string)
	if !ok {
		log.Printf("Invalid msgId in delivered confirmation from user %s", userId)
		return
	}

	userIdInt, err := strconv.Atoi(userId)
	if err != nil {
		log.Printf("Invalid userId: %s", userId)
		return
	}

	log.Printf("User %s received message %s (delivered)", userId, msgId)

	// 标记消息为已送达
	err = services.MarkMessageAsDelivered(msgId, userIdInt)
	if err != nil {
		log.Printf("Error marking message as delivered: %v", err)
		return
	}

	// 通知发送者消息已送达
	notifyMessageStatus(msgId, userIdInt, "delivered")
}

// handleRead 处理消息已读确认
func handleRead(userId string, wsMsg map[string]interface{}, conn *websocket.Conn) {
	data, ok := wsMsg["data"].(map[string]interface{})
	if !ok {
		log.Printf("Invalid data in read message from user %s", userId)
		return
	}

	msgId, ok := data["msgId"].(string)
	if !ok {
		log.Printf("Invalid msgId in read confirmation from user %s", userId)
		return
	}

	userIdInt, err := strconv.Atoi(userId)
	if err != nil {
		log.Printf("Invalid userId: %s", userId)
		return
	}

	log.Printf("User %s read message %s", userId, msgId)

	// 标记消息为已读
	err = services.MarkMessageAsRead(msgId, userIdInt)
	if err != nil {
		log.Printf("Error marking message as read: %v", err)
		return
	}

	// 通知发送者消息已读
	notifyMessageStatus(msgId, userIdInt, "read")
}

// notifyMessageStatus 通知消息状态更新
func notifyMessageStatus(msgId string, userId int, status string) {
	// 获取消息详情以找到发送者
	messageDetail, err := services.GetMessageDetail(msgId)
	if err != nil {
		log.Printf("Error getting message detail for status notification: %v", err)
		return
	}

	// 构建状态更新消息
	statusMsg := map[string]interface{}{
		"type":   "message_status",
		"msgId":  msgId,
		"userId": userId,
		"status": status,
	}

	// 发送给消息发送者
	if IsUserOnline(strconv.Itoa(messageDetail.FromUserId)) {
		err := SendMessageToUser(strconv.Itoa(messageDetail.FromUserId), statusMsg)
		if err != nil {
			log.Printf("Error sending status update to user %d: %v", messageDetail.FromUserId, err)
		} else {
			log.Printf("Status update sent: message %s is %s by user %d", msgId, status, userId)
		}
	}
}
