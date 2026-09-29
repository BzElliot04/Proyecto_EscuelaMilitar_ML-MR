-- =====================================================================
-- Sistema de Reservas de Espacios - Escuela Militar
-- Script DDL para PostgreSQL
-- Una sola base de datos, un esquema por microservicio (MS-4 no tiene BD propia)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS ms2_verificacion;
CREATE SCHEMA IF NOT EXISTS ms1_nucleo;
CREATE SCHEMA IF NOT EXISTS ms3_inventario;
CREATE SCHEMA IF NOT EXISTS ms5_quejas;

-- =====================================================================
-- ESQUEMA: ms2_verificacion  (cuentas, roles, permisos, auditoria)
-- =====================================================================

CREATE TABLE ms2_verificacion.tipo_cuenta (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(30) NOT NULL UNIQUE  -- ADMINISTRADOR / DESARROLLADOR / USUARIO
);

CREATE TABLE ms1_nucleo.tipo_espacio (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(60) NOT NULL,
    tipo_padre_id   INTEGER REFERENCES ms1_nucleo.tipo_espacio(id)
);

CREATE TABLE ms2_verificacion.rol (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(60) NOT NULL,
    tipo_cuenta_id  INTEGER NOT NULL REFERENCES ms2_verificacion.tipo_cuenta(id),
    UNIQUE (nombre, tipo_cuenta_id)
);

CREATE TABLE ms2_verificacion.permiso (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(60) NOT NULL UNIQUE,   -- ej. REMITIR_SOLICITUD, APROBAR_RESERVA
    descripcion VARCHAR(200)
);

CREATE TABLE ms2_verificacion.rol_permiso (
    rol_id      INTEGER NOT NULL REFERENCES ms2_verificacion.rol(id) ON DELETE CASCADE,
    permiso_id  INTEGER NOT NULL REFERENCES ms2_verificacion.permiso(id) ON DELETE CASCADE,
    PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE ms2_verificacion.usuario (
    id                  SERIAL PRIMARY KEY,
    tipo_cuenta_id      INTEGER NOT NULL REFERENCES ms2_verificacion.tipo_cuenta(id),
    rol_id              INTEGER REFERENCES ms2_verificacion.rol(id),
    nombre_usuario      VARCHAR(60) NOT NULL UNIQUE,
    alias               VARCHAR(60),
    hash_password       VARCHAR(255) NOT NULL,
    prioridad           INTEGER DEFAULT 0,
    intentos_fallidos  SMALLINT NOT NULL DEFAULT 0,
    bloqueado           BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE ms2_verificacion.usuario_area (
    usuario_id      INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id) ON DELETE CASCADE,
    tipo_espacio_id INTEGER NOT NULL REFERENCES ms1_nucleo.tipo_espacio(id) ON DELETE CASCADE,
    PRIMARY KEY (usuario_id, tipo_espacio_id)
);

CREATE TABLE ms2_verificacion.registro_acceso (
    id          SERIAL PRIMARY KEY,
    usuario_id  INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id),
    fecha       TIMESTAMP NOT NULL DEFAULT now(),
    tipo_evento VARCHAR(30) NOT NULL,   -- LOGIN / LOGOUT / BLOQUEO
    exito       BOOLEAN NOT NULL,
    ip          VARCHAR(45)
);

CREATE TABLE ms2_verificacion.sesion_activa (
    id                  SERIAL PRIMARY KEY,
    usuario_id          INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id) ON DELETE CASCADE,
    token               VARCHAR(500) NOT NULL,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT now(),
    fecha_expiracion    TIMESTAMP NOT NULL,
    revocada            BOOLEAN NOT NULL DEFAULT FALSE
);

-- =====================================================================
-- ESQUEMA: ms1_nucleo  (espacios, reservas, convenios, notificaciones)
-- =====================================================================

CREATE TABLE ms1_nucleo.espacio (
    id                      SERIAL PRIMARY KEY,
    tipo_espacio_id         INTEGER NOT NULL REFERENCES ms1_nucleo.tipo_espacio(id),
    nombre                  VARCHAR(80) NOT NULL,
    encargado_usuario_id    INTEGER REFERENCES ms2_verificacion.usuario(id),
    activo                  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE ms1_nucleo.convenio (
    id                  SERIAL PRIMARY KEY,
    entidad_externa     VARCHAR(120) NOT NULL,
    tipo_convenio       VARCHAR(60),
    vigente_desde       DATE NOT NULL,
    vigente_hasta       DATE,
    notas_operativas    TEXT
);

CREATE TABLE ms1_nucleo.convenio_espacio (
    convenio_id INTEGER NOT NULL REFERENCES ms1_nucleo.convenio(id) ON DELETE CASCADE,
    espacio_id  INTEGER NOT NULL REFERENCES ms1_nucleo.espacio(id) ON DELETE CASCADE,
    PRIMARY KEY (convenio_id, espacio_id)
);

CREATE TABLE ms1_nucleo.bloque_convenio (
    id                          SERIAL PRIMARY KEY,
    convenio_id                 INTEGER NOT NULL,
    espacio_id                  INTEGER NOT NULL,
    dia_semana                  SMALLINT NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    hora_inicio                 TIME NOT NULL,
    hora_fin                    TIME NOT NULL,
    modificable_por_defecto     BOOLEAN NOT NULL DEFAULT FALSE,
    modificado_por_usuario_id   INTEGER REFERENCES ms2_verificacion.usuario(id),
    motivo_modificacion         VARCHAR(255),
    FOREIGN KEY (convenio_id, espacio_id) REFERENCES ms1_nucleo.convenio_espacio(convenio_id, espacio_id) ON DELETE CASCADE
);

CREATE TABLE ms1_nucleo.reserva (
    id                      SERIAL PRIMARY KEY,
    espacio_preferido_id    INTEGER NOT NULL REFERENCES ms1_nucleo.espacio(id),
    espacio_asignado_id     INTEGER REFERENCES ms1_nucleo.espacio(id),
    solicitante_usuario_id  INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id),
    remitente_usuario_id    INTEGER REFERENCES ms2_verificacion.usuario(id),
    resolutor_usuario_id    INTEGER REFERENCES ms2_verificacion.usuario(id),
    convenio_id             INTEGER REFERENCES ms1_nucleo.convenio(id),
    estado                  VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
                            CHECK (estado IN ('PENDIENTE','REMITIDA','APROBADA','RECHAZADA','CANCELADA')),
    orden_llegada           INTEGER,
    nota_resolucion         VARCHAR(500),
    fecha_solicitud         TIMESTAMP NOT NULL DEFAULT now(),
    fecha_resolucion        TIMESTAMP
);

