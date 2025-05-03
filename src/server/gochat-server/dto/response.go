package dto


type Response struct{
	Code    int         `json:"code"`
	Msg string	  `json:"msg"`
	Data    interface{} `json:"data"`
}

func SuccessResponse(data interface{}) Response {
	return Response{
		Code: 0,
		Msg:  "success",
		Data: data,
	}
}
func ErrorResponseWithError(err error) Response {
	return Response{
		Code: -1,
		Msg:  err.Error(),
		Data: nil,
	}
}
func ErrorResponseWithMsg(msg string) Response {
	return Response{
		Code: -1,
		Msg:  msg,
		Data: nil,
	}
}