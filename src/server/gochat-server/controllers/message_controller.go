package controllers

import (
	"gochat_server/dto"
	"gochat_server/middlewares"
	"gochat_server/services"
	wsmanager "gochat_server/ws_manager"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// SendMessage 发送消息
func SendMessage(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		ToUserId int    `json:"toUserId" binding:"required"`
		MsgType  int    `json:"msgType" binding:"required"`
		Content  string `json:"content" binding:"required"`
		GroupId  *int   `json:"groupId"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	// 发送消息
	msgId, err := services.SendMessage(userID, parameter.ToUserId, parameter.MsgType, parameter.Content, parameter.GroupId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	// 如果接收者在线，通过WebSocket推送消息
	isGroup := parameter.GroupId != nil && *parameter.GroupId > 0
	if !isGroup {
		// 私聊消息
		if wsmanager.IsUserOnline(strconv.Itoa(parameter.ToUserId)) {
			// 检查接收者是否设置了免打扰
			isDoNotDisturb, err := services.IsDoNotDisturbActive(parameter.ToUserId, &userID, nil)
			if err != nil {
				// 免打扰检查失败，仍然发送消息但记录错误
				log.Printf("Failed to check do not disturb status: %v", err)
				isDoNotDisturb = false
			}
			
			// 获取消息详情
			messageDetail, err := services.GetMessageDetail(msgId)
			if err == nil {
				// 构建正确的WebSocket消息格式
				wsMessage := map[string]interface{}{
					"type": "message",
					"data": messageDetail,
					"doNotDisturb": isDoNotDisturb, // 添加免打扰标识
				}
				// 推送消息
				wsmanager.SendMessageToUser(strconv.Itoa(parameter.ToUserId), wsMessage)
			}
		}
	} else {
		// 群聊消息 - 推送给所有在线群成员
		members, err := services.GetGroupMembers(*parameter.GroupId)
		if err == nil {
			// 构建群聊消息详情
			groupMessageDetail := services.BuildGroupMessageDetail(msgId, userID, *parameter.GroupId, parameter.MsgType, parameter.Content)
			
			// 广播给所有在线群成员（除了发送者）
			for _, member := range members {
				if member.ID != userID && wsmanager.IsUserOnline(strconv.Itoa(member.ID)) {
					// 检查该成员是否设置了免打扰
					isDoNotDisturb, err := services.IsDoNotDisturbActive(member.ID, nil, parameter.GroupId)
					if err != nil {
						// 免打扰检查失败，仍然发送消息但记录错误
						log.Printf("Failed to check do not disturb status for user %d: %v", member.ID, err)
						isDoNotDisturb = false
					}
					
					// 构建正确的WebSocket消息格式
					wsMessage := map[string]interface{}{
						"type": "message",
						"data": groupMessageDetail,
						"doNotDisturb": isDoNotDisturb, // 添加免打扰标识
					}
					
					wsmanager.SendMessageToUser(strconv.Itoa(member.ID), wsMessage)
				}
			}
		}
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "发送成功",
		Data: map[string]interface{}{
			"msgId": msgId,
		},
	})
}

// GetChatHistory 获取聊天历史
func GetChatHistory(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	// 获取查询参数
	friendIdStr := c.Query("friendId")
	groupIdStr := c.Query("groupId")
	pageStr := c.DefaultQuery("page", "1")
	pageSizeStr := c.DefaultQuery("pageSize", "20")

	page, err := strconv.Atoi(pageStr)
	if err != nil || page < 1 {
		page = 1
	}

	pageSize, err := strconv.Atoi(pageSizeStr)
	if err != nil || pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	var messages []map[string]interface{}
	var total int

	if friendIdStr != "" {
		// 获取私聊历史
		friendId, err := strconv.Atoi(friendIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, dto.ErrorResponse{
				Code:    400,
				Message: "无效的好友ID",
			})
			return
		}

		messages, total, err = services.GetChatHistory(userID, friendId, page, pageSize)
		if err != nil {
			c.JSON(http.StatusOK, dto.ErrorResponse{
				Code:    400,
				Message: err.Error(),
			})
			return
		}
	} else if groupIdStr != "" {
		// 获取群聊历史
		groupId, err := strconv.Atoi(groupIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, dto.ErrorResponse{
				Code:    400,
				Message: "无效的群组ID",
			})
			return
		}

		messages, total, err = services.GetGroupChatHistory(groupId, page, pageSize)
		if err != nil {
			c.JSON(http.StatusOK, dto.ErrorResponse{
				Code:    400,
				Message: err.Error(),
			})
			return
		}
	} else {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "请提供friendId或groupId参数",
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "获取成功",
		Data: map[string]interface{}{
			"messages": messages,
			"total":    total,
			"page":     page,
			"pageSize": pageSize,
		},
	})
}

// GetConversationList 获取会话列表
func GetConversationList(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	conversations, err := services.GetConversationList(userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "获取成功",
		Data:    conversations,
	})
}

// GetOfflineMessages 获取离线消息
func GetOfflineMessages(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	messages, err := services.GetOfflineMessages(userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "获取成功",
		Data:    messages,
	})
}

// UploadFile 上传文件
func UploadFile(c *gin.Context) {
	_, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	// 获取文件类型参数
	fileType := c.PostForm("type")
	if fileType != "image" && fileType != "video" {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "文件类型必须是 image 或 video",
		})
		return
	}

	// 获取上传的文件
	file, fileHeader, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "获取文件失败: " + err.Error(),
		})
		return
	}
	defer file.Close()

	// 上传文件到 MinIO
	url, err := services.UploadFile(file, fileHeader, fileType)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "上传成功",
		Data: map[string]interface{}{
			"url": url,
		},
	})
}

// MarkMessageDelivered 标记消息为已送达
func MarkMessageDelivered(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		MsgId string `json:"msgId" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err := services.MarkMessageAsDelivered(parameter.MsgId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "标记成功",
		Data:    nil,
	})
}

