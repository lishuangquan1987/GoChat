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

// Register 用户注册
func Register(c *gin.Context) {
	var parameter struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
		Nickname string `json:"nickname" binding:"required"`
		Sex      int    `json:"sex"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	user, err := services.Register(parameter.Username, parameter.Password, parameter.Nickname, parameter.Sex)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "注册成功",
		Data:    user,
	})
}

// Login 用户登录
func Login(c *gin.Context) {
	var parameter struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	loginResp, err := services.Login(parameter.Username, parameter.Password)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    401,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "登录成功",
		Data:    loginResp,
	})
}

// GetProfile 获取用户信息
func GetProfile(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	user, err := services.GetUserByID(userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    404,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "获取成功",
		Data:    user,
	})
}

// UpdateProfile 更新用户信息（兼容旧版本）
func UpdateProfile(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	var parameter struct {
		Nickname  *string `json:"nickname"`
		Sex       *int    `json:"sex"`
		Avatar    *string `json:"avatar"`
		Signature *string `json:"signature"`
		Region    *string `json:"region"`
		Birthday  *string `json:"birthday"` // ISO 8601格式: "2006-01-02"
		Status    *string `json:"status"`
	}

	if err := c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "参数错误: " + err.Error(),
		})
		return
	}

	// 解析生日
	var birthday *time.Time
	if parameter.Birthday != nil && *parameter.Birthday != "" {
		parsed, err := time.Parse("2006-01-02", *parameter.Birthday)
		if err == nil {
			birthday = &parsed
		}
	}

	user, err := services.UpdateUserProfile(userID, parameter.Nickname, parameter.Sex, parameter.Avatar, parameter.Signature, parameter.Region, birthday, parameter.Status)
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
		Data:    user,
	})
}

// Logout 用户登出
func Logout(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	err := services.Logout(userID)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "登出成功",
		Data:    nil,
	})
}

// SearchUsers 搜索用户
func SearchUsers(c *gin.Context) {
	userID, ok := middlewares.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
			Code:    401,
			Message: "未授权",
		})
		return
	}

	// 获取查询参数
	keyword := c.Query("keyword")
	if keyword == "" {
		c.JSON(http.StatusBadRequest, dto.ErrorResponse{
			Code:    400,
			Message: "搜索关键词不能为空",
		})
		return
	}

	// 获取可选参数
	excludeFriends := c.DefaultQuery("excludeFriends", "false") == "true"
	limitStr := c.DefaultQuery("limit", "20")
	limit := 20
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
		limit = l
	}

	// 搜索用户
	users, err := services.SearchUsers(keyword, excludeFriends, userID, limit)
	if err != nil {
		c.JSON(http.StatusOK, dto.ErrorResponse{
			Code:    400,
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, dto.Response{
		Code:    0,
		Message: "搜索成功",
		Data:    users,
	})
}
