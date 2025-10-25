package controllers

import (
	"gochat_server/dto"
	"gochat_server/middlewares"
	"gochat_server/services"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// SetPrivateDoNotDisturb 设置私聊免打扰
func SetPrivateDoNotDisturb(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		TargetUserID int        `json:"targetUserId" binding:"required"`
		StartTime    *time.Time `json:"startTime"`
		EndTime      *time.Time `json:"endTime"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err := services.SetPrivateDoNotDisturb(userID, parameter.TargetUserID, parameter.StartTime, parameter.EndTime)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "设置成功",
		Data:    nil,
	})
}

// SetGroupDoNotDisturb 设置群聊免打扰
func SetGroupDoNotDisturb(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		TargetGroupID int        `json:"targetGroupId" binding:"required"`
		StartTime     *time.Time `json:"startTime"`
		EndTime       *time.Time `json:"endTime"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err := services.SetGroupDoNotDisturb(userID, parameter.TargetGroupID, parameter.StartTime, parameter.EndTime)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "设置成功",
		Data:    nil,
	})
}

// SetGlobalDoNotDisturb 设置全局免打扰
func SetGlobalDoNotDisturb(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		StartTime *time.Time `json:"startTime"`
		EndTime   *time.Time `json:"endTime"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	err := services.SetGlobalDoNotDisturb(userID, parameter.StartTime, parameter.EndTime)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "设置成功",
		Data:    nil,
	})
}

// RemovePrivateDoNotDisturb 移除私聊免打扰
func RemovePrivateDoNotDisturb(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	targetUserIDStr := c.Param("targetUserId")
	targetUserID, err := strconv.Atoi(targetUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的用户ID",
		})
		return
	}

	err = services.RemovePrivateDoNotDisturb(userID, targetUserID)
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

// RemoveGroupDoNotDisturb 移除群聊免打扰
func RemoveGroupDoNotDisturb(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	targetGroupIDStr := c.Param("targetGroupId")
	targetGroupID, err := strconv.Atoi(targetGroupIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "无效的群组ID",
		})
		return
	}

	err = services.RemoveGroupDoNotDisturb(userID, targetGroupID)
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

// RemoveGlobalDoNotDisturb 移除全局免打扰
func RemoveGlobalDoNotDisturb(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	err := services.RemoveGlobalDoNotDisturb(userID)
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

// GetDoNotDisturbSettings 获取免打扰设置列表
func GetDoNotDisturbSettings(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	settings, err := services.GetDoNotDisturbSettings(userID)
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
		Data:    settings,
	})
}

// CheckDoNotDisturbStatus 检查免打扰状态
func CheckDoNotDisturbStatus(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	targetUserIDStr := c.Query("targetUserId")
	targetGroupIDStr := c.Query("targetGroupId")

	var targetUserID *int
	var targetGroupID *int

	if targetUserIDStr != "" {
		id, err := strconv.Atoi(targetUserIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, dto.ErrorResponse{
				Code:    400,
				Message: "无效的用户ID",
			})
			return
		}
		targetUserID = &id
	}

	if targetGroupIDStr != "" {
		id, err := strconv.Atoi(targetGroupIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, dto.ErrorResponse{
				Code:    400,
				Message: "无效的群组ID",
			})
			return
		}
		targetGroupID = &id
	}

	isActive, err := services.IsDoNotDisturbActive(userID, targetUserID, targetGroupID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "查询成功",
		Data: map[string]interface{}{
			"isActive": isActive,
		},
	})
}