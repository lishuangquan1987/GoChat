package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// GroupChatRecord holds the schema definition for the GroupChatRecord entity.
type GroupChatRecord struct {
	ent.Schema
}

// Fields of the GroupChatRecord.
func (GroupChatRecord) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID,由发送者产生"),
		field.String("fromUserId").NotEmpty().Comment("发送者ID"),
		field.String("groupId").NotEmpty().Comment("群组ID"),
		field.String("msgType").NotEmpty().Comment("消息类型"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}

// Edges of the GroupChatRecord.
func (GroupChatRecord) Edges() []ent.Edge {
	return nil
}
