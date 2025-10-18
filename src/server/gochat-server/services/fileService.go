package services

import (
	"context"
	"errors"
	"fmt"
	"gochat_server/configs"
	"io"
	"mime/multipart"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var minioClient *minio.Client

// 文件大小限制
const (
	MaxImageSize = 10 * 1024 * 1024  // 10MB
	MaxVideoSize = 100 * 1024 * 1024 // 100MB
)

// 支持的文件类型
var (
	ImageExtensions = []string{".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"}
	VideoExtensions = []string{".mp4", ".avi", ".mov", ".wmv", ".flv", ".mkv"}
)

// InitMinIO 初始化 MinIO 客户端
func InitMinIO() error {
	cfg := configs.Cfg.MinIO
	
	var err error
	minioClient, err = minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return fmt.Errorf("初始化MinIO客户端失败: %v", err)
	}

	// 检查bucket是否存在，不存在则创建
	ctx := context.Background()
	exists, err := minioClient.BucketExists(ctx, cfg.BucketName)
	if err != nil {
		return fmt.Errorf("检查bucket失败: %v", err)
	}

	if !exists {
		err = minioClient.MakeBucket(ctx, cfg.BucketName, minio.MakeBucketOptions{})
		if err != nil {
			return fmt.Errorf("创建bucket失败: %v", err)
		}

		// 设置bucket为公开读取
		policy := fmt.Sprintf(`{
			"Version": "2012-10-17",
			"Statement": [{
				"Effect": "Allow",
				"Principal": {"AWS": ["*"]},
				"Action": ["s3:GetObject"],
				"Resource": ["arn:aws:s3:::%s/*"]
			}]
		}`, cfg.BucketName)

		err = minioClient.SetBucketPolicy(ctx, cfg.BucketName, policy)
		if err != nil {
			return fmt.Errorf("设置bucket策略失败: %v", err)
		}
	}

	return nil
}

// UploadFile 上传文件
func UploadFile(file multipart.File, fileHeader *multipart.FileHeader, fileType string) (string, error) {
	if minioClient == nil {
		return "", errors.New("MinIO客户端未初始化")
	}

	// 获取文件扩展名
	ext := strings.ToLower(filepath.Ext(fileHeader.Filename))

	// 验证文件类型
	if fileType == "image" {
		if !contains(ImageExtensions, ext) {
			return "", errors.New("不支持的图片格式")
		}
		if fileHeader.Size > MaxImageSize {
			return "", fmt.Errorf("图片大小超过限制（最大%dMB）", MaxImageSize/(1024*1024))
		}
	} else if fileType == "video" {
		if !contains(VideoExtensions, ext) {
			return "", errors.New("不支持的视频格式")
		}
		if fileHeader.Size > MaxVideoSize {
			return "", fmt.Errorf("视频大小超过限制（最大%dMB）", MaxVideoSize/(1024*1024))
		}
	} else {
		return "", errors.New("不支持的文件类型")
	}

	// 生成唯一文件名
	fileName := fmt.Sprintf("%s/%s%s", fileType, uuid.New().String(), ext)

	// 获取文件内容类型
	contentType := fileHeader.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	// 上传文件
	cfg := configs.Cfg.MinIO
	ctx := context.Background()
	_, err := minioClient.PutObject(ctx, cfg.BucketName, fileName, file, fileHeader.Size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("上传文件失败: %v", err)
	}

	// 生成文件URL
	protocol := "http"
	if cfg.UseSSL {
		protocol = "https"
	}
	url := fmt.Sprintf("%s://%s/%s/%s", protocol, cfg.Endpoint, cfg.BucketName, fileName)

	return url, nil
}

// GetFileURL 获取文件URL（预签名URL，用于私有文件）
func GetFileURL(fileName string, expiry time.Duration) (string, error) {
	if minioClient == nil {
		return "", errors.New("MinIO客户端未初始化")
	}

	cfg := configs.Cfg.MinIO
	ctx := context.Background()
	presignedURL, err := minioClient.PresignedGetObject(ctx, cfg.BucketName, fileName, expiry, nil)
	if err != nil {
		return "", fmt.Errorf("生成预签名URL失败: %v", err)
	}

	return presignedURL.String(), nil
}

// DeleteFile 删除文件
func DeleteFile(fileName string) error {
	if minioClient == nil {
		return errors.New("MinIO客户端未初始化")
	}

	cfg := configs.Cfg.MinIO
	ctx := context.Background()
	err := minioClient.RemoveObject(ctx, cfg.BucketName, fileName, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("删除文件失败: %v", err)
	}

	return nil
}

// DownloadFile 下载文件
func DownloadFile(fileName string) (io.ReadCloser, error) {
	if minioClient == nil {
		return nil, errors.New("MinIO客户端未初始化")
	}

	cfg := configs.Cfg.MinIO
	ctx := context.Background()
	object, err := minioClient.GetObject(ctx, cfg.BucketName, fileName, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("下载文件失败: %v", err)
	}

	return object, nil
}

// contains 检查切片是否包含指定元素
func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

// GetMinIOClient 获取MinIO客户端（用于测试或其他用途）
func GetMinIOClient() *minio.Client {
	return minioClient
}
