package com.example.acme.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

/**
 * ACME HTTP-01 Challenge Controller
 * 
 * Implements RFC8555 standard HTTP-01 challenge validation
 * Path: /.well-known/acme-challenge/{token}
 * Response: token + "." + base64url(Thumbprint(accountKey))
 * 
 * Uses in-memory storage for challenge responses with dynamic management
 */
@RestController
@RequestMapping("/.well-known/acme-challenge")
public class AcmeChallengeController {

    // In-memory storage for challenge responses
    private final Map<String, String> challengeResponses = new ConcurrentHashMap<>();
    
    // Challenge response expiry times (milliseconds) - default 5 minutes
    private final Map<String, Long> challengeExpiry = new ConcurrentHashMap<>();
    
    @Value("${acme.challenge.expiry:300000}")
    private long challengeExpiryMs;

    /**
     * Handle ACME HTTP-01 challenge request
     * 
     * @param token Challenge token
     * @return Challenge response content
     */
    @GetMapping(value = "/{token}", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> handleAcmeChallenge(@PathVariable String token) {
        System.out.println("Received ACME challenge request, token: " + token);
        
        try {
            // Check if token is empty
            if (token == null || token.trim().isEmpty()) {
                System.out.println("Received empty token");
                return ResponseEntity.badRequest().body("Invalid token");
            }

            // Get challenge response from memory
            String response = getChallengeFromMemory(token);
            
            if (response != null) {
                System.out.println("Found challenge response, token: " + token);
                return ResponseEntity.ok(response);
            }

            System.out.println("Challenge response not found, token: " + token);
            return ResponseEntity.notFound().build();

        } catch (Exception e) {
            System.out.println("Error processing ACME challenge, token: " + token + ", error: " + e.getMessage());
            return ResponseEntity.internalServerError()
                    .body("Error processing ACME challenge: " + e.getMessage());
        }
    }

    /**
     * Get challenge response from memory
     */
    private String getChallengeFromMemory(String token) {
        // Check if expired
        Long expiryTime = challengeExpiry.get(token);
        if (expiryTime != null && System.currentTimeMillis() > expiryTime) {
            System.out.println("Challenge response expired, removing token: " + token);
            challengeResponses.remove(token);
            challengeExpiry.remove(token);
            return null;
        }
        
        return challengeResponses.get(token);
    }

    /**
     * Add challenge response to memory
     * 
     * @param token Challenge token
     * @param response Challenge response content
     * @return Operation result
     */
    @PostMapping("/{token}")
    public ResponseEntity<String> addChallengeResponse(
            @PathVariable String token,
            @RequestBody String response) {
        
        System.out.println("Adding challenge response, token: " + token);
        
        try {
            // Validate input
            if (token == null || token.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Token cannot be empty");
            }
            
            if (response == null || response.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Response cannot be empty");
            }

            // Store challenge response
            challengeResponses.put(token, response.trim());
            
            // Set expiry time
            long expiryTime = System.currentTimeMillis() + challengeExpiryMs;
            challengeExpiry.put(token, expiryTime);
            
            System.out.println("Challenge response added successfully, token: " + token + ", expiry: " + expiryTime);
            return ResponseEntity.ok("Challenge response added for token: " + token);
            
        } catch (Exception e) {
            System.out.println("Error adding challenge response, token: " + token + ", error: " + e.getMessage());
            return ResponseEntity.internalServerError()
                    .body("Error adding challenge response: " + e.getMessage());
        }
    }

    /**
     * Remove challenge response
     * 
     * @param token Challenge token
     * @return Operation result
     */
    @DeleteMapping("/{token}")
    public ResponseEntity<String> removeChallengeResponse(@PathVariable String token) {
        System.out.println("Removing challenge response, token: " + token);
        
        try {
            boolean removed = challengeResponses.remove(token) != null;
            challengeExpiry.remove(token);
            
            if (removed) {
                System.out.println("Challenge response removed successfully, token: " + token);
                return ResponseEntity.ok("Challenge response removed for token: " + token);
            } else {
                System.out.println("Challenge response not found, token: " + token);
                return ResponseEntity.notFound().build();
            }
            
        } catch (Exception e) {
            System.out.println("Error removing challenge response, token: " + token + ", error: " + e.getMessage());
            return ResponseEntity.internalServerError()
                    .body("Error removing challenge response: " + e.getMessage());
        }
    }

    /**
     * Add batch challenge responses
     * 
     * @param challenges Challenge response mapping
     * @return Operation result
     */
    @PostMapping("/batch")
    public ResponseEntity<String> addBatchChallengeResponses(@RequestBody Map<String, String> challenges) {
        System.out.println("Adding batch challenge responses, count: " + challenges.size());
        
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
            
            System.out.println("Batch addition completed, successfully added: " + addedCount + " challenge responses");
            return ResponseEntity.ok("Added " + addedCount + " challenge responses");
            
        } catch (Exception e) {
            System.out.println("Error adding batch challenge responses, error: " + e.getMessage());
            return ResponseEntity.internalServerError()
                    .body("Error adding batch challenge responses: " + e.getMessage());
        }
    }

    /**
     * Clear all challenge responses
     * 
     * @return Operation result
     */
    @DeleteMapping("/clear")
    public ResponseEntity<String> clearAllChallenges() {
        System.out.println("Clearing all challenge responses");
        
        try {
            int count = challengeResponses.size();
            challengeResponses.clear();
            challengeExpiry.clear();
            
            System.out.println("Clear completed, removed " + count + " challenge responses");
            return ResponseEntity.ok("Cleared " + count + " challenge responses");
            
        } catch (Exception e) {
            System.out.println("Error clearing challenge responses, error: " + e.getMessage());
            return ResponseEntity.internalServerError()
                    .body("Error clearing challenge responses: " + e.getMessage());
        }
    }

    /**
     * Get all challenge responses (for debugging)
     * 
     * @return All challenge responses
     */
    @GetMapping("/debug/all")
    public ResponseEntity<Map<String, Object>> getAllChallenges() {
        System.out.println("Getting all challenge responses");
        
        try {
            Map<String, Object> result = new ConcurrentHashMap<>();
            result.put("challenges", challengeResponses);
            result.put("expiry", challengeExpiry);
            result.put("count", challengeResponses.size());
            result.put("currentTime", System.currentTimeMillis());
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            System.out.println("Error getting challenge responses, error: " + e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Get challenge response statistics
     * 
     * @return Statistics information
     */
    @GetMapping("/debug/stats")
    public ResponseEntity<Map<String, Object>> getChallengeStats() {
        System.out.println("Getting challenge response statistics");
        
        try {
            long currentTime = System.currentTimeMillis();
            int expiredCount = 0;
            
            // Calculate expired count
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
            System.out.println("Error getting statistics, error: " + e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Health check endpoint
     * 
     * @return Health status
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