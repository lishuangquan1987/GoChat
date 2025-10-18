package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

// FriendRelationship holds the schema definition for the FriendRelationship entity.
type FriendRelationship struct {
	ent.Schema
}

// Fields of the FriendRelationship.
func (FriendRelationship) Fields() []ent.Field {
	return []ent.Field{
		field.Int("userId").Comment("用户ID"),
		field.Int("friendId").Comment("好友ID"),
	}
}

// Edges of the FriendRelationship.
func (FriendRelationship) Edges() []ent.Edge {
	return nil
}

// Indexes of the FriendRelationship.
func (FriendRelationship) Indexes() []ent.Index {
	return []ent.Index{
		// 用户ID索引，用于查询用户的所有好友
		index.Fields("userId"),
		// 用户ID和好友ID组合索引，确保唯一性并加速查询
		index.Fields("userId", "friendId").Unique(),
	}
}
