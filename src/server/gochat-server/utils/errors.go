package utils

import (
	"fmt"
	"gochat_server/dto"
)

// AppError 应用错误类型
type AppError struct {
	Code    int
	Message string
	Err     error
}

// Error 实现error接口
func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Err)
	}
	return e.Message
}

// NewAppError 创建应用错误
func NewAppError(code int, message string, err error) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
		Err:     err,
	}
}

// 预定义错误构造函数

// NewInvalidParamError 参数错误
func NewInvalidParamError(message string) *AppError {
	return &AppError{
		Code:    dto.CodeInvalidParam,
		Message: message,
		Err:     nil,
	}
}

// NewUnauthorizedError 未授权错误
func NewUnauthorizedError(message string) *AppError {
	return &AppError{
		Code:    dto.CodeUnauthorized,
		Message: message,
		Err:     nil,
	}
}

// NewForbiddenError 禁止访问错误
func NewForbiddenError(message string) *AppError {
	return &AppError{
		Code:    dto.CodeForbidden,
		Message: message,
		Err:     nil,
	}
}

// NewNotFoundError 资源不存在错误
func NewNotFoundError(message string) *AppError {
	return &AppError{
		Code:    dto.CodeNotFound,
		Message: message,
		Err:     nil,
	}
}

// NewConflictError 资源冲突错误
func NewConflictError(message string) *AppError {
	return &AppError{
		Code:    dto.CodeConflict,
		Message: message,
		Err:     nil,
	}
}

// NewDatabaseError 数据库错误
func NewDatabaseError(err error) *AppError {
	return &AppError{
		Code:    dto.CodeDatabaseError,
		Message: "数据库操作失败",
		Err:     err,
	}
}

// NewInternalError 内部错误
func NewInternalError(err error) *AppError {
	return &AppError{
		Code:    dto.CodeInternalError,
		Message: "服务器内部错误",
		Err:     err,
	}
}

// NewFileError 文件操作错误
func NewFileError(err error) *AppError {
	return &AppError{
		Code:    dto.CodeFileError,
		Message: "文件操作失败",
		Err:     err,
	}
}
