#!/usr/bin/env bash
# ============================================================================
# Database Library
# Functions for setting up and configuring the mail database
# ============================================================================

# Dependencies: None (uses global variables from main script)

setup_database() {
    print_section "Configuring Database"
    
    log_step "Starting MariaDB..."
    systemctl start mariadb || systemctl start mysql || true
    systemctl enable mariadb || systemctl enable mysql || true
    
    log_step "Creating mail database and user..."
    
    mysql -u root <<EOF
-- Create database
CREATE DATABASE IF NOT EXISTS mail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user
CREATE USER IF NOT EXISTS 'mailuser'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT SELECT ON mail.* TO 'mailuser'@'localhost';
FLUSH PRIVILEGES;

-- Use database
USE mail;

-- ============================================================================
-- DOMAINS TABLE
-- Stores all virtual mail domains that this server handles
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain VARCHAR(255) NOT NULL UNIQUE COMMENT 'Domain name (e.g., example.com)',
    description TEXT COMMENT 'Optional description of the domain',
    enabled TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = disabled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_domain (domain),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Virtual mail domains';

-- ============================================================================
-- USERS TABLE
-- Stores all email user accounts with encrypted passwords
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE COMMENT 'Full email address (user@domain.com)',
    domain_id INT NOT NULL COMMENT 'Reference to mail_domains table',
    password VARCHAR(255) NOT NULL COMMENT 'Encrypted password (use SHA512-CRYPT or BCRYPT)',
    name VARCHAR(255) DEFAULT NULL COMMENT 'Full name of the user',
    enabled TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = disabled',
    quota_bytes BIGINT DEFAULT 5368709120 COMMENT 'Storage quota in bytes (default 5GB)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES mail_domains(id) ON DELETE CASCADE,
    INDEX idx_email (email),
    INDEX idx_domain_id (domain_id),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Email user accounts';

-- ============================================================================
-- ALIASES TABLE
-- Email aliases that forward to other addresses
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_aliases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    source_email VARCHAR(255) NOT NULL COMMENT 'Source alias address (info@example.com)',
    destination_email VARCHAR(255) NOT NULL COMMENT 'Destination email (user@example.com)',
    domain_id INT NOT NULL COMMENT 'Reference to mail_domains table',
    enabled TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = disabled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES mail_domains(id) ON DELETE CASCADE,
    INDEX idx_source (source_email),
    INDEX idx_destination (destination_email),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Email aliases and forwards';

-- ============================================================================
-- AUDIT LOG TABLE
-- Tracks important events for security and compliance
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_audit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT DEFAULT NULL COMMENT 'Reference to mail_users table',
    action VARCHAR(50) NOT NULL COMMENT 'Action performed (login, password_change, etc)',
    details TEXT COMMENT 'Additional details about the action',
    ip_address VARCHAR(45) COMMENT 'IP address of the client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES mail_users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Audit log for security and compliance';

-- Insert configured domains
EOF

    # Insert domains
    for domain in "${MAIL_DOMAINS[@]}"; do
        mysql -u root mail <<EOF
INSERT IGNORE INTO mail_domains (domain, description) 
VALUES ('$domain', 'Configured by installation script');
EOF
        log_success "Added domain to database: $domain"
    done
    
    log_success "Database configured successfully"
}
