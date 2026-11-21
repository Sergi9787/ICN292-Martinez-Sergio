CREATE DATABASE IF NOT EXISTS bobs_coffee_final
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE bobs_coffee_final;

CREATE TABLE IF NOT EXISTS insumo (
    id_insumo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(80) NOT NULL,
    unidad_base VARCHAR(30) NOT NULL,
    stock_minimo DECIMAL(18,6) NOT NULL,
    CONSTRAINT ck_insumo_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_insumo_stock_minimo CHECK (stock_minimo >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS proveedor (
    id_proveedor INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    CONSTRAINT ck_proveedor_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS usuario (
    id_usuario INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    rol VARCHAR(30) NOT NULL,
    CONSTRAINT ck_usuario_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_usuario_rol CHECK (rol IN ('ADMINISTRADOR', 'COMPRAS', 'COCINA'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS insumo_proveedor (
    id_insumo INT NOT NULL,
    id_proveedor INT NOT NULL,
    plazo_entrega_dias INT NOT NULL,
    PRIMARY KEY (id_insumo, id_proveedor),
    CONSTRAINT fk_ip_insumo FOREIGN KEY (id_insumo) REFERENCES insumo (id_insumo),
    CONSTRAINT fk_ip_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedor (id_proveedor),
    CONSTRAINT ck_ip_plazo CHECK (plazo_entrega_dias >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orden_compra (
    id_orden INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT NOT NULL,
    fecha_emision DATE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'EMITIDA',
    es_urgente TINYINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_oc_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedor (id_proveedor),
    CONSTRAINT ck_oc_estado CHECK (estado IN ('EMITIDA', 'PARCIAL', 'RECIBIDA', 'CANCELADA')),
    CONSTRAINT ck_oc_urgente CHECK (es_urgente IN (0, 1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_orden (
    id_detalle INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_orden INT NOT NULL,
    id_insumo INT NOT NULL,
    cantidad_solicitada_base DECIMAL(18,6) NOT NULL,
    precio_unitario_base DECIMAL(18,6) NOT NULL,
    CONSTRAINT fk_do_orden FOREIGN KEY (id_orden) REFERENCES orden_compra (id_orden),
    CONSTRAINT fk_do_insumo FOREIGN KEY (id_insumo) REFERENCES insumo (id_insumo),
    CONSTRAINT ck_do_cantidad CHECK (cantidad_solicitada_base > 0),
    CONSTRAINT ck_do_precio CHECK (precio_unitario_base >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recepcion (
    id_recepcion INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_orden INT NOT NULL,
    fecha_hora_recepcion DATETIME NOT NULL,
    CONSTRAINT fk_recepcion_orden FOREIGN KEY (id_orden) REFERENCES orden_compra (id_orden)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_recepcion (
    id_detalle_recepcion INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_recepcion INT NOT NULL,
    id_detalle INT NOT NULL,
    cantidad_recibida_base DECIMAL(18,6) NOT NULL,
    cantidad_aceptada_base DECIMAL(18,6) NOT NULL,
    CONSTRAINT fk_dr_recepcion FOREIGN KEY (id_recepcion) REFERENCES recepcion (id_recepcion),
    CONSTRAINT fk_dr_detalle FOREIGN KEY (id_detalle) REFERENCES detalle_orden (id_detalle),
    CONSTRAINT uq_dr_recepcion_detalle UNIQUE (id_recepcion, id_detalle),
    CONSTRAINT ck_dr_recibida CHECK (cantidad_recibida_base > 0),
    CONSTRAINT ck_dr_aceptada CHECK (cantidad_aceptada_base BETWEEN 0 AND cantidad_recibida_base)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS conteo_fisico (
    id_conteo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    fecha_hora DATETIME NOT NULL,
    CONSTRAINT fk_cf_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_conteo (
    id_detalle_conteo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_conteo INT NOT NULL,
    id_insumo INT NOT NULL,
    cantidad_fisica_base DECIMAL(18,6) NOT NULL,
    cantidad_teorica_antes_base DECIMAL(18,6) NOT NULL,
    CONSTRAINT fk_dc_conteo FOREIGN KEY (id_conteo) REFERENCES conteo_fisico (id_conteo),
    CONSTRAINT fk_dc_insumo FOREIGN KEY (id_insumo) REFERENCES insumo (id_insumo),
    CONSTRAINT uq_dc_conteo_insumo UNIQUE (id_conteo, id_insumo),
    CONSTRAINT ck_dc_fisica CHECK (cantidad_fisica_base >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movimiento_inventario (
    id_movimiento INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_insumo INT NOT NULL,
    id_usuario INT NOT NULL,
    id_detalle_recepcion INT NULL,
    id_detalle_conteo INT NULL,
    fecha_hora DATETIME NOT NULL,
    tipo_movimiento VARCHAR(20) NOT NULL,
    variacion_cantidad_base DECIMAL(18,6) NOT NULL,
    motivo VARCHAR(500) NULL,
    id_insumo_saldo_inicial INT GENERATED ALWAYS AS (
        CASE WHEN tipo_movimiento = 'SALDO_INICIAL' THEN id_insumo ELSE NULL END
    ) VIRTUAL,
    CONSTRAINT fk_mi_insumo FOREIGN KEY (id_insumo) REFERENCES insumo (id_insumo),
    CONSTRAINT fk_mi_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
    CONSTRAINT fk_mi_recepcion FOREIGN KEY (id_detalle_recepcion)
        REFERENCES detalle_recepcion (id_detalle_recepcion),
    CONSTRAINT fk_mi_conteo FOREIGN KEY (id_detalle_conteo)
        REFERENCES detalle_conteo (id_detalle_conteo),
    CONSTRAINT uq_mi_recepcion UNIQUE (id_detalle_recepcion),
    CONSTRAINT uq_mi_conteo UNIQUE (id_detalle_conteo),
    CONSTRAINT uq_mi_saldo_inicial UNIQUE (id_insumo_saldo_inicial),
    INDEX idx_movimiento_insumo_fecha (id_insumo, fecha_hora),
    CONSTRAINT ck_mi_tipo_y_origen CHECK (
        (tipo_movimiento = 'ENTRADA' AND variacion_cantidad_base > 0
         AND id_detalle_recepcion IS NOT NULL AND id_detalle_conteo IS NULL)
        OR (tipo_movimiento = 'AJUSTE' AND variacion_cantidad_base <> 0
            AND id_detalle_recepcion IS NULL AND id_detalle_conteo IS NOT NULL)
        OR (tipo_movimiento IN ('CONSUMO', 'MERMA') AND variacion_cantidad_base < 0
            AND id_detalle_recepcion IS NULL AND id_detalle_conteo IS NULL)
        OR (tipo_movimiento = 'SALDO_INICIAL' AND variacion_cantidad_base > 0
            AND id_detalle_recepcion IS NULL AND id_detalle_conteo IS NULL)
    )
) ENGINE=InnoDB;

DELIMITER $$

CREATE TRIGGER IF NOT EXISTS validar_recepcion_insert
BEFORE INSERT ON detalle_recepcion
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM recepcion AS r
        JOIN detalle_orden AS d ON d.id_orden = r.id_orden
        WHERE r.id_recepcion = NEW.id_recepcion AND d.id_detalle = NEW.id_detalle
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El detalle no pertenece a la orden de la recepcion';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS validar_recepcion_update
BEFORE UPDATE ON detalle_recepcion
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM recepcion AS r
        JOIN detalle_orden AS d ON d.id_orden = r.id_orden
        WHERE r.id_recepcion = NEW.id_recepcion AND d.id_detalle = NEW.id_detalle
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El detalle no pertenece a la orden de la recepcion';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS validar_movimiento_insert
BEFORE INSERT ON movimiento_inventario
FOR EACH ROW
BEGIN
    IF NEW.tipo_movimiento = 'ENTRADA' AND NOT EXISTS (
        SELECT 1 FROM detalle_recepcion AS r
        JOIN detalle_orden AS d ON d.id_detalle = r.id_detalle
        WHERE r.id_detalle_recepcion = NEW.id_detalle_recepcion
          AND d.id_insumo = NEW.id_insumo
          AND r.cantidad_aceptada_base = NEW.variacion_cantidad_base
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La entrada no coincide con el insumo o la cantidad aceptada';
    END IF;
    IF NEW.tipo_movimiento = 'AJUSTE' AND NOT EXISTS (
        SELECT 1 FROM detalle_conteo AS c
        WHERE c.id_detalle_conteo = NEW.id_detalle_conteo
          AND c.id_insumo = NEW.id_insumo
          AND (c.cantidad_fisica_base - c.cantidad_teorica_antes_base) = NEW.variacion_cantidad_base
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ajuste no coincide con el insumo o la diferencia del conteo';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS validar_movimiento_update
BEFORE UPDATE ON movimiento_inventario
FOR EACH ROW
BEGIN
    IF NEW.tipo_movimiento = 'ENTRADA' AND NOT EXISTS (
        SELECT 1 FROM detalle_recepcion AS r
        JOIN detalle_orden AS d ON d.id_detalle = r.id_detalle
        WHERE r.id_detalle_recepcion = NEW.id_detalle_recepcion
          AND d.id_insumo = NEW.id_insumo
          AND r.cantidad_aceptada_base = NEW.variacion_cantidad_base
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La entrada no coincide con el insumo o la cantidad aceptada';
    END IF;
    IF NEW.tipo_movimiento = 'AJUSTE' AND NOT EXISTS (
        SELECT 1 FROM detalle_conteo AS c
        WHERE c.id_detalle_conteo = NEW.id_detalle_conteo
          AND c.id_insumo = NEW.id_insumo
          AND (c.cantidad_fisica_base - c.cantidad_teorica_antes_base) = NEW.variacion_cantidad_base
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ajuste no coincide con el insumo o la diferencia del conteo';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS conservar_orden_de_recepcion
BEFORE UPDATE ON recepcion
FOR EACH ROW
BEGIN
    IF NEW.id_orden <> OLD.id_orden AND EXISTS (
        SELECT 1 FROM detalle_recepcion WHERE id_recepcion = OLD.id_recepcion
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se cambia la orden de una recepcion con lineas registradas';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS conservar_linea_orden_recibida
BEFORE UPDATE ON detalle_orden
FOR EACH ROW
BEGIN
    IF (NEW.id_orden <> OLD.id_orden OR NEW.id_insumo <> OLD.id_insumo)
        AND EXISTS (SELECT 1 FROM detalle_recepcion WHERE id_detalle = OLD.id_detalle)
    THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se cambia la orden o el insumo de una linea con recepciones';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS conservar_origen_entrada
BEFORE UPDATE ON detalle_recepcion
FOR EACH ROW
BEGIN
    IF (NEW.id_detalle <> OLD.id_detalle OR NEW.id_recepcion <> OLD.id_recepcion
        OR NEW.cantidad_aceptada_base <> OLD.cantidad_aceptada_base)
        AND EXISTS (
            SELECT 1 FROM movimiento_inventario
            WHERE id_detalle_recepcion = OLD.id_detalle_recepcion
        )
    THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La linea de recepcion ya respalda una entrada de inventario';
    END IF;
END;
$$

CREATE TRIGGER IF NOT EXISTS conservar_origen_ajuste
BEFORE UPDATE ON detalle_conteo
FOR EACH ROW
BEGIN
    IF (NEW.id_conteo <> OLD.id_conteo OR NEW.id_insumo <> OLD.id_insumo
        OR NEW.cantidad_fisica_base <> OLD.cantidad_fisica_base
        OR NEW.cantidad_teorica_antes_base <> OLD.cantidad_teorica_antes_base)
        AND EXISTS (
            SELECT 1 FROM movimiento_inventario
            WHERE id_detalle_conteo = OLD.id_detalle_conteo
        )
    THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La linea de conteo ya respalda un ajuste de inventario';
    END IF;
END;
$$

DELIMITER ;

CREATE OR REPLACE VIEW v_stock_actual AS
SELECT i.id_insumo, i.nombre, i.unidad_base, i.stock_minimo,
       COALESCE(SUM(m.variacion_cantidad_base), 0) AS stock_actual
FROM insumo AS i
LEFT JOIN movimiento_inventario AS m ON m.id_insumo = i.id_insumo
GROUP BY i.id_insumo, i.nombre, i.unidad_base, i.stock_minimo;

CREATE OR REPLACE VIEW v_stock_bajo AS
SELECT id_insumo, nombre, unidad_base, stock_minimo, stock_actual
FROM v_stock_actual
WHERE stock_actual <= stock_minimo;


SELECT 'Tablas' AS objeto, COUNT(*) AS cantidad
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Vistas', COUNT(*)
FROM information_schema.views WHERE table_schema = DATABASE()
UNION ALL
SELECT 'Disparadores', COUNT(*)
FROM information_schema.triggers WHERE trigger_schema = DATABASE();
