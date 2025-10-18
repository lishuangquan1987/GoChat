package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

type Message struct {
	ent.Schema
}

func (Message) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Unique().Comment("消息ID"),
		field.String("msgType").NotEmpty().Comment("消息类型: text/image/video等"),
		field.String("content").NotEmpty().Comment("消息内容，文本或URL等"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}
