package dto

const (
	TEXT_MESSAGE  = iota + 1 // 文本消息
	IMAGE_MESSAGE            // 图片消息
	VIDEO_MESSAGE            // 视频消息
)

type ChatMessage struct {
	MsgId    string `json:"msgId"`
	FromUser string `json:"fromUser"`
	ToUser   string `json:"toUser"`
	MsgType  int    `json:"type"`
}
