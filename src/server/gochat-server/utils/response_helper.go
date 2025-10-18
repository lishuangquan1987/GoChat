package utils

import (
	"gochat_server/dto"
	"net/http"

	"github.com/gin-gonic/gin"
)

// RespondSuccess 返回成功响应
func RespondSuccess(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, dto.SuccessResponse(data))
}

// RespondError 返回错误响应
func RespondError(c *gin.Context, err error) {
	if appErr, ok := err.(*AppError); ok {
		// 应用自定义错误
		statusCode := getHTTPStatusCode(appErr.Code)
		c.JSON(statusCode, dto.NewErrorResponse(appErr.Code, appErr.Message, appErr.Err))
	} else {
		// 普通错误
		c.JSON(http.StatusInternalServerError, dto.NewErrorResponse(
			dto.CodeInternalError,
			"服务器内部错误",
			err,
		))
	}
}

// RespondErrorWithCode 返回指定错误码的错误响应
func RespondErrorWithCode(c *gin.Context, code int, message string) {
	statusCode := getHTTPStatusCode(code)
	c.JSON(statusCode, dto.ErrorResponseWithCode(code, message))
}

// RespondBadRequest 返回400错误
func RespondBadRequest(c *gin.Context, message string) {
	c.JSON(http.StatusBadRequest, dto.ErrorResponseWithCode(dto.CodeInvalidParam, message))
}

// RespondUnauthorized 返回401错误
func RespondUnauthorized(c *gin.Context, message string) {
	c.JSON(http.StatusUnauthorized, dto.ErrorResponseWithCode(dto.CodeUnauthorized, message))
}

// RespondForbidden 返回403错误
func RespondForbidden(c *gin.Context, message string) {
	c.JSON(http.StatusForbidden, dto.ErrorResponseWithCode(dto.CodeForbidden, message))
}

// RespondNotFound 返回404错误
func RespondNotFound(c *gin.Context, message string) {
	c.JSON(http.StatusNotFound, dto.ErrorResponseWithCode(dto.CodeNotFound, message))
}

// RespondConflict 返回409错误
func RespondConflict(c *gin.Context, message string) {
	c.JSON(http.StatusConflict, dto.ErrorResponseWithCode(dto.CodeConflict, message))
}

// RespondInternalError 返回500错误
func RespondInternalError(c *gin.Context, message string) {
	c.JSON(http.StatusInternalServerError, dto.ErrorResponseWithCode(dto.CodeInternalError, message))
}

// getHTTPStatusCode 根据应用错误码获取HTTP状态码
func getHTTPStatusCode(code int) int {
	switch code {
	case dto.CodeSuccess:
		return http.StatusOK
	case dto.CodeInvalidParam:
		return http.StatusBadRequest
	case dto.CodeUnauthorized:
		return http.StatusUnauthorized
	case dto.CodeForbidden:
		return http.StatusForbidden
	case dto.CodeNotFound:
		return http.StatusNotFound
	case dto.CodeConflict:
		return http.StatusConflict
	case dto.CodeValidationFailed:
		return http.StatusUnprocessableEntity
	case dto.CodeInternalError, dto.CodeDatabaseError, dto.CodeWebSocketError, dto.CodeFileError, dto.CodeCacheError:
		return http.StatusInternalServerError
	default:
		return http.StatusInternalServerError
	}
}
