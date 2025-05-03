package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// TextMessage holds the schema definition for the TextMessage entity.
type TextMessage struct {
	ent.Schema
}

// Fields of the TextMessage.
func (TextMessage) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID,由发送者产生"),
		field.String("text").NotEmpty().Comment("文本消息"),
	}
}

// Edges of the TextMessage.
func (TextMessage) Edges() []ent.Edge {
	return nil
}
