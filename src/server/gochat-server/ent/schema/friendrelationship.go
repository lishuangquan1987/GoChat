package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// FriendRelationship holds the schema definition for the FriendRelationship entity.
type FriendRelationship struct {
	ent.Schema
}

// Fields of the FriendRelationship.
func (FriendRelationship) Fields() []ent.Field {
	return []ent.Field{
		field.String("userId").NotEmpty().Comment("用户ID"),
		field.String("friendId").NotEmpty().Comment("好友ID"),
	}
}

// Edges of the FriendRelationship.
func (FriendRelationship) Edges() []ent.Edge {
	return nil
}
