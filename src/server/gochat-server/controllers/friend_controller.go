package controllers

import (
	"gochat_server/dto"
	"gochat_server/middlewares"
	"gochat_server/services"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// SendFriendRequest 发送好友请求
func SendFriendRequest(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		FriendId int    `json:"friendId" binding:"required"`
		Remark   string `json:"remark"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err := services.SendFriendRequest(userID, parameter.FriendId, parameter.Remark)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "好友请求已发送",
		Data:    nil,
	})
}

// AcceptFriendRequest 接受好友请求
func AcceptFriendRequest(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		RequestId int `json:"requestId" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	// 验证请求是否属于当前用户
	requests, err := services.GetFriendRequests(userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	found := false
	for _, req := range requests {
		if req.ID == parameter.RequestId {
			found = true
			break
		}
	}

	if !found {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    403,
			Message: "无权操作此请求",
		})
		return
	}

	err = services.AcceptFriendRequest(parameter.RequestId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "已接受好友请求",
		Data:    nil,
	})
}

// RejectFriendRequest 拒绝好友请求
func RejectFriendRequest(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		RequestId int `json:"requestId" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	// 验证请求是否属于当前用户
	requests, err := services.GetFriendRequests(userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	found := false
	for _, req := range requests {
		if req.ID == parameter.RequestId {
			found = true
			break
		}
	}

	if !found {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    403,
			Message: "无权操作此请求",
		})
		return
	}

	err = services.RejectFriendRequest(parameter.RequestId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "已拒绝好友请求",
		Data:    nil,
	})
}

// GetFriendList 获取好友列表
func GetFriendList(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	friends, err := services.GetFriendList(userID)
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
		Data:    friends,
	})
}

// GetFriendRequests 获取好友请求列表
func GetFriendRequests(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	requests, err := services.GetFriendRequestsWithUsers(userID)
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
		Data:    requests,
	})
}

// GetSentFriendRequests 获取发送的好友请求列表
func GetSentFriendRequests(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	requests, err := services.GetSentFriendRequests(userID)
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
		Data:    requests,
	})
}

// DeleteFriend 删除好友
func DeleteFriend(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	friendIdStr := c.Param("friendId")
	friendId, err := strconv.Atoi(friendIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的好友ID",
		})
		return
	}

	err = services.DeleteFriend(userID, friendId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "删除好友成功",
		Data:    nil,
	})
}

// UpdateFriendRemark 更新好友备注
func UpdateFriendRemark(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	friendIdStr := c.Param("friendId")
	friendId, err := strconv.Atoi(friendIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的好友ID",
		})
		return
	}

	var parameter struct {
		RemarkName *string  `json:"remarkName"`
		Category   *string  `json:"category"`
		Tags       []string `json:"tags"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err = services.UpdateFriendRemark(userID, friendId, parameter.RemarkName, parameter.Category, parameter.Tags)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "更新成功",
		Data:    nil,
	})
}

// GetFriendWithRemark 获取带备注的好友信息
func GetFriendWithRemark(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	friendIdStr := c.Param("friendId")
	friendId, err := strconv.Atoi(friendIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的好友ID",
		})
		return
	}

	result, err := services.GetFriendWithRemark(userID, friendId)
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
		Data:    result,
	})
}