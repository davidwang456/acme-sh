package com.example.acme;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * ACME 挑战验证服务器
 * 
 * 提供 HTTP-01 挑战验证服务，支持 acme.sh 的域名验证
 */
@SpringBootApplication
public class AcmeChallengeApplication {

    public static void main(String[] args) {
        SpringApplication.run(AcmeChallengeApplication.class, args);
    }

    /**
     * 应用启动后的初始化操作
     */
    @Component
    public static class ApplicationInitializer {
        
        @Value("${acme.challenge.webroot:/tmp/webroot}")
        private String webrootPath;

        @EventListener(ApplicationReadyEvent.class)
        public void initializeApplication() {
            try {
                // 创建必要的目录结构
                createDirectories();
                
                System.out.println("✅ ACME Challenge Server 启动成功");
                System.out.println("📁 Webroot 路径: " + webrootPath);
                System.out.println("🌐 服务地址: http://localhost:80/.well-known/acme-challenge/");
                System.out.println("🔍 健康检查: http://localhost:80/.well-known/acme-challenge/health");
                
            } catch (Exception e) {
                System.err.println("❌ 应用初始化失败: " + e.getMessage());
            }
        }

        private void createDirectories() throws Exception {
            Path webroot = Paths.get(webrootPath);
            Path acmeChallenge = webroot.resolve(".well-known").resolve("acme-challenge");
            
            // 创建目录结构
            Files.createDirectories(acmeChallenge);
            
            System.out.println("📂 创建目录: " + acmeChallenge.toAbsolutePath());
        }
    }
} 