-- =====================================================
-- Схема базы данных для словаря русского жестового языка
-- PostgreSQL 17+ (совместимо с 14+)
-- =====================================================

-- Установка кодировки UTF-8 (если не установлена глобально)
-- SET client_encoding = 'UTF8';

-- =====================================================
-- Step 1: Таблица categories
-- =====================================================
CREATE TABLE IF NOT EXISTS categories (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    "order" INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_categories_order ON categories("order");

-- =====================================================
-- Step 2: Таблица signs
-- =====================================================
CREATE TABLE IF NOT EXISTS signs (
    id VARCHAR(50) PRIMARY KEY,
    word VARCHAR(200) NOT NULL,
    description TEXT,
    category_id VARCHAR(50) NOT NULL,
    embeddings JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_signs_category_id ON signs(category_id);
CREATE INDEX IF NOT EXISTS idx_signs_word ON signs(word);

-- =====================================================
-- Step 3: Таблица sign_videos
-- =====================================================
CREATE TABLE IF NOT EXISTS sign_videos (
    id SERIAL PRIMARY KEY,
    sign_id VARCHAR(50) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    url VARCHAR(500) NOT NULL,
    context_description TEXT NOT NULL,
    "order" INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sign_id) REFERENCES signs(id) ON DELETE CASCADE,
    UNIQUE (sign_id, "order")
);

CREATE INDEX IF NOT EXISTS idx_sign_videos_sign_id ON sign_videos(sign_id);
CREATE INDEX IF NOT EXISTS idx_sign_videos_order ON sign_videos("order");

-- =====================================================
-- Step 4: Таблица sign_synonyms
-- =====================================================
CREATE TABLE IF NOT EXISTS sign_synonyms (
    id SERIAL PRIMARY KEY,
    sign_id_1 VARCHAR(50) NOT NULL,
    sign_id_2 VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sign_id_1) REFERENCES signs(id) ON DELETE CASCADE,
    FOREIGN KEY (sign_id_2) REFERENCES signs(id) ON DELETE CASCADE,
    UNIQUE (sign_id_1, sign_id_2),
    CHECK (sign_id_1 != sign_id_2)
);

CREATE INDEX IF NOT EXISTS idx_synonyms_sign_1 ON sign_synonyms(sign_id_1);
CREATE INDEX IF NOT EXISTS idx_synonyms_sign_2 ON sign_synonyms(sign_id_2);

-- =====================================================
-- Step 5: Таблица sync_metadata
-- =====================================================
CREATE TABLE IF NOT EXISTS sync_metadata (
    id SERIAL PRIMARY KEY,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1
);

-- Вставка начальной записи (если таблица пустая)
INSERT INTO sync_metadata (last_updated, version)
SELECT CURRENT_TIMESTAMP, 1
WHERE NOT EXISTS (SELECT 1 FROM sync_metadata);

-- =====================================================
-- Step 6: Таблица admin_users
-- =====================================================
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_username ON admin_users(username);

-- =====================================================
-- Step 7: Функция и триггеры для автоматического обновления updated_at
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для таблицы signs
DROP TRIGGER IF EXISTS update_signs_updated_at ON signs;
CREATE TRIGGER update_signs_updated_at 
    BEFORE UPDATE ON signs
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Триггеры для таблицы categories
DROP TRIGGER IF EXISTS update_categories_updated_at ON categories;
CREATE TRIGGER update_categories_updated_at 
    BEFORE UPDATE ON categories
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Триггеры для таблицы sign_videos
DROP TRIGGER IF EXISTS update_sign_videos_updated_at ON sign_videos;
CREATE TRIGGER update_sign_videos_updated_at 
    BEFORE UPDATE ON sign_videos
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Проверка создания таблиц
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'Схема базы данных успешно создана!';
    RAISE NOTICE 'Создано таблиц: categories, signs, sign_videos, sign_synonyms, sync_metadata, admin_users';
END $$;

