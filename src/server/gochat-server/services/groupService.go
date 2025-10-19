package services

import (
	"context"
	"errors"
	"gochat_server/ent"
	"gochat_server/ent/group"

	"github.com/google/uuid"
)

// CreateGroup 创建群组
func CreateGroup(groupName string, ownerId int, memberIds []int) (*ent.Group, error) {
	// 验证群主是否存在
	_, err := db.User.Get(context.TODO(), ownerId)
	if err != nil {
		return nil, errors.New("群主不存在")
	}

	// 验证所有成员是否存在
	for _, memberId := range memberIds {
		_, err := db.User.Get(context.TODO(), memberId)
		if err != nil {
			return nil, errors.New("成员不存在")
		}
	}

	// 确保群主在成员列表中
	hasOwner := false
	for _, memberId := range memberIds {
		if memberId == ownerId {
			hasOwner = true
			break
		}
	}
	if !hasOwner {
		memberIds = append(memberIds, ownerId)
	}

	// 生成群组ID
	groupId := uuid.New().String()

	// 创建群组
	newGroup, err := db.Group.Create().
		SetGroupId(groupId).
		SetGroupName(groupName).
		SetOwnerId(ownerId).
		SetCreateUserId(ownerId).
		SetMembers(memberIds).
		Save(context.TODO())

	if err != nil {
		return nil, errors.New("创建群组失败")
	}

	// 使所有成员的用户群组缓存失效
	for _, memberId := range memberIds {
		_ = InvalidateUserGroupsCache(memberId)
	}

	return newGroup, nil
}

// GetUserGroups 获取用户所属的群组列表（带缓存）
func GetUserGroups(userId int) ([]*ent.Group, error) {
	// 尝试从缓存获取
	groups, found := GetCachedUserGroups(userId)
	if found {
		return groups, nil
	}

	// 查询所有群组
	allGroups, err := db.Group.Query().All(context.TODO())
	if err != nil {
		return nil, errors.New("查询群组失败")
	}

	// 过滤出用户所属的群组
	userGroups := make([]*ent.Group, 0)
	for _, g := range allGroups {
		for _, memberId := range g.Members {
			if memberId == userId {
				userGroups = append(userGroups, g)
				break
			}
		}
	}

	// 写入缓存
	_ = CacheUserGroups(userId, userGroups)

	return userGroups, nil
}

// GetGroupByID 根据ID获取群组信息
func GetGroupByID(groupId int) (*ent.Group, error) {
	group, err := db.Group.Get(context.TODO(), groupId)
	if err != nil {
		return nil, errors.New("群组不存在")
	}
	return group, nil
}

// GetGroupByGroupID 根据GroupID获取群组信息
func GetGroupByGroupID(groupId string) (*ent.Group, error) {
	group, err := db.Group.Query().
		Where(group.GroupId(groupId)).
		First(context.TODO())
	if err != nil {
		return nil, errors.New("群组不存在")
	}
	return group, nil
}

// AddGroupMembers 添加群成员
func AddGroupMembers(groupId int, userIds []int) error {
	// 获取群组
	g, err := db.Group.Get(context.TODO(), groupId)
	if err != nil {
		return errors.New("群组不存在")
	}

	// 验证所有用户是否存在
	for _, userId := range userIds {
		_, err := db.User.Get(context.TODO(), userId)
		if err != nil {
			return errors.New("用户不存在")
		}
	}

	// 合并成员列表（去重）
	memberMap := make(map[int]bool)
	for _, memberId := range g.Members {
		memberMap[memberId] = true
	}
	for _, userId := range userIds {
		memberMap[userId] = true
	}

	// 转换为切片
	newMembers := make([]int, 0, len(memberMap))
	for memberId := range memberMap {
		newMembers = append(newMembers, memberId)
	}

	// 更新群组成员
	_, err = db.Group.UpdateOneID(groupId).
		SetMembers(newMembers).
		Save(context.TODO())

	if err != nil {
		return errors.New("添加群成员失败")
	}

	// 使群成员缓存失效
	_ = InvalidateGroupMembersCache(groupId)
	
	// 使新成员的用户群组缓存失效
	for _, userId := range userIds {
		_ = InvalidateUserGroupsCache(userId)
	}

	return nil
}

