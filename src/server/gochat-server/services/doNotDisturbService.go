package services

import (
	"context"
	"fmt"
	"gochat_server/ent"
	"gochat_server/ent/donotdisturb"
	"time"
)

// DoNotDisturbType 免打扰类型
type DoNotDisturbType int

const (
	DoNotDisturbTypePrivate DoNotDisturbType = iota // 私聊免打扰
	DoNotDisturbTypeGroup                           // 群聊免打扰
	DoNotDisturbTypeGlobal                          // 全局免打扰
)

// DoNotDisturbSetting 免打扰设置
type DoNotDisturbSetting struct {
	ID           int                `json:"id"`
	UserID       int                `json:"userId"`
	TargetUserID *int               `json:"targetUserId,omitempty"`
	TargetGroupID *int              `json:"targetGroupId,omitempty"`
	IsGlobal     bool               `json:"isGlobal"`
	StartTime    *time.Time         `json:"startTime,omitempty"`
	EndTime      *time.Time         `json:"endTime,omitempty"`
	Type         DoNotDisturbType   `json:"type"`
	CreatedAt    time.Time          `json:"createdAt"`
	UpdatedAt    time.Time          `json:"updatedAt"`
}

// SetPrivateDoNotDisturb 设置私聊免打扰
func SetPrivateDoNotDisturb(userID, targetUserID int, startTime, endTime *time.Time) error {
	ctx := context.Background()
	
	// 检查是否已存在设置
	existing, err := db.DoNotDisturb.Query().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.TargetUserID(targetUserID),
		).
		First(ctx)
	
	if err != nil && !ent.IsNotFound(err) {
		return fmt.Errorf("查询免打扰设置失败: %v", err)
	}
	
	if existing != nil {
		// 更新现有设置
		update := existing.Update().SetUpdatedAt(time.Now())
		if startTime != nil {
			update = update.SetStartTime(*startTime)
		} else {
			update = update.ClearStartTime()
		}
		if endTime != nil {
			update = update.SetEndTime(*endTime)
		} else {
			update = update.ClearEndTime()
		}
		_, err = update.Save(ctx)
		if err != nil {
			return fmt.Errorf("更新私聊免打扰设置失败: %v", err)
		}
	} else {
		// 创建新设置
		create := db.DoNotDisturb.Create().
			SetUserID(userID).
			SetTargetUserID(targetUserID).
			SetIsGlobal(false)
		if startTime != nil {
			create = create.SetStartTime(*startTime)
		}
		if endTime != nil {
			create = create.SetEndTime(*endTime)
		}
		_, err = create.Save(ctx)
		if err != nil {
			return fmt.Errorf("创建私聊免打扰设置失败: %v", err)
		}
	}
	
	return nil
}

// SetGroupDoNotDisturb 设置群聊免打扰
func SetGroupDoNotDisturb(userID, targetGroupID int, startTime, endTime *time.Time) error {
	ctx := context.Background()
	
	// 检查是否已存在设置
	existing, err := db.DoNotDisturb.Query().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.TargetGroupID(targetGroupID),
		).
		First(ctx)
	
	if err != nil && !ent.IsNotFound(err) {
		return fmt.Errorf("查询群聊免打扰设置失败: %v", err)
	}
	
	if existing != nil {
		// 更新现有设置
		update := existing.Update().SetUpdatedAt(time.Now())
		if startTime != nil {
			update = update.SetStartTime(*startTime)
		} else {
			update = update.ClearStartTime()
		}
		if endTime != nil {
			update = update.SetEndTime(*endTime)
		} else {
			update = update.ClearEndTime()
		}
		_, err = update.Save(ctx)
		if err != nil {
			return fmt.Errorf("更新群聊免打扰设置失败: %v", err)
		}
	} else {
		// 创建新设置
		create := db.DoNotDisturb.Create().
			SetUserID(userID).
			SetTargetGroupID(targetGroupID).
			SetIsGlobal(false)
		if startTime != nil {
			create = create.SetStartTime(*startTime)
		}
		if endTime != nil {
			create = create.SetEndTime(*endTime)
		}
		_, err = create.Save(ctx)
		if err != nil {
			return fmt.Errorf("创建群聊免打扰设置失败: %v", err)
		}
	}
	
	return nil
}

// SetGlobalDoNotDisturb 设置全局免打扰
func SetGlobalDoNotDisturb(userID int, startTime, endTime *time.Time) error {
	ctx := context.Background()
	
	// 检查是否已存在全局设置
	existing, err := db.DoNotDisturb.Query().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.IsGlobal(true),
		).
		First(ctx)
	
	if err != nil && !ent.IsNotFound(err) {
		return fmt.Errorf("查询全局免打扰设置失败: %v", err)
	}
	
	if existing != nil {
		// 更新现有设置
		update := existing.Update().SetUpdatedAt(time.Now())
		if startTime != nil {
			update = update.SetStartTime(*startTime)
		} else {
			update = update.ClearStartTime()
		}
		if endTime != nil {
			update = update.SetEndTime(*endTime)
		} else {
			update = update.ClearEndTime()
		}
		_, err = update.Save(ctx)
		if err != nil {
			return fmt.Errorf("更新全局免打扰设置失败: %v", err)
		}
	} else {
		// 创建新设置
		create := db.DoNotDisturb.Create().
			SetUserID(userID).
			SetIsGlobal(true)
		if startTime != nil {
			create = create.SetStartTime(*startTime)
		}
		if endTime != nil {
			create = create.SetEndTime(*endTime)
		}
		_, err = create.Save(ctx)
		if err != nil {
			return fmt.Errorf("创建全局免打扰设置失败: %v", err)
		}
	}
	
	return nil
}

