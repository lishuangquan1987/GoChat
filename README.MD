# GoChat

## 技术栈思考

- server使用go/gin/Gorilla WebSocket

- client使用C#/Avalonia实现桌面跨平台，maui实现移动端跨平台

- http:用户注册、登录等信息

- websocket：服务端主动给客户端发送消息

- minio:存储非文字信息

- 数据库使用postgreysql

- 用户发送消息（http）->接收消息处理（存储数据库）->发送消息处理（分发消息，群消息发送到多个）->websocket发送到客户端

## 聊天过程

### 单聊

对方在线：

<img title="" src="./img/client1-client2.png" alt="loading-ag-83" data-align="inline" style="zoom:100%;">

![loading-ag-88](./img/client1-client2-2.png)

对方不在线：

![loading-ag-93](./img/client1-client2-offline.png)

![loading-ag-100](./img/client1-client2-2-offline.png)

### 群聊
