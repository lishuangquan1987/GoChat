package configs

import "github.com/spf13/viper"

var Cfg Config //全局变量，存储配置文件内容

type Config struct {
	DBType           string       // 数据库类型
	ConnectionString string       // 数据库连接字符串
	MinIO            MinIOConfig  // MinIO配置
	Server           ServerConfig // 服务器配置
}

type MinIOConfig struct {
	Endpoint   string // MinIO服务地址
	AccessKey  string // 访问密钥
	SecretKey  string // 密钥
	BucketName string // 存储桶名称
	UseSSL     bool   // 是否使用SSL
}

type ServerConfig struct {
	Port string // 服务器端口
}

func init() {
	viper.SetConfigName("Config")
	viper.AddConfigPath(".")
	err := viper.ReadInConfig()
	if err != nil {
		panic("Error reading config file, " + err.Error())
	}

	err = viper.Unmarshal(&Cfg)
	if err != nil {
		panic("Unable to decode into struct, " + err.Error())
	}
}
