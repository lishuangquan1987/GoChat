package wsmanager

import (
	authmanager "gochat-server/auth_manager"
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

	//处理消息接收和发送
	go wsManager.handleMessages(conn)

}

func addConnection(userId string, conn *websocket.Conn) {
	mu.Lock()
	defer mu.Unlock()
	dic[userId] = conn
}
