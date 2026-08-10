package com.apa.fishing;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling   // 지수·운세 배치용. 빼먹으면 @Scheduled가 조용히 안 돈다
@SpringBootApplication
public class FishingApplication {

    public static void main(String[] args) {
        SpringApplication.run(FishingApplication.class, args);
    }
}
