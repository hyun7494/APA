package com.apa.auth.controller;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SecureController {

    @GetMapping("/secure/hello")
    public String hello(Authentication auth) {
        return "hyun Test, Hello! :" + auth.getName();
    }
}