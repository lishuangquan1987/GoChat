package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

type MessageStatus struct {
	ent.Schema
}

func (MessageStatus) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID"),
		field.Int("userId").Comment("用户ID"),
		field.Bool("isDelivered").Default(false).Comment("是否已送达"),
		field.Bool("isRead").Default(false).Comment("是否已读"),
		field.Time("deliveredTime").Optional().Nillable().Comment("送达时间"),
		field.Time("readTime").Optional().Nillable().Comment("已读时间"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}

func (MessageStatus) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("msgId", "userId").Unique(),
		index.Fields("userId"),
	}
}
