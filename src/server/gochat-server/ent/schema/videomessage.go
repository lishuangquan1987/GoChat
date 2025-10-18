package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// VideoMessage holds the schema definition for the VideoMessage entity.
type VideoMessage struct {
	ent.Schema
}

// Fields of the VideoMessage.
func (VideoMessage) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID,由发送者产生"),
		field.String("videoUrl").NotEmpty().Comment("视频URL"),
	}
}

// Edges of the VideoMessage.
func (VideoMessage) Edges() []ent.Edge {
	return nil
}
