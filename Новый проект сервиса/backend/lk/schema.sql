-- Таблицы личного кабинета (своя часть, не CS-Cart). Создаются один раз в базе сайта.

CREATE TABLE IF NOT EXISTS irepair_lk_clients (
  phone         VARCHAR(15)  NOT NULL PRIMARY KEY,   -- 79031234567
  ro_client_id  BIGINT       NOT NULL DEFAULT 0,     -- клиент в RemOnline
  first_name    VARCHAR(100) NOT NULL DEFAULT '',
  last_name     VARCHAR(100) NOT NULL DEFAULT '',
  email         VARCHAR(190) NOT NULL DEFAULT '',
  gender        VARCHAR(1)   NOT NULL DEFAULT '',    -- M / F
  birthday      DATE         NULL,
  created_at    INT UNSIGNED NOT NULL DEFAULT 0,
  last_login_at INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Действующий код из СМС (хранится только подпись кода)
CREATE TABLE IF NOT EXISTS irepair_lk_otp (
  phone      VARCHAR(15)      NOT NULL PRIMARY KEY,
  code_hash  CHAR(64)         NOT NULL,
  attempts   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  expires_at INT UNSIGNED     NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Журнал запросов кода: ограничение частоты СМС
CREATE TABLE IF NOT EXISTS irepair_lk_sms_log (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  phone      VARCHAR(15)  NOT NULL,
  ip         VARCHAR(45)  NOT NULL DEFAULT '',
  sent       TINYINT(1)   NOT NULL DEFAULT 0,
  created_at INT UNSIGNED NOT NULL,
  KEY phone_time (phone, created_at),
  KEY ip_time (ip, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS irepair_lk_sessions (
  token_hash  CHAR(64)     NOT NULL PRIMARY KEY,
  phone       VARCHAR(15)  NOT NULL,
  ip          VARCHAR(45)  NOT NULL DEFAULT '',
  orders_json TEXT         NULL,                     -- заказы клиента: к чужим доступа нет
  created_at  INT UNSIGNED NOT NULL,
  expires_at  INT UNSIGNED NOT NULL,
  KEY phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Списания баллов по заказам (на старом сайте — таблица remonline_history; при переезде перенести)
CREATE TABLE IF NOT EXISTS irepair_lk_bonus_history (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  order_id   BIGINT       NOT NULL,
  item_id    BIGINT       NOT NULL,
  amount     INT          NOT NULL,
  phone      VARCHAR(15)  NOT NULL DEFAULT '',
  created_at INT UNSIGNED NOT NULL,
  KEY order_id (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Замок: по одному заказу баллы списываются один раз
CREATE TABLE IF NOT EXISTS irepair_lk_spend_lock (
  order_id   BIGINT       NOT NULL PRIMARY KEY,
  phone      VARCHAR(15)  NOT NULL,
  created_at INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
