package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// ChatRecord holds the schema definition for the ChatRecord entity.
type ChatRecord struct {
	ent.Schema
}

// Fields of the ChatRecord.
func (ChatRecord) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID,由发送者产生"),
		field.String("fromUserId").NotEmpty().Comment("发送者ID"),
		field.String("toUserId").NotEmpty().Comment("接收者ID"),
		field.String("msgType").NotEmpty().Comment("消息类型"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}

// Edges of the ChatRecord.
func (ChatRecord) Edges() []ent.Edge {
	return nil
}
