# GoChat 实现需求文档

## Introduction

GoChat 是一个跨平台的实时聊天应用系统，支持私聊和群聊功能。系统采用前后端分离架构，服务端使用 Go 语言开发，客户端使用 Flutter 实现全平台支持。本文档定义了系统的功能需求和验收标准。

## Glossary

- **GoChat_Server**: Go 语言开发的后端服务器系统
- **GoChat_Client**: Flutter 开发的跨平台客户端应用
- **User**: 注册并使用 GoChat 系统的用户
- **Message**: 用户之间传递的信息，包括文本、图片、视频
- **WebSocket_Connection**: 客户端与服务器之间的实时双向通信连接
- **Chat_Record**: 存储在数据库中的聊天消息记录
- **Friend_Relationship**: 两个用户之间的好友关系
- **Group**: 多个用户组成的群组
- **Token**: 用户身份验证令牌
- **MinIO**: 对象存储服务，用于存储多媒体文件

## Requirements

### Requirement 1: 用户注册与认证

**User Story:** 作为一个新用户，我想要注册账号并登录系统，以便开始使用聊天功能

#### Acceptance Criteria

1. WHEN User 提交注册请求包含用户名、密码和昵称，THE GoChat_Server SHALL 验证用户名唯一性并创建新用户账号
2. WHEN User 提交的用户名已存在，THE GoChat_Server SHALL 返回错误信息"用户名已存在"
3. WHEN User 提交登录请求包含正确的用户名和密码，THE GoChat_Server SHALL 生成并返回有效的 Token
4. WHEN User 提交登录请求包含错误的密码，THE GoChat_Server SHALL 返回错误信息"密码错误"
5. THE GoChat_Server SHALL 使用加密算法存储用户密码

### Requirement 2: WebSocket 连接管理

**User Story:** 作为一个已登录用户，我想要建立实时连接，以便接收即时消息

#### Acceptance Criteria

1. WHEN User 使用有效的 Token 请求 WebSocket 连接，THE GoChat_Server SHALL 建立连接并将其添加到连接池
2. WHEN User 使用无效的 Token 请求 WebSocket 连接，THE GoChat_Server SHALL 拒绝连接并返回 401 状态码
3. WHILE WebSocket_Connection 处于活动状态，THE GoChat_Server SHALL 每 30 秒发送一次心跳消息
4. WHEN WebSocket_Connection 心跳检测失败，THE GoChat_Server SHALL 关闭连接并从连接池移除
5. WHEN User 断开连接，THE GoChat_Server SHALL 从连接池中移除该用户的连接

### Requirement 3: 私聊消息发送与接收

**User Story:** 作为一个用户，我想要发送私聊消息给好友，以便进行一对一交流

#### Acceptance Criteria

1. WHEN User 发送文本消息给在线好友，THE GoChat_Server SHALL 存储消息到数据库并通过 WebSocket 实时推送给接收者
2. WHEN User 发送消息给离线好友，THE GoChat_Server SHALL 存储消息到数据库并标记为待推送
3. WHEN 离线 User 建立 WebSocket 连接，THE GoChat_Server SHALL 推送所有待推送的离线消息
4. THE GoChat_Server SHALL 为每条消息生成唯一的消息 ID
5. THE GoChat_Server SHALL 记录消息的发送时间戳

### Requirement 4: 多媒体消息支持

**User Story:** 作为一个用户，我想要发送图片和视频消息，以便分享多媒体内容

#### Acceptance Criteria

1. WHEN User 上传图片文件小于 10MB，THE GoChat_Server SHALL 存储文件到 MinIO 并返回访问 URL
2. WHEN User 上传视频文件小于 100MB，THE GoChat_Server SHALL 存储文件到 MinIO 并返回访问 URL
3. WHEN User 上传文件超过大小限制，THE GoChat_Server SHALL 返回错误信息
4. THE GoChat_Server SHALL 验证上传文件的类型为图片或视频格式
5. THE GoChat_Server SHALL 将多媒体消息的 URL 存储到对应的消息表中