// MarkMessageRead 标记消息为已读
func MarkMessageRead(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		MsgId string `json:"msgId" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err := services.MarkMessageAsRead(parameter.MsgId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "标记成功",
		Data:    nil,
	})
}

// RecallMessage 撤回消息
func RecallMessage(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		MsgId string `json:"msgId" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	// 撤回消息
	messageDetail, err := services.RecallMessage(parameter.MsgId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	// 通过WebSocket通知相关用户消息已撤回
	go func() {
		if messageDetail.IsGroup && messageDetail.GroupId != nil {
			// 群聊消息：通知所有群成员
			members, err := services.GetGroupMembers(*messageDetail.GroupId)
			if err == nil {
				recallNotification := map[string]interface{}{
					"type": "message_recalled",
					"data": map[string]interface{}{
						"msgId":   parameter.MsgId,
						"groupId": *messageDetail.GroupId,
					},
				}
				for _, member := range members {
					wsmanager.SendMessageToUser(strconv.Itoa(member.ID), recallNotification)
				}
			}
		} else {
			// 私聊消息：通知接收者
			recallNotification := map[string]interface{}{
				"type": "message_recalled",
				"data": map[string]interface{}{
					"msgId":     parameter.MsgId,
					"fromUserId": messageDetail.FromUserId,
					"toUserId":   messageDetail.ToUserId,
				},
			}
			wsmanager.SendMessageToUser(strconv.Itoa(messageDetail.ToUserId), recallNotification)
		}
	}()

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "撤回成功",
		Data:    nil,
	})
}

// GetMessageStatus 获取消息状态
func GetMessageStatus(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	msgId := c.Query("msgId")
	if msgId == "" {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "msgId参数不能为空",
		})
		return
	}

	status, err := services.GetMessageStatus(msgId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "获取成功",
		Data: map[string]interface{}{
			"msgId":         status.MsgId,
			"userId":        status.UserId,
			"isDelivered":   status.IsDelivered,
			"isRead":        status.IsRead,
			"deliveredTime": status.DeliveredTime,
			"readTime":      status.ReadTime,
		},
	})
}

// GetUnreadMessageCount 获取未读消息数
func GetUnreadMessageCount(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	friendIdStr := c.DefaultQuery("friendId", "0")
	friendId := 0
	if friendIdStr != "0" {
		if id, err := strconv.Atoi(friendIdStr); err == nil {
			friendId = id
		}
	}

	groupIdStr := c.DefaultQuery("groupId", "")
	var groupId *int
	if groupIdStr != "" {
		if id, err := strconv.Atoi(groupIdStr); err == nil {
			groupId = &id
		}
	}

	count, err := services.GetUnreadMessageCount(userID, friendId, groupId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "获取成功",
		Data: map[string]interface{}{
			"unreadCount": count,
		},
	})
}

// MarkAllMessagesAsRead 标记所有消息为已读
func MarkAllMessagesAsRead(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	friendIdStr := c.DefaultQuery("friendId", "")
	var friendId *int
	if friendIdStr != "" {
		if id, err := strconv.Atoi(friendIdStr); err == nil {
			friendId = &id
		}
	}

	groupIdStr := c.DefaultQuery("groupId", "")
	var groupId *int
	if groupIdStr != "" {
		if id, err := strconv.Atoi(groupIdStr); err == nil {
			groupId = &id
		}
	}

	err := services.MarkAllMessagesAsRead(userID, friendId, groupId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "标记成功",
		Data:    nil,
	})
}
