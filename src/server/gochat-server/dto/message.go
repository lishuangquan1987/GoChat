package dto

const (
	TEXT_MESSAGE  = iota + 1 // 文本消息
	IMAGE_MESSAGE            // 图片消息
	VIDEO_MESSAGE            // 视频消息
)

// 消息体，记录是什么消息
type ChatMessage struct {
	MsgId    string `json:"msgId"`
	FromUser string `json:"fromUser"`
	ToUser   string `json:"toUser"`
	MsgType  int    `json:"type"`
	Time	 int64  `json:"time"`
}
type TextMessage struct {
	MsgId	string `json:"msgId"`
	Text 	string `json:"text"`	
}
type ImageMessage struct {
	MsgId	string `json:"msgId"`
	ImageUrl string `json:"imageUrl"`
}
type VideoMessage struct {
	MsgId	string `json:"msgId"`
	VideoUrl string `json:"videoUrl"`
}
