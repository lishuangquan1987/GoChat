package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

// FriendRequest holds the schema definition for the FriendRequest entity.
type FriendRequest struct {
	ent.Schema
}

// Fields of the FriendRequest.
func (FriendRequest) Fields() []ent.Field {
	return []ent.Field{
		field.Int("fromUserId").Comment("发送者ID"),
		field.Int("toUserId").Comment("接收者ID"),
		field.String("remark").Optional().Comment("备注信息"),
		field.Int("status").Default(0).Comment("状态: 0-待处理, 1-已接受, 2-已拒绝"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}

// Edges of the FriendRequest.
func (FriendRequest) Edges() []ent.Edge {
	return nil
}

// Indexes of the FriendRequest.
func (FriendRequest) Indexes() []ent.Index {
	return []ent.Index{
		// 接收者ID和状态索引，用于查询待处理的好友请求
		index.Fields("toUserId", "status"),
		// 发送者和接收者组合索引，防止重复请求
		index.Fields("fromUserId", "toUserId"),
	}
}
