package services

import (
	"context"
	"encoding/json"
	"fmt"
	"gochat_server/configs"
	"gochat_server/ent"
	"gochat_server/utils"
	"time"

	"github.com/nalgeon/redka"
)

var cache *redka.DB

func InitCache() error {
	if !configs.Cfg.Redka.Enabled {
		utils.Info("Redka cache is disabled")
		return nil
	}

	var err error
	cache, err = redka.Open(configs.Cfg.Redka.Path, nil)
	if err != nil {
		return fmt.Errorf("failed to open Redka cache: %w", err)
	}

	utils.Info("Redka cache initialized at: %s", configs.Cfg.Redka.Path)
	return nil
}

func CloseCache() error {
	if cache != nil {
		return cache.Close()
	}
	return nil
}

func userCacheKey(userId int) string {
	return fmt.Sprintf("user:%d", userId)
}

func friendListCacheKey(userId int) string {
	return fmt.Sprintf("friend_list:%d", userId)
}

func userGroupsCacheKey(userId int) string {
	return fmt.Sprintf("user_groups:%d", userId)
}

func groupMembersCacheKey(groupId int) string {
	return fmt.Sprintf("group_members:%d", groupId)
}

func setWithTTL(key, value string, ttl time.Duration) error {
	if cache == nil {
		return nil
	}
	
	err := cache.Str().Set(key, value)
	if err != nil {
		return err
	}
	
	return cache.Key().Expire(key, ttl)
}

func GetUserByIDWithCache(userId int) (*ent.User, error) {
	if cache == nil {
		return db.User.Get(context.TODO(), userId)
	}

	key := userCacheKey(userId)
	
	data, err := cache.Str().Get(key)
	if err == nil {
		dataStr := data.String()
		if dataStr != "" {
			var user ent.User
			if err := json.Unmarshal([]byte(dataStr), &user); err == nil {
				utils.Debug("Cache hit for user: %d", userId)
				return &user, nil
			}
		}
	}

	user, err := db.User.Get(context.TODO(), userId)
	if err != nil {
		return nil, err
	}

	CacheUser(user)
	utils.Debug("Cache miss for user: %d, cached from DB", userId)
	return user, nil
}

func CacheUser(user *ent.User) error {
	if cache == nil {
		return nil
	}

	key := userCacheKey(user.ID)
	data, err := json.Marshal(user)
	if err != nil {
		return err
	}

	ttl := time.Duration(configs.Cfg.Redka.CacheTTL) * time.Second
	return setWithTTL(key, string(data), ttl)
}

func InvalidateUserCache(userId int) error {
	if cache == nil {
		return nil
	}

	key := userCacheKey(userId)
	_, err := cache.Key().Delete(key)
	return err
}

func GetCachedFriendList(userId int) ([]*ent.User, bool) {
	if cache == nil {
		return nil, false
	}

	key := friendListCacheKey(userId)
	data, err := cache.Str().Get(key)
	if err != nil {
		return nil, false
	}

	dataStr := data.String()
	if dataStr == "" {
		return nil, false
	}

	var friends []*ent.User
	if err := json.Unmarshal([]byte(dataStr), &friends); err != nil {
		return nil, false
	}

	return friends, true
}

func CacheFriendList(userId int, friends []*ent.User) error {
	if cache == nil {
		return nil
	}

	key := friendListCacheKey(userId)
	data, err := json.Marshal(friends)
	if err != nil {
		return err
	}

	ttl := time.Duration(configs.Cfg.Redka.CacheTTL) * time.Second
	return setWithTTL(key, string(data), ttl)
}

func InvalidateFriendListCache(userId int) error {
	if cache == nil {
		return nil
	}

	key := friendListCacheKey(userId)
	_, err := cache.Key().Delete(key)
	return err
}

func GetCachedUserGroups(userId int) ([]*ent.Group, bool) {
	if cache == nil {
		return nil, false
	}

	key := userGroupsCacheKey(userId)
	data, err := cache.Str().Get(key)
	if err != nil {
		return nil, false
	}

	dataStr := data.String()
	if dataStr == "" {
		return nil, false
	}

	var groups []*ent.Group
	if err := json.Unmarshal([]byte(dataStr), &groups); err != nil {
		return nil, false
	}

	return groups, true
}

func CacheUserGroups(userId int, groups []*ent.Group) error {
	if cache == nil {
		return nil
	}

	key := userGroupsCacheKey(userId)
	data, err := json.Marshal(groups)
	if err != nil {
		return err
	}

	ttl := time.Duration(configs.Cfg.Redka.CacheTTL) * time.Second
	return setWithTTL(key, string(data), ttl)
}

func InvalidateUserGroupsCache(userId int) error {
	if cache == nil {
		return nil
	}

	key := userGroupsCacheKey(userId)
	_, err := cache.Key().Delete(key)
	return err
}

