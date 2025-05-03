package controllers

import (
	"gochat_server/dto"
	"gochat_server/ent"
	"gochat_server/services"

	"github.com/gin-gonic/gin"
)

func (c *gin.Context) Login() {
	var parameter struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}

	var err error
	if err = c.ShouldBindJSON(&parameter); err != nil {
		c.JSON(200, dto.ErrorResponseWithError(err))
		return
	}

	var user *ent.User
	user, err = services.Login(parameter.Username, parameter.Password)
	if err != nil {
		c.JSON(200, dto.ErrorResponseWithError(err))
		return
	}

	c.JSON(200, dto.SuccessResponse(user))
}
