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
 * ACME Challenge Validation Server
 * 
 * Provides HTTP-01 challenge validation service for acme.sh domain validation
 */
@SpringBootApplication
public class AcmeChallengeApplication {

    public static void main(String[] args) {
        SpringApplication.run(AcmeChallengeApplication.class, args);
    }

    /**
     * Application initialization after startup
     */
    @Component
    public static class ApplicationInitializer {
        
        @Value("${acme.challenge.webroot:/tmp/webroot}")
        private String webrootPath;

        @EventListener(ApplicationReadyEvent.class)
        public void initializeApplication() {
            try {
                // Create necessary directory structure
                createDirectories();
                
                System.out.println("✅ ACME Challenge Server started successfully");
                System.out.println("📁 Webroot path: " + webrootPath);
                System.out.println("🌐 Service URL: http://localhost:80/.well-known/acme-challenge/");
                System.out.println("🔍 Health check: http://localhost:80/.well-known/acme-challenge/health");
                
            } catch (Exception e) {
                System.err.println("❌ Application initialization failed: " + e.getMessage());
            }
        }

        private void createDirectories() throws Exception {
            Path webroot = Paths.get(webrootPath);
            Path acmeChallenge = webroot.resolve(".well-known").resolve("acme-challenge");
            
            // Create directory structure
            Files.createDirectories(acmeChallenge);
            
            System.out.println("📂 Created directory: " + acmeChallenge.toAbsolutePath());
        }
    }
} 