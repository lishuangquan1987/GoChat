package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// Message 基础消息表：存储消息元信息（类型、内容、创建时间）
// 具体内容表 TextMessage/ImageMessage/VideoMessage 通过 msgId 关联
type Message struct {
	ent.Schema
}

// Fields of the Message.
func (Message) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID,由发送者产生"),
		field.String("msgType").NotEmpty().Comment("消息类型: text/image/video 或数值枚举"),
		field.String("content").NotEmpty().Comment("消息内容(冗余存储,便于快速列表展示)"),
		field.Bool("isRevoked").Default(false).Comment("是否已撤回"),
		field.Time("revokeTime").Optional().Nillable().Comment("撤回时间"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}

// Edges of the Message.
func (Message) Edges() []ent.Edge {
	return nil
}