// RemoveGroupMember 移除群成员
func RemoveGroupMember(groupId, userId int) error {
	// 获取群组
	g, err := db.Group.Get(context.TODO(), groupId)
	if err != nil {
		return errors.New("群组不存在")
	}

	// 不能移除群主
	if g.OwnerId == userId {
		return errors.New("不能移除群主")
	}

	// 从成员列表中移除
	newMembers := make([]int, 0)
	found := false
	for _, memberId := range g.Members {
		if memberId != userId {
			newMembers = append(newMembers, memberId)
		} else {
			found = true
		}
	}

	if !found {
		return errors.New("用户不在群组中")
	}

	// 更新群组成员
	_, err = db.Group.UpdateOneID(groupId).
		SetMembers(newMembers).
		Save(context.TODO())

	if err != nil {
		return errors.New("移除群成员失败")
	}

	// 使群成员缓存失效
	_ = InvalidateGroupMembersCache(groupId)
	
	// 使被移除用户的用户群组缓存失效
	_ = InvalidateUserGroupsCache(userId)

	return nil
}

// GetGroupMembers 获取群成员列表（带缓存）
func GetGroupMembers(groupId int) ([]*ent.User, error) {
	// 尝试从缓存获取
	members, found := GetCachedGroupMembers(groupId)
	if found {
		return members, nil
	}

	// 获取群组
	g, err := db.Group.Get(context.TODO(), groupId)
	if err != nil {
		return nil, errors.New("群组不存在")
	}

	// 查询所有成员信息
	members = make([]*ent.User, 0, len(g.Members))
	for _, memberId := range g.Members {
		user, err := db.User.Get(context.TODO(), memberId)
		if err != nil {
			continue // 跳过不存在的用户
		}
		members = append(members, user)
	}

	// 写入缓存
	_ = CacheGroupMembers(groupId, members)

	return members, nil
}

// IsGroupMember 检查用户是否是群成员
func IsGroupMember(groupId, userId int) (bool, error) {
	g, err := db.Group.Get(context.TODO(), groupId)
	if err != nil {
		return false, errors.New("群组不存在")
	}

	for _, memberId := range g.Members {
		if memberId == userId {
			return true, nil
		}
	}

	return false, nil
}

// IsGroupOwner 检查用户是否是群主
func IsGroupOwner(groupId, userId int) (bool, error) {
	g, err := db.Group.Get(context.TODO(), groupId)
	if err != nil {
		return false, errors.New("群组不存在")
	}

	return g.OwnerId == userId, nil
}

// UpdateGroupName 更新群组名称
func UpdateGroupName(groupId int, groupName string) error {
	_, err := db.Group.UpdateOneID(groupId).
		SetGroupName(groupName).
		Save(context.TODO())

	if err != nil {
		return errors.New("更新群组名称失败")
	}

	return nil
}

// TransferGroupOwner 转让群主
func TransferGroupOwner(groupId, newOwnerId int) error {
	// 检查新群主是否是群成员
	isMember, err := IsGroupMember(groupId, newOwnerId)
	if err != nil {
		return err
	}
	if !isMember {
		return errors.New("新群主必须是群成员")
	}

	// 更新群主
	_, err = db.Group.UpdateOneID(groupId).
		SetOwnerId(newOwnerId).
		Save(context.TODO())

	if err != nil {
		return errors.New("转让群主失败")
	}

	return nil
}

// DeleteGroup 解散群组
func DeleteGroup(groupId int) error {
	err := db.Group.DeleteOneID(groupId).Exec(context.TODO())
	if err != nil {
		return errors.New("解散群组失败")
	}

	return nil
}
// GetGroupById 根据ID获取群组信息（别名）
func GetGroupById(groupId int) (*ent.Group, error) {
	return GetGroupByID(groupId)
}