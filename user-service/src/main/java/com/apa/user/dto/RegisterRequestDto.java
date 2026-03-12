package com.apa.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class RegisterRequestDto {

    @NotBlank(message = "username은 필수입니다.")
    @Size(min = 3, max = 50, message = "username은 3~50자 사이여야 합니다.")
    private String username;

    @NotBlank(message = "password는 필수입니다.")
    @Size(min = 8, message = "password는 최소 8자 이상이어야 합니다.")
    private String password;

    @NotBlank(message = "email은 필수입니다.")
    @Email(message = "올바른 이메일 형식이 아닙니다.")
    private String email;
}
