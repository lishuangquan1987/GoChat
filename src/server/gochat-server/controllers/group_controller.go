package controllers

import (
	"gochat_server/dto"
	"gochat_server/middlewares"
	"gochat_server/services"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// CreateGroup 创建群组
func CreateGroup(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		GroupName string `json:"groupName" binding:"required"`
		MemberIds []int  `json:"memberIds" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	group, err := services.CreateGroup(parameter.GroupName, userID, parameter.MemberIds)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "创建成功",
		Data:    group,
	})
}

// GetGroupList 获取群组列表
func GetGroupList(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	groups, err := services.GetUserGroups(userID)
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
		Data:    groups,
	})
}

// GetGroupDetail 获取群组详情
func GetGroupDetail(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	groupIdStr := c.Param("groupId")
	groupId, err := strconv.Atoi(groupIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的群组ID",
		})
		return
	}

	// 检查用户是否是群成员
	isMember, err := services.IsGroupMember(groupId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	if !isMember {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    403,
			Message: "无权查看该群组",
		})
		return
	}

	group, err := services.GetGroupByID(groupId)
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
		Data:    group,
	})
}

// AddGroupMembers 添加群成员
func AddGroupMembers(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	groupIdStr := c.Param("groupId")
	groupId, err := strconv.Atoi(groupIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的群组ID",
		})
		return
	}

	// 检查是否是群主
	isOwner, err := services.IsGroupOwner(groupId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	if !isOwner {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    403,
			Message: "只有群主可以添加成员",
		})
		return
	}

	var parameter struct {
		UserIds []int `json:"userIds" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err = services.AddGroupMembers(groupId, parameter.UserIds)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "添加成功",
		Data:    nil,
	})
}

// RemoveGroupMember 移除群成员
func RemoveGroupMember(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	groupIdStr := c.Param("groupId")
	groupId, err := strconv.Atoi(groupIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的群组ID",
		})
		return
	}

	userIdStr := c.Param("userId")
	removeUserId, err := strconv.Atoi(userIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的用户ID",
		})
		return
	}

	// 检查是否是群主
	isOwner, err := services.IsGroupOwner(groupId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	if !isOwner {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    403,
			Message: "只有群主可以移除成员",
		})
		return
	}

	err = services.RemoveGroupMember(groupId, removeUserId)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "移除成功",
		Data:    nil,
	})
}

// GetGroupMembers 获取群成员列表
func GetGroupMembers(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	groupIdStr := c.Param("groupId")
	groupId, err := strconv.Atoi(groupIdStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的群组ID",
		})
		return
	}

	// 检查用户是否是群成员
	isMember, err := services.IsGroupMember(groupId, userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	if !isMember {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    403,
			Message: "无权查看群成员",
		})
		return
	}

	members, err := services.GetGroupMembers(groupId)
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
		Data:    members,
	})
}
