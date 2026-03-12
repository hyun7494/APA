package com.apa.user.service;

import com.apa.user.dto.RegisterRequestDto;
import com.apa.user.dto.UserResponseDto;
import com.apa.user.entity.User;
import com.apa.user.exception.UserException;
import com.apa.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public UserResponseDto register(RegisterRequestDto request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new UserException(UserException.ErrorCode.USERNAME_ALREADY_EXISTS);
        }
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new UserException(UserException.ErrorCode.EMAIL_ALREADY_EXISTS);
        }

        User user = User.builder()
                .username(request.getUsername())
                .password(passwordEncoder.encode(request.getPassword()))
                .email(request.getEmail())
                .role(User.Role.USER)
                .build();

        return new UserResponseDto(userRepository.save(user));
    }

    @Transactional(readOnly = true)
    public UserResponseDto getUser(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new UserException(UserException.ErrorCode.USER_NOT_FOUND));
        return new UserResponseDto(user);
    }

    @Transactional(readOnly = true)
    public UserResponseDto getUserByUsername(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UserException(UserException.ErrorCode.USER_NOT_FOUND));
        return new UserResponseDto(user);
    }
}