func GetCachedGroupMembers(groupId int) ([]*ent.User, bool) {
	if cache == nil {
		return nil, false
	}

	key := groupMembersCacheKey(groupId)
	data, err := cache.Str().Get(key)
	if err != nil {
		return nil, false
	}

	dataStr := data.String()
	if dataStr == "" {
		return nil, false
	}

	var members []*ent.User
	if err := json.Unmarshal([]byte(dataStr), &members); err != nil {
		return nil, false
	}

	return members, true
}

func CacheGroupMembers(groupId int, members []*ent.User) error {
	if cache == nil {
		return nil
	}

	key := groupMembersCacheKey(groupId)
	data, err := json.Marshal(members)
	if err != nil {
		return err
	}

	ttl := time.Duration(configs.Cfg.Redka.CacheTTL) * time.Second
	return setWithTTL(key, string(data), ttl)
}

func InvalidateGroupMembersCache(groupId int) error {
	if cache == nil {
		return nil
	}

	key := groupMembersCacheKey(groupId)
	_, err := cache.Key().Delete(key)
	return err
}

func CacheOnlineUser(userId int) error {
	if cache == nil {
		return nil
	}

	key := fmt.Sprintf("online:%d", userId)
	ttl := time.Duration(configs.Cfg.Redka.CacheTTL) * time.Second
	return setWithTTL(key, "1", ttl)
}

func IsUserOnline(userId int) bool {
	if cache == nil {
		return false
	}

	key := fmt.Sprintf("online:%d", userId)
	data, err := cache.Str().Get(key)
	return err == nil && data.String() == "1"
}

func RemoveOnlineUser(userId int) error {
	if cache == nil {
		return nil
	}

	key := fmt.Sprintf("online:%d", userId)
	_, err := cache.Key().Delete(key)
	return err
}

func GetCacheStats() map[string]interface{} {
	if cache == nil {
		return map[string]interface{}{
			"enabled": false,
		}
	}

	keys, _ := cache.Key().Keys("*")
	
	return map[string]interface{}{
		"enabled":      true,
		"total_keys":   len(keys),
		"path":         configs.Cfg.Redka.Path,
		"cache_ttl":    configs.Cfg.Redka.CacheTTL,
		"hot_data_ttl": configs.Cfg.Redka.HotDataTTL,
	}
}

// Chat history cache functions
func GetCachedChatHistory(userId1, userId2 int, page int) ([]map[string]interface{}, bool) {
	// Simplified implementation - return cache miss
	return nil, false
}

func CacheChatHistory(userId1, userId2 int, page int, messages []map[string]interface{}) error {
	// Simplified implementation - no caching for now
	return nil
}

func InvalidateChatHistoryCache(userId1, userId2 int) error {
	// Simplified implementation
	return nil
}

func GetCachedGroupChatHistory(groupId int, page int) ([]map[string]interface{}, bool) {
	// Simplified implementation - return cache miss
	return nil, false
}

func CacheGroupChatHistory(groupId int, page int, messages []map[string]interface{}) error {
	// Simplified implementation - no caching for now
	return nil
}

func InvalidateGroupChatHistoryCache(groupId int) error {
	// Simplified implementation
	return nil
}

// Hot user functions
func MarkUserAsHot(userId int) error {
	if cache == nil {
		return nil
	}

	key := fmt.Sprintf("user_access_count:%d", userId)
	
	// Increase access count
	count, err := cache.Str().Incr(key, 1)
	if err != nil {
		return err
	}

	// Set counter expiration time (1 hour)
	cache.Key().Expire(key, time.Hour)

	// If access count exceeds threshold, mark as hot user
	if count >= 10 {
		user, err := db.User.Get(context.TODO(), userId)
		if err == nil {
			CacheHotUser(user)
			utils.Debug("User %d marked as hot user (access count: %d)", userId, count)
		}
	}

	return nil
}

func CacheHotUser(user *ent.User) error {
	if cache == nil {
		return nil
	}

	key := fmt.Sprintf("hot_user:%d", user.ID)
	data, err := json.Marshal(user)
	if err != nil {
		return err
	}

	ttl := time.Duration(configs.Cfg.Redka.HotDataTTL) * time.Second
	return setWithTTL(key, string(data), ttl)
}

func GetHotUserByID(userId int) (*ent.User, error) {
	if cache == nil {
		return nil, fmt.Errorf("cache not available")
	}

	key := fmt.Sprintf("hot_user:%d", userId)
	data, err := cache.Str().Get(key)
	if err != nil {
		return nil, fmt.Errorf("hot user cache miss")
	}

	dataStr := data.String()
	if dataStr == "" {
		return nil, fmt.Errorf("hot user cache miss")
	}

	var user ent.User
	if err := json.Unmarshal([]byte(dataStr), &user); err != nil {
		return nil, err
	}

	utils.Debug("Hot cache hit for user: %d", userId)
	return &user, nil
}