package com.example.acme.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

/**
 * ACME HTTP-01 验证挑战控制器
 * 
 * 实现 RFC8555 标准的 HTTP-01 挑战验证
 * 路径: /.well-known/acme-challenge/{token}
 * 响应: token + "." + base64url(Thumbprint(accountKey))
 * 
 * 使用内存存储挑战响应，支持动态管理
 */
@RestController
@RequestMapping("/.well-known/acme-challenge")
public class AcmeChallengeController {

    private static final Logger logger = LoggerFactory.getLogger(AcmeChallengeController.class);

    // 内存存储挑战响应
    private final Map<String, String> challengeResponses = new ConcurrentHashMap<>();
    
    // 挑战响应过期时间（毫秒）- 默认5分钟
    private final Map<String, Long> challengeExpiry = new ConcurrentHashMap<>();
    
    @Value("${acme.challenge.expiry:300000}")
    private long challengeExpiryMs;

    /**
     * 处理 ACME HTTP-01 挑战请求
     * 
     * @param token 挑战令牌
     * @return 挑战响应内容
     */
    @GetMapping(value = "/{token}", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> handleAcmeChallenge(@PathVariable String token) {
        logger.info("收到ACME挑战请求，token: {}", token);
        
        try {
            // 检查token是否为空
            if (token == null || token.trim().isEmpty()) {
                logger.warn("收到空的token");
                return ResponseEntity.badRequest().body("Invalid token");
            }

            // 从内存中获取挑战响应
            String response = getChallengeFromMemory(token);
            
            if (response != null) {
                logger.info("找到挑战响应，token: {}", token);
                return ResponseEntity.ok(response);
            }

            logger.warn("未找到挑战响应，token: {}", token);
            return ResponseEntity.notFound().build();

        } catch (Exception e) {
            logger.error("处理ACME挑战时发生错误，token: {}", token, e);
            return ResponseEntity.internalServerError()
                    .body("Error processing ACME challenge: " + e.getMessage());
        }
    }

    /**
     * 从内存读取挑战响应
     */
    private String getChallengeFromMemory(String token) {
        // 检查是否过期
        Long expiryTime = challengeExpiry.get(token);
        if (expiryTime != null && System.currentTimeMillis() > expiryTime) {
            logger.info("挑战响应已过期，删除token: {}", token);
            challengeResponses.remove(token);
            challengeExpiry.remove(token);
            return null;
        }
        
        return challengeResponses.get(token);
    }

    /**
     * 添加挑战响应到内存
     * 
     * @param token 挑战令牌
     * @param response 挑战响应内容
     * @return 操作结果
     */
    @PostMapping("/{token}")
    public ResponseEntity<String> addChallengeResponse(
            @PathVariable String token,
            @RequestBody String response) {
        
        logger.info("添加挑战响应，token: {}", token);
        
        try {
            // 验证输入
            if (token == null || token.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Token cannot be empty");
            }
            
            if (response == null || response.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Response cannot be empty");
            }

            // 存储挑战响应
            challengeResponses.put(token, response.trim());
            
            // 设置过期时间
            long expiryTime = System.currentTimeMillis() + challengeExpiryMs;
            challengeExpiry.put(token, expiryTime);
            
            logger.info("挑战响应添加成功，token: {}, 过期时间: {}", token, expiryTime);
            return ResponseEntity.ok("Challenge response added for token: " + token);
            
        } catch (Exception e) {
            logger.error("添加挑战响应时发生错误，token: {}", token, e);
            return ResponseEntity.internalServerError()
                    .body("Error adding challenge response: " + e.getMessage());
        }
    }

    /**
     * 删除挑战响应
     * 
     * @param token 挑战令牌
     * @return 操作结果
     */
    @DeleteMapping("/{token}")
    public ResponseEntity<String> removeChallengeResponse(@PathVariable String token) {
        logger.info("删除挑战响应，token: {}", token);
        
        try {
            boolean removed = challengeResponses.remove(token) != null;
            challengeExpiry.remove(token);
            
            if (removed) {
                logger.info("挑战响应删除成功，token: {}", token);
                return ResponseEntity.ok("Challenge response removed for token: " + token);
            } else {
                logger.warn("挑战响应不存在，token: {}", token);
                return ResponseEntity.notFound().build();
            }
            
        } catch (Exception e) {
            logger.error("删除挑战响应时发生错误，token: {}", token, e);
            return ResponseEntity.internalServerError()
                    .body("Error removing challenge response: " + e.getMessage());
        }
    }

    /**
     * 批量添加挑战响应
     * 
     * @param challenges 挑战响应映射
     * @return 操作结果
     */
    @PostMapping("/batch")
    public ResponseEntity<String> addBatchChallengeResponses(@RequestBody Map<String, String> challenges) {
        logger.info("批量添加挑战响应，数量: {}", challenges.size());
        
        try {
            int addedCount = 0;
            long expiryTime = System.currentTimeMillis() + challengeExpiryMs;
            
            for (Map.Entry<String, String> entry : challenges.entrySet()) {
                String token = entry.getKey();
                String response = entry.getValue();
                
                if (token != null && !token.trim().isEmpty() && 
                    response != null && !response.trim().isEmpty()) {
                    
                    challengeResponses.put(token, response.trim());
                    challengeExpiry.put(token, expiryTime);
                    addedCount++;
                }
            }
            
            logger.info("批量添加完成，成功添加: {} 个挑战响应", addedCount);
            return ResponseEntity.ok("Added " + addedCount + " challenge responses");
            
        } catch (Exception e) {
            logger.error("批量添加挑战响应时发生错误", e);
            return ResponseEntity.internalServerError()
                    .body("Error adding batch challenge responses: " + e.getMessage());
        }
    }

    /**
     * 清空所有挑战响应
     * 
     * @return 操作结果
     */
    @DeleteMapping("/clear")
    public ResponseEntity<String> clearAllChallenges() {
        logger.info("清空所有挑战响应");
        
        try {
            int count = challengeResponses.size();
            challengeResponses.clear();
            challengeExpiry.clear();
            
            logger.info("清空完成，删除了 {} 个挑战响应", count);
            return ResponseEntity.ok("Cleared " + count + " challenge responses");
            
        } catch (Exception e) {
            logger.error("清空挑战响应时发生错误", e);
            return ResponseEntity.internalServerError()
                    .body("Error clearing challenge responses: " + e.getMessage());
        }
    }

    /**
     * 获取所有挑战响应（调试用）
     * 
     * @return 所有挑战响应
     */
    @GetMapping("/debug/all")
    public ResponseEntity<Map<String, Object>> getAllChallenges() {
        logger.info("获取所有挑战响应");
        
        try {
            Map<String, Object> result = new ConcurrentHashMap<>();
            result.put("challenges", challengeResponses);
            result.put("expiry", challengeExpiry);
            result.put("count", challengeResponses.size());
            result.put("currentTime", System.currentTimeMillis());
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            logger.error("获取挑战响应时发生错误", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * 获取挑战响应统计信息
     * 
     * @return 统计信息
     */
    @GetMapping("/debug/stats")
    public ResponseEntity<Map<String, Object>> getChallengeStats() {
        logger.info("获取挑战响应统计信息");
        
        try {
            long currentTime = System.currentTimeMillis();
            int expiredCount = 0;
            
            // 计算过期数量
            for (Long expiryTime : challengeExpiry.values()) {
                if (currentTime > expiryTime) {
                    expiredCount++;
                }
            }
            
            Map<String, Object> stats = new ConcurrentHashMap<>();
            stats.put("totalChallenges", challengeResponses.size());
            stats.put("expiredChallenges", expiredCount);
            stats.put("activeChallenges", challengeResponses.size() - expiredCount);
            stats.put("currentTime", currentTime);
            stats.put("expiryTimeMs", challengeExpiryMs);
            
            return ResponseEntity.ok(stats);
            
        } catch (Exception e) {
            logger.error("获取统计信息时发生错误", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * 健康检查端点
     * 
     * @return 健康状态
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new ConcurrentHashMap<>();
        health.put("status", "UP");
        health.put("service", "ACME Challenge Controller");
        health.put("timestamp", System.currentTimeMillis());
        health.put("activeChallenges", challengeResponses.size());
        
        return ResponseEntity.ok(health);
    }
} 