### Requirement 5: 好友管理

**User Story:** 作为一个用户，我想要添加和管理好友，以便与他们进行聊天

#### Acceptance Criteria

1. WHEN User 发送好友请求给另一个 User，THE GoChat_Server SHALL 创建好友请求记录
2. WHEN User 接受好友请求，THE GoChat_Server SHALL 创建双向好友关系记录
3. WHEN User 拒绝好友请求，THE GoChat_Server SHALL 删除好友请求记录
4. WHEN User 请求好友列表，THE GoChat_Server SHALL 返回所有好友的信息
5. WHEN User 删除好友，THE GoChat_Server SHALL 删除双向好友关系记录

### Requirement 6: 群组管理

**User Story:** 作为一个用户，我想要创建和管理群组，以便进行多人聊天

#### Acceptance Criteria

1. WHEN User 创建群组，THE GoChat_Server SHALL 生成唯一的群组 ID 并设置创建者为群主
2. WHEN 群主添加成员到群组，THE GoChat_Server SHALL 更新群组成员列表
3. WHEN 群主移除成员，THE GoChat_Server SHALL 从群组成员列表中删除该成员
4. WHEN User 请求群组列表，THE GoChat_Server SHALL 返回用户所属的所有群组信息
5. THE GoChat_Server SHALL 记录群组的创建时间

### Requirement 7: 群聊消息

**User Story:** 作为一个群组成员，我想要在群组中发送消息，以便与所有成员交流

#### Acceptance Criteria

1. WHEN 群组成员发送消息，THE GoChat_Server SHALL 存储消息到群聊记录表
2. WHEN 群组成员发送消息，THE GoChat_Server SHALL 推送消息给所有在线的群组成员
3. WHEN 群组有离线成员，THE GoChat_Server SHALL 标记消息为待推送
4. WHEN 离线群组成员上线，THE GoChat_Server SHALL 推送所有未读的群聊消息
5. THE GoChat_Server SHALL 支持群聊中的文本、图片和视频消息

### Requirement 8: 消息历史查询

**User Story:** 作为一个用户，我想要查看聊天历史记录，以便回顾之前的对话

#### Acceptance Criteria

1. WHEN User 请求私聊历史记录，THE GoChat_Server SHALL 返回与指定好友的所有消息记录
2. WHEN User 请求群聊历史记录，THE GoChat_Server SHALL 返回指定群组的所有消息记录
3. THE GoChat_Server SHALL 按时间顺序返回消息记录
4. THE GoChat_Server SHALL 支持分页查询消息历史
5. THE GoChat_Server SHALL 返回消息的完整信息包括发送者、内容、时间和类型

### Requirement 9: Flutter 客户端界面

**User Story:** 作为一个用户，我想要使用简洁美观的界面，以便舒适地使用聊天功能

#### Acceptance Criteria

1. THE GoChat_Client SHALL 使用类似微信的绿色主题配色方案
2. THE GoChat_Client SHALL 提供登录和注册界面
3. THE GoChat_Client SHALL 提供聊天列表界面显示最近对话
4. THE GoChat_Client SHALL 提供聊天界面显示消息气泡
5. THE GoChat_Client SHALL 提供好友列表和群组列表界面

### Requirement 10: 客户端实时通信

**User Story:** 作为一个用户，我想要实时接收消息，以便及时回复对话

#### Acceptance Criteria

1. WHEN GoChat_Client 启动，THE GoChat_Client SHALL 使用 Token 建立 WebSocket 连接
2. WHEN GoChat_Client 接收到 WebSocket 消息，THE GoChat_Client SHALL 更新聊天界面显示新消息
3. WHEN WebSocket_Connection 断开，THE GoChat_Client SHALL 自动尝试重新连接
4. THE GoChat_Client SHALL 在发送消息时显示发送状态（发送中、已发送、失败）
5. THE GoChat_Client SHALL 支持消息通知提醒用户新消息
