package dto

// 错误码定义
const (
	// 成功
	CodeSuccess = 0

	// 客户端错误 (400-499)
	CodeInvalidParam     = 400 // 参数错误
	CodeUnauthorized     = 401 // 未授权
	CodeForbidden        = 403 // 禁止访问
	CodeNotFound         = 404 // 资源不存在
	CodeConflict         = 409 // 资源冲突（如用户名已存在）
	CodeValidationFailed = 422 // 验证失败

	// 服务器错误 (500-599)
	CodeInternalError  = 500 // 服务器内部错误
	CodeDatabaseError  = 501 // 数据库错误
	CodeWebSocketError = 502 // WebSocket错误
	CodeFileError      = 503 // 文件操作错误
	CodeCacheError     = 504 // 缓存错误
)

// Response 统一响应结构
type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// ErrorResponse 错误响应结构
type ErrorResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Error   string `json:"error,omitempty"` // 详细错误信息（开发环境）
}

// SuccessResponse 成功响应
func SuccessResponse(data interface{}) Response {
	return Response{
		Code:    CodeSuccess,
		Message: "success",
		Data:    data,
	}
}

// ErrorResponseWithError 错误响应（从error生成）
func ErrorResponseWithError(err error) Response {
	return Response{
		Code:    CodeInternalError,
		Message: err.Error(),
		Data:    nil,
	}
}

// ErrorResponseWithMsg 错误响应（从消息生成）
func ErrorResponseWithMsg(msg string) Response {
	return Response{
		Code:    CodeInternalError,
		Message: msg,
		Data:    nil,
	}
}

// ErrorResponseWithCode 错误响应（指定错误码）
func ErrorResponseWithCode(code int, msg string) Response {
	return Response{
		Code:    code,
		Message: msg,
		Data:    nil,
	}
}

// NewErrorResponse 创建错误响应
func NewErrorResponse(code int, message string, err error) ErrorResponse {
	resp := ErrorResponse{
		Code:    code,
		Message: message,
	}
	if err != nil {
		resp.Error = err.Error()
	}
	return resp
}