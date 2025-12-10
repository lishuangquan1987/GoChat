//go:build ignore
// +build ignore

package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// 获取当前工作目录
	wd, err := os.Getwd()
	if err != nil {
		log.Fatalf("获取工作目录失败: %v", err)
	}

	// 检查 ent/schema 目录是否存在
	schemaDir := filepath.Join(wd, "ent", "schema")
	if _, err := os.Stat(schemaDir); os.IsNotExist(err) {
		log.Fatalf("ent/schema 目录不存在: %v", err)
	}

	fmt.Println("正在生成 Ent 实体...")
	fmt.Printf("Schema 目录: %s\n", schemaDir)

	// 执行 ent generate 命令
	cmd := exec.Command("go", "run", "-mod=mod", "entgo.io/ent/cmd/ent", "generate", "./ent/schema")
	cmd.Dir = wd
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		log.Fatalf("生成 Ent 实体失败: %v", err)
	}

	fmt.Println("\n✅ Ent 实体生成成功！")
}
