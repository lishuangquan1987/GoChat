package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

// ChatRecord holds the schema definition for the ChatRecord entity.
type ChatRecord struct {
	ent.Schema
}

// Fields of the ChatRecord.
func (ChatRecord) Fields() []ent.Field {
	return []ent.Field{
		field.String("msgId").NotEmpty().Comment("消息ID，关联Message表"),
		field.Int("fromUserId").Comment("发送者ID"),
		field.Int("toUserId").Comment("接收者ID"),
		field.Int("msgType").Comment("消息类型: 1-文本, 2-图片, 3-视频"),
		field.Bool("isGroup").Default(false).Comment("是否为群聊"),
		field.Int("groupId").Optional().Comment("群聊ID，仅群聊时有值"),
		field.Time("createTime").Default(time.Now).Comment("创建时间"),
	}
}

// Edges of the ChatRecord.
func (ChatRecord) Edges() []ent.Edge {
	return nil
}

// Indexes of the ChatRecord.
func (ChatRecord) Indexes() []ent.Index {
	return []ent.Index{
		// 消息ID索引，用于快速查找消息
		index.Fields("msgId").Unique(),
		// 发送者和接收者组合索引，用于查询聊天历史
		index.Fields("fromUserId", "toUserId"),
		// 接收者和创建时间索引，用于查询用户收到的消息
		index.Fields("toUserId", "createTime"),
		// 群聊ID和创建时间索引，用于查询群聊历史
		index.Fields("groupId", "createTime"),
	}
}