// RemovePrivateDoNotDisturb 移除私聊免打扰
func RemovePrivateDoNotDisturb(userID, targetUserID int) error {
	ctx := context.Background()
	
	_, err := db.DoNotDisturb.Delete().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.TargetUserID(targetUserID),
		).
		Exec(ctx)
	
	if err != nil {
		return fmt.Errorf("移除私聊免打扰设置失败: %v", err)
	}
	
	return nil
}

// RemoveGroupDoNotDisturb 移除群聊免打扰
func RemoveGroupDoNotDisturb(userID, targetGroupID int) error {
	ctx := context.Background()
	
	_, err := db.DoNotDisturb.Delete().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.TargetGroupID(targetGroupID),
		).
		Exec(ctx)
	
	if err != nil {
		return fmt.Errorf("移除群聊免打扰设置失败: %v", err)
	}
	
	return nil
}

// RemoveGlobalDoNotDisturb 移除全局免打扰
func RemoveGlobalDoNotDisturb(userID int) error {
	ctx := context.Background()
	
	_, err := db.DoNotDisturb.Delete().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.IsGlobal(true),
		).
		Exec(ctx)
	
	if err != nil {
		return fmt.Errorf("移除全局免打扰设置失败: %v", err)
	}
	
	return nil
}

// GetDoNotDisturbSettings 获取用户的免打扰设置列表
func GetDoNotDisturbSettings(userID int) ([]*DoNotDisturbSetting, error) {
	ctx := context.Background()
	
	settings, err := db.DoNotDisturb.Query().
		Where(donotdisturb.UserID(userID)).
		All(ctx)
	
	if err != nil {
		return nil, fmt.Errorf("获取免打扰设置失败: %v", err)
	}
	
	result := make([]*DoNotDisturbSetting, len(settings))
	for i, setting := range settings {
		dndType := DoNotDisturbTypePrivate
		if setting.IsGlobal {
			dndType = DoNotDisturbTypeGlobal
		} else if setting.TargetGroupID != nil {
			dndType = DoNotDisturbTypeGroup
		}
		
		result[i] = &DoNotDisturbSetting{
			ID:            setting.ID,
			UserID:        setting.UserID,
			TargetUserID:  setting.TargetUserID,
			TargetGroupID: setting.TargetGroupID,
			IsGlobal:      setting.IsGlobal,
			StartTime:     setting.StartTime,
			EndTime:       setting.EndTime,
			Type:          dndType,
			CreatedAt:     setting.CreatedAt,
			UpdatedAt:     setting.UpdatedAt,
		}
	}
	
	return result, nil
}

// IsDoNotDisturbActive 检查是否处于免打扰状态
func IsDoNotDisturbActive(userID int, targetUserID *int, targetGroupID *int) (bool, error) {
	ctx := context.Background()
	now := time.Now()
	
	// 检查全局免打扰
	globalSetting, err := db.DoNotDisturb.Query().
		Where(
			donotdisturb.UserID(userID),
			donotdisturb.IsGlobal(true),
		).
		First(ctx)
	
	if err == nil {
		// 存在全局免打扰设置
		if globalSetting.StartTime == nil && globalSetting.EndTime == nil {
			// 永久免打扰
			return true, nil
		} else if globalSetting.StartTime != nil && globalSetting.EndTime != nil {
			// 定时免打扰
			if now.After(*globalSetting.StartTime) && now.Before(*globalSetting.EndTime) {
				return true, nil
			}
		}
	} else if !ent.IsNotFound(err) {
		return false, fmt.Errorf("查询全局免打扰设置失败: %v", err)
	}
	
	// 检查特定对象的免打扰
	var specificSetting *ent.DoNotDisturb
	if targetUserID != nil {
		// 私聊免打扰
		specificSetting, err = db.DoNotDisturb.Query().
			Where(
				donotdisturb.UserID(userID),
				donotdisturb.TargetUserID(*targetUserID),
			).
			First(ctx)
	} else if targetGroupID != nil {
		// 群聊免打扰
		specificSetting, err = db.DoNotDisturb.Query().
			Where(
				donotdisturb.UserID(userID),
				donotdisturb.TargetGroupID(*targetGroupID),
			).
			First(ctx)
	}
	
	if err == nil && specificSetting != nil {
		// 存在特定免打扰设置
		if specificSetting.StartTime == nil && specificSetting.EndTime == nil {
			// 永久免打扰
			return true, nil
		} else if specificSetting.StartTime != nil && specificSetting.EndTime != nil {
			// 定时免打扰
			if now.After(*specificSetting.StartTime) && now.Before(*specificSetting.EndTime) {
				return true, nil
			}
		}
	} else if !ent.IsNotFound(err) {
		return false, fmt.Errorf("查询特定免打扰设置失败: %v", err)
	}
	
	return false, nil
}