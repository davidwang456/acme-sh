package com.example.acme.controller;

import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * 测试控制器
 * 用于验证 Spring Boot 应用是否正常运行
 */
@RestController
@RequestMapping("/test")
public class TestController {

    /**
     * 基本测试端点
     */
    @GetMapping
    public Map<String, Object> test() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "ACME Challenge Server is running");
        response.put("timestamp", LocalDateTime.now());
        response.put("endpoints", new String[]{
            "GET /test - 基本测试",
            "GET /.well-known/acme-challenge/{token} - ACME 挑战验证",
            "GET /.well-known/acme-challenge/health - 健康检查",
            "POST /.well-known/acme-challenge/{token} - 添加挑战响应",
            "DELETE /.well-known/acme-challenge/{token} - 删除挑战响应"
        });
        return response;
    }

    /**
     * 模拟 ACME 挑战响应
     */
    @GetMapping("/acme/{token}")
    public String mockAcmeChallenge(@PathVariable String token) {
        return token + ".mock-response-" + System.currentTimeMillis();
    }

    /**
     * 检查端口是否可访问
     */
    @GetMapping("/port-check")
    public Map<String, Object> portCheck() {
        Map<String, Object> response = new HashMap<>();
        response.put("port", 80);
        response.put("accessible", true);
        response.put("timestamp", LocalDateTime.now());
        return response;
    }
} 