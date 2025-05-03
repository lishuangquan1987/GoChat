package configs

import "github.com/spf13/viper"

var Cfg Config //全局变量，存储配置文件内容

type Config struct {
	DBType           string // 数据库类型
	ConnectionString string // 数据库连接字符串
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
