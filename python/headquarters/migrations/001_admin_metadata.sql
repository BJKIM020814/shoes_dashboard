-- 기존 업무 테이블은 변경하지 않는다. 자동 실행되지 않는다.
-- MySQL 8.x / InnoDB / utf8mb4. 실행 계정과 런타임 계정을 분리하는 것을 권장한다.
CREATE TABLE IF NOT EXISTS hq_member_metadata (
    customer_id VARCHAR(254) COLLATE utf8mb4_bin PRIMARY KEY,
    grade ENUM('general','vip') NOT NULL DEFAULT 'general',
    updated_by VARCHAR(128) NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS hq_review_moderation (
    resource_key CHAR(64) COLLATE ascii_bin PRIMARY KEY,
    customer_id VARCHAR(254) COLLATE utf8mb4_bin NOT NULL,
    product_code VARCHAR(128) COLLATE utf8mb4_bin NOT NULL,
    review_seq INT NOT NULL,
    status ENUM('public','reported','hidden') NOT NULL DEFAULT 'public',
    reason VARCHAR(1000),
    updated_by VARCHAR(128) NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_review (customer_id, product_code, review_seq),
    KEY ix_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS hq_audit_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_id VARCHAR(128) NOT NULL,
    action VARCHAR(64) NOT NULL,
    entity_id TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY ix_actor_time (employee_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
