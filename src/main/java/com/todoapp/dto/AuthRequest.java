package com.todoapp.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class AuthRequest {
    @NotBlank(message = "Username is required")
    private String username;

    // Max 72 matches BCrypt's input limit and mirrors the constraint on
    // RegisterRequest.password. Added in SB-GL-50 as the compensating
    // control for CVE-2025-22228; since Spring Security 7 carries the fix
    // it is plain input validation (SB-GL-62).
    @NotBlank(message = "Password is required")
    @Size(max = 72, message = "Password cannot exceed 72 characters")
    private String password;

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
}