CREATE TABLE ms1_nucleo.historial_reserva (
    id                  SERIAL PRIMARY KEY,
    reserva_id          INTEGER NOT NULL REFERENCES ms1_nucleo.reserva(id) ON DELETE CASCADE,
    estado_anterior     VARCHAR(20),
    estado_nuevo        VARCHAR(20) NOT NULL,
    usuario_id          INTEGER REFERENCES ms2_verificacion.usuario(id),
    comentario          VARCHAR(500),
    fecha               TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE ms1_nucleo.horario_mantenimiento (
    id              SERIAL PRIMARY KEY,
    espacio_id      INTEGER NOT NULL REFERENCES ms1_nucleo.espacio(id) ON DELETE CASCADE,
    fecha_inicio    TIMESTAMP NOT NULL,
    fecha_fin       TIMESTAMP NOT NULL,
    motivo          VARCHAR(255),
    creado_por_ms   VARCHAR(30) NOT NULL DEFAULT 'ms3_inventario'
);

CREATE TABLE ms1_nucleo.parametro_sistema (
    id          SERIAL PRIMARY KEY,
    clave       VARCHAR(80) NOT NULL UNIQUE,   -- ej. MAX_SOLICITUDES_ACTIVAS, PLAZO_RESOLUCION_HORAS
    valor       VARCHAR(255) NOT NULL,
    descripcion VARCHAR(255),
    activo      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE ms1_nucleo.notificacion (
    id                  SERIAL PRIMARY KEY,
    usuario_id          INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id) ON DELETE CASCADE,
    tipo                VARCHAR(40) NOT NULL,
    mensaje             VARCHAR(500) NOT NULL,
    referencia_entidad  VARCHAR(60),
    referencia_id       INTEGER,
    leida               BOOLEAN NOT NULL DEFAULT FALSE,
    fecha               TIMESTAMP NOT NULL DEFAULT now()
);

-- =====================================================================
-- ESQUEMA: ms3_inventario  (materiales y mantenimiento)
-- =====================================================================

CREATE TABLE ms3_inventario.tipo_consumible (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL,
    umbral_alerta   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE ms3_inventario.inventario_espacio (
    id                  SERIAL PRIMARY KEY,
    espacio_id          INTEGER NOT NULL REFERENCES ms1_nucleo.espacio(id),
    tipo_consumible_id  INTEGER NOT NULL REFERENCES ms3_inventario.tipo_consumible(id),
    saldo_disponible    INTEGER NOT NULL DEFAULT 0,
    UNIQUE (espacio_id, tipo_consumible_id)
);

CREATE TABLE ms3_inventario.movimiento_inventario (
    id                      SERIAL PRIMARY KEY,
    inventario_espacio_id   INTEGER NOT NULL REFERENCES ms3_inventario.inventario_espacio(id),
    tipo_movimiento         VARCHAR(10) NOT NULL CHECK (tipo_movimiento IN ('ENTRADA','SALIDA')),
    cantidad                INTEGER NOT NULL CHECK (cantidad > 0),
    responsable_usuario_id  INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id),
    motivo                  VARCHAR(255),
    fecha                   TIMESTAMP NOT NULL DEFAULT now()
);

-- =====================================================================
-- ESQUEMA: ms5_quejas  (sugerencias, reclamos, estadisticas)
-- =====================================================================

CREATE TABLE ms5_quejas.sugerencia_reclamo (
    id          SERIAL PRIMARY KEY,
    usuario_id  INTEGER NOT NULL REFERENCES ms2_verificacion.usuario(id),
    tipo        VARCHAR(20) NOT NULL CHECK (tipo IN ('SUGERENCIA','MEJORA','RECLAMO')),
    contenido   TEXT NOT NULL,
    estado      VARCHAR(20) NOT NULL DEFAULT 'RECIBIDA',
    fecha       TIMESTAMP NOT NULL DEFAULT now()
);

-- NOTA: ms4_ia (Agente de IA) no tiene esquema propio: consume datos
-- anonimizados de ms1_nucleo y ms5_quejas via API, sin persistir nada.
