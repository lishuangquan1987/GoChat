package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// ImageMessage holds the schema definition for the ImageMessage entity.
type ImageMessage struct {
	ent.Schema
}

// Fields of the ImageMessage.
func (ImageMessage) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID,由发送者产生"),
		field.String("imageUrl").NotEmpty().Comment("图片消息"),
	}
}

// Edges of the ImageMessage.
func (ImageMessage) Edges() []ent.Edge {
	return nil
}
