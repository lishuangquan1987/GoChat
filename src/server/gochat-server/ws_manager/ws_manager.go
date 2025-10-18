package wsmanager

import (
	authmanager "gochat_server/auth_manager"
	"log"
	"net/http"
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

		log.Printf("Received message from user %s: %s", userId, string(message))

		// 回显消息（临时实现，后续会在消息处理模块中完善）
		if err := conn.WriteMessage(messageType, message); err != nil {
			log.Printf("Error writing message to user %s: %v", userId, err)
			break
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

// pushOfflineMessages 推送离线消息
func pushOfflineMessages(userId string, conn *websocket.Conn) {
	// 注意：这里需要导入 services 包，但为了避免循环依赖，
	// 我们将在后续优化中处理。暂时记录日志
	log.Printf("TODO: Push offline messages to user %s", userId)
	
	// TODO: 调用 services.GetOfflineMessages 获取离线消息并推送
	// userIdInt, err := strconv.Atoi(userId)
	// if err != nil {
	// 	return
	// }
	// 
	// messages, err := services.GetOfflineMessages(userIdInt)
	// if err != nil {
	// 	log.Printf("Error getting offline messages for user %s: %v", userId, err)
	// 	return
	// }
	// 
	// for _, msg := range messages {
	// 	err := conn.WriteJSON(msg)
	// 	if err != nil {
	// 		log.Printf("Error sending offline message to user %s: %v", userId, err)
	// 		break
	// 	}
	// }
}
