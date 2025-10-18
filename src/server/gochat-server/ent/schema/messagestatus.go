package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

type MessageStatus struct {
	ent.Schema
}

func (MessageStatus) Fields() []ent.Field {
	return []ent.Field{
		field.Int("chatRecordId").Comment("消息记录ID，关联ChatRecord"),
		field.String("status").NotEmpty().Comment("状态：待发送/发送成功/发送失败/已读"),
		field.String("failReason").Optional().Comment("失败原因"),
		field.Time("updateTime").Default(time.Now).Comment("状态更新时间"),
	}
}
