package dto

// Response 统一响应结构
type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

// ErrorResponse 错误响应结构
type ErrorResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// SuccessResponse 成功响应
func SuccessResponse(data interface{}) Response {
	return Response{
		Code:    0,
		Message: "success",
		Data:    data,
	}
}

// ErrorResponseWithError 错误响应（从error生成）
func ErrorResponseWithError(err error) Response {
	return Response{
		Code:    -1,
		Message: err.Error(),
		Data:    nil,
	}
}

// ErrorResponseWithMsg 错误响应（从消息生成）
func ErrorResponseWithMsg(msg string) Response {
	return Response{
		Code:    -1,
		Message: msg,
		Data:    nil,
	}
}