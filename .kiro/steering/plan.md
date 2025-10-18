# GoChat 项目详细需求文档

## 项目概述

GoChat 是一个跨平台的实时聊天应用系统，支持私聊和群聊功能。系统采用前后端分离架构，服务端使用 Go 语言开发，客户端支持桌面端（C#/Avalonia）和移动端（MAUI）。

## 技术架构

### 后端技术栈
- **Web框架**: Go + Gin
- **实时通信**: Gorilla WebSocket
- **数据库**: PostgreSQL
- **ORM**: Ent (Facebook's Entity Framework for Go)
- **文件存储**: MinIO (用于存储图片、视频等非文字信息)
- **缓存**: Redka (Redis兼容)

### 前端技术栈
- **Flutter**:windows/linux/macos/andriod/ios

### 通信协议
- **HTTP**: 用户注册、登录、好友管理等基础功能
- **WebSocket**: 实时消息推送和接收

## 功能需求

### 1. 用户管理模块

#### 1.1 用户注册
- 用户可以通过用户名、密码、昵称注册账号
- 支持性别选择（可选）
- 用户名必须唯一
- 密码需要加密存储

#### 1.2 用户登录
- 用户通过用户名和密码登录
- 登录成功后生成认证token
- 支持token验证机制

#### 1.3 用户信息管理
- 用户可以修改昵称
- 用户可以修改密码
- 用户可以查看个人信息

### 2. 好友管理模块

#### 2.1 好友关系
- 用户可以添加好友
- 用户可以删除好友
- 支持好友列表查看
- 好友关系为双向关系

#### 2.2 好友请求
- 发送好友请求
- 接受/拒绝好友请求
- 好友请求通知

### 3. 私聊功能

#### 3.1 在线私聊
根据 README 中的流程图描述：
- 用户A发送消息给用户B（通过HTTP接口）
- 服务器接收消息并存储到数据库
- 服务器通过WebSocket实时推送消息给在线的用户B
- 用户B实时接收到消息

#### 3.2 离线私聊
- 当用户B不在线时，消息存储在数据库中
- 用户B上线后，服务器推送离线消息
- 支持离线消息的批量推送

#### 3.3 消息类型支持
- 文本消息
- 图片消息（存储在MinIO）
- 视频消息（存储在MinIO）

### 4. 群聊功能

#### 4.1 群组管理
- 创建群组
- 群组信息管理（群名、群主等）
- 群成员管理（添加、移除成员）
- 群主权限管理

#### 4.2 群聊消息
- 群内消息发送
- 群消息广播给所有在线成员
- 离线成员消息存储和推送
- 支持多种消息类型（文本、图片、视频）

### 5. 实时通信模块

#### 5.1 WebSocket连接管理
- 用户上线时建立WebSocket连接
- 连接池管理（维护用户ID与连接的映射）
- 心跳检测机制（30秒间隔）
- 连接断开处理

#### 5.2 消息推送
- 实时消息推送
- 离线消息推送
- 群消息广播
- 消息状态管理（已发送、已接收、已读）

### 6. 消息存储模块

#### 6.1 消息记录
- 聊天记录存储
- 消息ID生成和管理
- 消息时间戳记录
- 消息类型标识

#### 6.2 文件存储
- 图片文件上传和存储
- 视频文件上传和存储
- 文件URL生成和管理
- 文件访问权限控制

## 数据模型

### 用户表 (User)
- ID: 主键
- Username: 用户名（唯一）
- Password: 密码（加密）
- Nickname: 昵称
- Sex: 性别（0:男，1:女）

### 好友关系表 (FriendRelationship)
- ID: 主键
- UserId: 用户ID
- FriendId: 好友ID

### 群组表 (Group)
- ID: 主键
- GroupId: 群组ID
- GroupName: 群组名称
- OwnerId: 群主ID
- CreateUserId: 创建者ID
- CreateTime: 创建时间
- Members: 群成员ID列表

### 聊天记录表 (ChatRecord)
- ID: 主键
- MsgId: 消息ID
- FromUserId: 发送者ID
- ToUserId: 接收者ID
- IsGroup: 是否为群聊
- GroupId: 群聊ID（群聊时使用）
- CreateTime: 创建时间

### 文本消息表 (TextMessage)
- ID: 主键
- MsgId: 消息ID
- Text: 文本内容

### 图片消息表 (ImageMessage)
- ID: 主键
- MsgId: 消息ID
- ImageUrl: 图片URL

### 视频消息表 (VideoMessage)
- ID: 主键
- MsgId: 消息ID
- VideoUrl: 视频URL

## API接口设计

### 用户相关接口
- POST /api/user/register - 用户注册
- POST /api/user/login - 用户登录
- GET /api/user/profile - 获取用户信息
- PUT /api/user/profile - 更新用户信息

### 好友相关接口
- GET /api/friends - 获取好友列表
- POST /api/friends/request - 发送好友请求
- POST /api/friends/accept - 接受好友请求
- DELETE /api/friends/{friendId} - 删除好友

### 消息相关接口
- POST /api/messages/send - 发送消息
- GET /api/messages/history - 获取聊天历史
- POST /api/messages/upload - 上传文件

### 群组相关接口
- POST /api/groups - 创建群组
- GET /api/groups - 获取群组列表
- POST /api/groups/{groupId}/members - 添加群成员
- DELETE /api/groups/{groupId}/members/{userId} - 移除群成员

### WebSocket接口
- GET /ws?userId={userId}&token={token} - 建立WebSocket连接

## 消息流程

### 私聊消息流程
1. 用户A通过HTTP接口发送消息
2. 服务器验证用户身份和权限
3. 服务器将消息存储到数据库
4. 服务器检查用户B是否在线
5. 如果用户B在线，通过WebSocket实时推送消息
6. 如果用户B离线，消息标记为待推送
7. 用户B上线时，推送离线消息

### 群聊消息流程
1. 用户A通过HTTP接口发送群消息
2. 服务器验证用户身份和群成员权限
3. 服务器将消息存储到数据库
4. 服务器获取群成员列表
5. 对每个在线群成员通过WebSocket推送消息
6. 对离线群成员标记消息为待推送
7. 离线成员上线时推送未读消息

## 非功能需求

### 性能要求
- 支持并发用户数：1000+
- 消息延迟：< 100ms
- 文件上传大小限制：图片 < 10MB，视频 < 100MB

### 安全要求
- 用户密码加密存储
- API接口需要身份验证
- WebSocket连接需要token验证
- 文件上传安全检查

### 可用性要求
- 系统可用性：99.9%
- 支持断线重连
- 消息可靠性保证

## 部署要求

### 服务器环境
- Go 1.24+
- PostgreSQL 12+
- MinIO服务
- Redis/Redka

### 客户端环境
- 桌面端：支持Windows、macOS、Linux
- 移动端：支持Android、iOS

## 开发阶段规划

### 第一阶段：基础功能
- 用户注册登录
- 基础的私聊功能
- WebSocket连接管理

### 第二阶段：完善功能
- 好友管理
- 群聊功能
- 文件消息支持

### 第三阶段：优化和扩展
- 消息状态管理
- 离线消息优化
- 性能优化

## 当前实现状态

根据代码分析，当前已实现：
- 基础项目结构搭建
- 用户注册登录功能
- 数据模型定义（Ent schema）
- WebSocket连接管理基础框架
- 消息DTO定义

待实现功能：
- 消息发送和接收处理逻辑
- 好友管理功能
- 群聊功能
- 文件上传和存储
- 客户端应用开发

## UI需求
使用Flutter实现类似微信绿色风格的UI界面，界面简单清爽
