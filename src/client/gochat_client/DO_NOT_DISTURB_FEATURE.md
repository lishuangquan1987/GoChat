# 免打扰功能实现

## 功能概述

实现了类似微信的免打扰功能，用户可以设置：
- **私聊免打扰**：针对特定用户的消息免打扰
- **群聊免打扰**：针对特定群组的消息免打扰  
- **全局免打扰**：所有消息都免打扰

支持永久免打扰和定时免打扰两种模式。

## 核心特性

### 1. 灵活的免打扰设置
- **永久免打扰**：直到手动取消
- **定时免打扰**：设置开始和结束时间
- **快速选项**：1小时、4小时、8小时、24小时、永久
- **自定义时间**：用户可以自由选择时间段

### 2. 多层级免打扰
- **全局免打扰**：优先级最高，屏蔽所有通知
- **特定对象免打扰**：针对某个用户或群组
- **智能判断**：服务器端自动检查免打扰状态

### 3. 完整的管理界面
- **设置页面入口**：在隐私设置中添加免打扰入口
- **免打扰管理页面**：查看、编辑、删除免打扰设置
- **直观的状态显示**：显示当前是否生效

## 技术实现

### 服务器端

#### 数据模型 (DoNotDisturb Schema)
```go
type DoNotDisturb struct {
    ID            int        `json:"id"`
    UserID        int        `json:"userId"`        // 用户ID
    TargetUserID  *int       `json:"targetUserId"`  // 目标用户ID（私聊）
    TargetGroupID *int       `json:"targetGroupId"` // 目标群组ID（群聊）
    IsGlobal      bool       `json:"isGlobal"`      // 是否全局免打扰
    StartTime     *time.Time `json:"startTime"`     // 开始时间
    EndTime       *time.Time `json:"endTime"`       // 结束时间
    CreatedAt     time.Time  `json:"createdAt"`
    UpdatedAt     time.Time  `json:"updatedAt"`
}
```

#### API接口
- `POST /api/donotdisturb/private` - 设置私聊免打扰
- `POST /api/donotdisturb/group` - 设置群聊免打扰
- `POST /api/donotdisturb/global` - 设置全局免打扰
- `DELETE /api/donotdisturb/private/:targetUserId` - 移除私聊免打扰
- `DELETE /api/donotdisturb/group/:targetGroupId` - 移除群聊免打扰
- `DELETE /api/donotdisturb/global` - 移除全局免打扰
- `GET /api/donotdisturb/settings` - 获取免打扰设置列表
- `GET /api/donotdisturb/status` - 检查免打扰状态

#### 消息发送集成
```go
// 在消息发送时检查免打扰状态
isDoNotDisturb, err := services.IsDoNotDisturbActive(parameter.ToUserId, &userID, nil)

// 在WebSocket消息中添加免打扰标识
wsMessage := map[string]interface{}{
    "type": "message",
    "data": messageDetail,
    "doNotDisturb": isDoNotDisturb,
}
```

### 客户端

#### 数据模型
```dart
class DoNotDisturbSetting {
  final int id;
  final int userId;
  final int? targetUserId;
  final int? targetGroupId;
  final bool isGlobal;
  final DateTime? startTime;
  final DateTime? endTime;
  final DoNotDisturbType type;
  
  // 检查当前是否处于免打扰时间段
  bool get isCurrentlyActive { ... }
  
  // 获取免打扰描述文本
  String get description { ... }
}
```

#### 服务层
```dart
class DoNotDisturbService {
  // 设置各种类型的免打扰
  Future<void> setPrivateDoNotDisturb({...});
  Future<void> setGroupDoNotDisturb({...});
  Future<void> setGlobalDoNotDisturb({...});
  
  // 移除免打扰设置
  Future<void> removePrivateDoNotDisturb(int targetUserId);
  Future<void> removeGroupDoNotDisturb(int targetGroupId);
  Future<void> removeGlobalDoNotDisturb();
  
  // 查询免打扰状态
  Future<List<DoNotDisturbSetting>> getDoNotDisturbSettings();
  Future<bool> checkDoNotDisturbStatus({...});
}
```

#### UI界面
- **DoNotDisturbPage**：免打扰设置管理页面
- **DoNotDisturbDialog**：添加/编辑免打扰设置对话框
- **设置页面集成**：在隐私设置中添加入口

#### 消息处理集成
```dart
void _handleChatMessage(Map<String, dynamic> data) {
  // 检查是否为免打扰消息
  final isDoNotDisturb = data['doNotDisturb'] as bool? ?? false;
  
  // 只有在非免打扰状态下才显示通知
  if (!isDoNotDisturb) {
    _notificationService.showMessageNotification(...);
    DesktopNotification.updateUnreadStatus(...);
  }
}
```

## 使用流程

### 设置免打扰
1. 进入设置页面
2. 点击"免打扰设置"
3. 点击右上角"+"添加免打扰
4. 选择免打扰类型（全局/私聊/群聊）
5. 输入目标ID（如果需要）
6. 选择时长（快速选项或自定义时间）
7. 保存设置

### 管理免打扰
1. 在免打扰设置页面查看所有设置
2. 点击设置项的菜单按钮
3. 选择"编辑"或"删除"
4. 修改设置或确认删除

### 免打扰效果
- **消息仍然接收**：免打扰不影响消息接收和存储
- **通知被屏蔽**：不显示应用内通知和桌面通知
- **未读数正常**：未读消息数仍然正常计算和显示
- **状态可见**：在设置页面可以看到当前生效的免打扰

## 技术优势

### 1. 服务器端智能判断
- 免打扰检查在服务器端进行，减少客户端计算
- 支持复杂的时间判断逻辑
- 全局免打扰优先级管理

### 2. 客户端高效处理
- 服务器直接在消息中标识免打扰状态
- 客户端只需简单判断标识位
- 避免重复的免打扰状态查询

### 3. 用户体验优化
- 直观的设置界面
- 快速选项和自定义时间并存
- 实时状态显示和管理

### 4. 数据一致性
- 数据库唯一索引确保设置不重复
- 支持设置的增删改查
- 时间范围验证和处理

## 扩展性

### 未来可扩展功能
1. **按时间段免打扰**：如每天22:00-8:00免打扰
2. **按消息类型免打扰**：只屏蔽某些类型的消息
3. **VIP用户例外**：即使设置免打扰，某些重要联系人仍可通知
4. **免打扰统计**：显示被屏蔽的通知数量
5. **批量设置**：一次性设置多个用户或群组的免打扰

### 集成建议
1. **与用户关系集成**：在好友/群组详情页直接设置免打扰
2. **与消息列表集成**：在会话列表显示免打扰图标
3. **与通知设置集成**：与系统通知权限联动

这个免打扰功能提供了完整的消息通知控制能力，让用户可以根据需要灵活管理消息通知，提升使用体验。