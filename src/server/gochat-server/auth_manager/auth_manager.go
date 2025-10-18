package authmanager

import (
	"errors"
	"fmt"
	"log"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
	_ "github.com/mattn/go-sqlite3"
	"github.com/nalgeon/redka"
	"golang.org/x/crypto/bcrypt"
)

const (
	AuthDB         = "auth.db"
	JWTSecret      = "gochat-secret-key-change-in-production" // 生产环境应该从配置文件读取
	TokenExpireDays = 7
)

// JWT Claims 结构
type Claims struct {
	UserID   int    `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// HashPassword 使用 bcrypt 加密密码
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// CheckPassword 验证密码
func CheckPassword(hashedPassword, password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
	return err == nil
}

// GenerateToken 生成 JWT token
func GenerateToken(userID int, username string) (string, error) {
	expirationTime := time.Now().Add(TokenExpireDays * 24 * time.Hour)
	
	claims := &Claims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(JWTSecret))
	if err != nil {
		return "", err
	}

	// 将 token 存储到 Redka 中，用于验证和管理
	if !AddToken(strconv.Itoa(userID), tokenString) {
		return "", errors.New("failed to store token")
	}

	return tokenString, nil
}

// ParseToken 解析 JWT token
func ParseToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(JWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// ValidateToken 验证 token 是否有效
func ValidateToken(userId, token string) bool {
	// 首先解析 token
	claims, err := ParseToken(token)
	if err != nil {
		log.Printf("Failed to parse token: %v", err)
		return false
	}

	// 验证 userID 是否匹配
	if strconv.Itoa(claims.UserID) != userId {
		log.Printf("UserID mismatch: expected %s, got %d", userId, claims.UserID)
		return false
	}

	// 检查 token 是否在 Redka 中存在（用于登出功能）
	db, err := redka.Open(AuthDB, nil)
	if err != nil {
		log.Printf("Failed to open auth db: %v", err)
		return false
	}
	defer db.Close()

	tokenInDb, err := db.Str().Get(userId)
	if err != nil {
		if errors.Is(err, redka.ErrNotFound) {
			log.Printf("Token not found in db for user: %s", userId)
			return false
		}
		log.Printf("Failed to get token from db: %v", err)
		return false
	}

	if tokenInDb.String() != token {
		log.Printf("Token mismatch for user: %s", userId)
		return false
	}

	return true
}

// AddToken 添加 token 到 Redka
func AddToken(userId, token string) bool {
	db, err := redka.Open(AuthDB, nil)
	if err != nil {
		log.Printf("Failed to open auth db: %v", err)
		return false
	}
	defer db.Close()

	// 设置 token，过期时间为 7 天
	err = db.Str().SetExpires(userId, token, TokenExpireDays*24*time.Hour)
	if err != nil {
		log.Printf("Failed to set token: %v", err)
		return false
	}
	return true
}

// DeleteToken 删除 token（用于登出）
func DeleteToken(userId string) bool {
	db, err := redka.Open(AuthDB, nil)
	if err != nil {
		log.Printf("Failed to open auth db: %v", err)
		return false
	}
	defer db.Close()

	deleted, err := db.Key().Delete(userId)
	if err != nil {
		log.Printf("Failed to delete token: %v", err)
		return false
	}

	if deleted == 0 {
		log.Printf("Token not found for user: %s", userId)
	}

	return true
}
