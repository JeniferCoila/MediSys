--ALTER DATABASE CitasMedicasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

CREATE DATABASE CitasMedicasDB;
GO
USE CitasMedicasDB;
GO


/* =========================
   ROL
   ========================= */
CREATE TABLE Roles (
    IdRol       INT IDENTITY(1,1) PRIMARY KEY,
    NombreRol   VARCHAR(50) NOT NULL UNIQUE
);


/* =========================
   USUARIOS
   ========================= */
CREATE TABLE Usuarios (
    IdUsuario     INT IDENTITY(1,1) PRIMARY KEY,
    Username      VARCHAR(50)  NOT NULL UNIQUE,
    Password  VARCHAR(64)  NOT NULL,  
    IdRol         INT          NOT NULL,
    Estado        BIT          NOT NULL DEFAULT (1),
    CONSTRAINT FK_Usuarios_Roles
        FOREIGN KEY (IdRol) REFERENCES Roles(IdRol)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

------------------------------------
-----Para validar credenciales------
CREATE PROCEDURE usp_usuarios_login
    @username VARCHAR(50),
    @password VARCHAR(100) -- se convierte a hash
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.IdUsuario, u.Username, u.IdRol, r.NombreRol
    FROM Usuarios u
    JOIN Roles r ON u.IdRol = r.IdRol
    WHERE u.Username = @username
      AND u.Password = CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', @password), 2);
END

-- Insertar roles
INSERT INTO Roles (NombreRol) VALUES 
('Administrador'),
('Médico'),
('Paciente');
GO

SELECT * FROM Roles
SELECT * FROM Usuarios

-- Insertar con HASH 
INSERT INTO Usuarios (Username, Password, IdRol)
VALUES ('admin', CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', 'admin123'), 2), 1);

INSERT INTO Usuarios (Username, Password, IdRol)
VALUES ('medico1', CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', 'medico123'), 2), 2);

INSERT INTO Usuarios (Username, Password, IdRol)
VALUES ('paciente1', CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', 'paciente123'), 2), 3);



-- Insertar usuarios de prueba
INSERT INTO Usuarios (Username, Password, IdRol) VALUES 
('admin', 'admin123', 1),
('medico', 'medico123', 2),
('paciente', 'paciente123', 3);
GO


/* =========================
   PACIENTES
   ========================= */
CREATE TABLE Pacientes (
    IdPaciente       INT IDENTITY(1,1) PRIMARY KEY,
    DNI              VARCHAR(10)   NOT NULL,
    Nombre           VARCHAR(100)  NOT NULL,
    Apellido         VARCHAR(100)  NOT NULL,
    FechaNacimiento  DATE          NOT NULL,
    Genero           CHAR(1)       NULL,   -- 'M','F'
    Telefono         VARCHAR(15)   NULL,
    Correo           VARCHAR(100)  NULL,
    Direccion        VARCHAR(200)  NULL,
    Estado           BIT           NOT NULL DEFAULT (1),
    FechaCreacion      DATETIME    NOT NULL DEFAULT (GETDATE()),
    FechaActualizacion DATETIME    NULL,
    FechaBaja          DATETIME    NULL,
    RowVersion         ROWVERSION,

    -- Checks útiles
    CONSTRAINT CK_Pacientes_Genero
        CHECK (Genero IN ('M','F') OR Genero IS NULL),
    CONSTRAINT CK_Pacientes_DNI
        CHECK (LEN(DNI) BETWEEN 8 AND 15)
);

-- Unicidad de DNI solo para activos (borrado lógico)
CREATE UNIQUE INDEX UX_Pacientes_DNI_Activos
    ON dbo.Pacientes(DNI)
    WHERE Estado = 1;

CREATE UNIQUE INDEX UX_Pacientes_Identidad_Activos
ON dbo.Pacientes(Nombre, Apellido, FechaNacimiento)
WHERE Estado = 1;



----PROCEDURES----
CREATE PROCEDURE usp_pacientes
    @filtro VARCHAR(100) = ''
AS
BEGIN
    SELECT IdPaciente, DNI, Nombre, Apellido, FechaNacimiento, Genero, Telefono, Correo, Direccion
    FROM Pacientes
    WHERE Estado = 1 AND (Nombre LIKE '%' + @filtro + '%' OR DNI LIKE '%' + @filtro + '%')
END


CREATE OR ALTER PROCEDURE usp_pacientes_agregar
 @DNI VARCHAR(10), @Nombre VARCHAR(100), @Apellido VARCHAR(100),
 @FechaNacimiento DATE, @Genero CHAR(1)=NULL, @Telefono VARCHAR(15)=NULL,
 @Correo VARCHAR(100)=NULL, @Direccion VARCHAR(200)=NULL
AS
BEGIN
  SET NOCOUNT ON;

  IF EXISTS (SELECT 1 FROM Pacientes WHERE Estado=1 AND DNI=@DNI) RETURN -1; -- DNI duplicado

  IF EXISTS (SELECT 1 FROM Pacientes 
             WHERE Estado=1 AND Nombre=@Nombre AND Apellido=@Apellido AND FechaNacimiento=@FechaNacimiento)
    RETURN -2; -- misma persona

  INSERT INTO Pacientes(DNI,Nombre,Apellido,FechaNacimiento,Genero,Telefono,Correo,Direccion,Estado)
  VALUES(@DNI,@Nombre,@Apellido,@FechaNacimiento,@Genero,@Telefono,@Correo,@Direccion,1);

  RETURN 1;
END



CREATE OR ALTER PROCEDURE usp_pacientes_buscar
  @IdPaciente INT
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    IdPaciente, DNI, Nombre, Apellido, FechaNacimiento,
    Genero, Telefono, Correo, Direccion,
    FechaCreacion, FechaActualizacion, FechaBaja
  FROM Pacientes
  WHERE IdPaciente=@IdPaciente;
END



CREATE OR ALTER PROCEDURE usp_pacientes_actualizar
 @IdPaciente INT,
 @DNI VARCHAR(10), @Nombre VARCHAR(100), @Apellido VARCHAR(100),
 @FechaNacimiento DATE, @Genero CHAR(1)=NULL, @Telefono VARCHAR(15)=NULL,
 @Correo VARCHAR(100)=NULL, @Direccion VARCHAR(200)=NULL
AS
BEGIN
  SET NOCOUNT ON;

  IF NOT EXISTS (SELECT 1 FROM Pacientes WHERE IdPaciente=@IdPaciente AND Estado=1) RETURN -99;

  IF EXISTS (SELECT 1 FROM Pacientes WHERE Estado=1 AND DNI=@DNI AND IdPaciente<>@IdPaciente) RETURN -1;

  IF EXISTS (SELECT 1 FROM Pacientes 
             WHERE Estado=1 AND Nombre=@Nombre AND Apellido=@Apellido AND FechaNacimiento=@FechaNacimiento
                   AND IdPaciente<>@IdPaciente) RETURN -2;

  UPDATE Pacientes
  SET DNI=@DNI, Nombre=@Nombre, Apellido=@Apellido, FechaNacimiento=@FechaNacimiento,
      Genero=@Genero, Telefono=@Telefono, Correo=@Correo, Direccion=@Direccion,
      FechaActualizacion=GETDATE()
  WHERE IdPaciente=@IdPaciente;

  RETURN 1;
END



CREATE OR ALTER PROCEDURE usp_pacientes_eliminar
  @IdPaciente INT
AS
BEGIN
  SET NOCOUNT ON;

  UPDATE Pacientes
  SET Estado=0, FechaBaja=GETDATE()
  WHERE IdPaciente=@IdPaciente AND Estado=1;
END



CREATE PROCEDURE usp_pacientes_contar
AS
BEGIN
    SELECT COUNT(*) AS Total
    FROM Pacientes
    WHERE Estado = 1;
END

INSERT INTO Pacientes (DNI, Nombre, Apellido, FechaNacimiento, Genero, Telefono, Correo, Direccion, Estado)
VALUES
('12345678', 'Juan', 'Pérez', '1985-03-15', 'M', '987654321', 'juan.perez@mail.com', 'Av. Siempre Viva 123', 1),
('87654321', 'María', 'López', '1990-07-22', 'F', '912345678', 'maria.lopez@mail.com', 'Calle Lima 456', 1),
('23456789', 'Carlos', 'Ramírez', '1982-05-10', 'M', '998877665', 'carlos.ramirez@mail.com', 'Jr. Arequipa 789', 1),
('34567890', 'Ana', 'Torres', '1995-09-18', 'F', '987123456', 'ana.torres@mail.com', 'Av. Grau 101', 1),
('45678901', 'Luis', 'Fernández', '1988-01-05', 'M', '912398745', 'luis.fernandez@mail.com', 'Calle Libertad 202', 1),
('56789012', 'Patricia', 'Castro', '1992-12-11', 'F', '976543210', 'patricia.castro@mail.com', 'Av. La Marina 303', 1),
('67890123', 'Ricardo', 'Vargas', '1984-06-27', 'M', '945612378', 'ricardo.vargas@mail.com', 'Jr. Callao 404', 1),
('78901234', 'Gabriela', 'Salazar', '1993-04-02', 'F', '965478123', 'gabriela.salazar@mail.com', 'Av. Universitaria 505', 1),
('89012345', 'Miguel', 'Herrera', '1981-08-14', 'M', '978541236', 'miguel.herrera@mail.com', 'Calle Central 606', 1),
('90123456', 'Claudia', 'Rojas', '1996-02-20', 'F', '987456321', 'claudia.rojas@mail.com', 'Jr. Amazonas 707', 1),
('11223344', 'Pedro', 'Castillo', '1983-10-30', 'M', '912345987', 'pedro.castillo@mail.com', 'Av. Independencia 808', 1),
('22334455', 'Sofía', 'Mendoza', '1997-07-12', 'F', '976541289', 'sofia.mendoza@mail.com', 'Calle San Martín 909', 1),
('33445566', 'Jorge', 'Aguilar', '1989-05-08', 'M', '945612389', 'jorge.aguilar@mail.com', 'Jr. Cusco 111', 1),
('44556677', 'Verónica', 'Paredes', '1991-03-16', 'F', '978541239', 'veronica.paredes@mail.com', 'Av. Primavera 222', 1),
('55667788', 'Fernando', 'Gutiérrez', '1980-11-25', 'M', '987456329', 'fernando.gutierrez@mail.com', 'Calle Las Flores 333', 1),
('66778899', 'Carmen', 'Vega', '1994-09-09', 'F', '912345981', 'carmen.vega@mail.com', 'Jr. Los Olivos 444', 1),
('77889900', 'Andrés', 'Chávez', '1987-01-17', 'M', '976541280', 'andres.chavez@mail.com', 'Av. Colonial 555', 1),
('88990011', 'Natalia', 'Ruiz', '1998-06-03', 'F', '945612380', 'natalia.ruiz@mail.com', 'Calle Arequipa 666', 1),
('99001122', 'Hugo', 'Morales', '1986-12-29', 'M', '978541230', 'hugo.morales@mail.com', 'Jr. Lima 777', 1),
('10111213', 'Paola', 'Sánchez', '1999-04-07', 'F', '987456320', 'paola.sanchez@mail.com', 'Av. Progreso 888', 1);


/* =========================
   ESPECIALIDADES
   ========================= */
CREATE TABLE Especialidades (
    IdEspecialidad  INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL UNIQUE,
    Estado          BIT NOT NULL DEFAULT (1)
);

/* =========================
   MÉDICOS
   ========================= */
CREATE TABLE Medicos (
    IdMedico INT IDENTITY(1,1) PRIMARY KEY,
    CMP VARCHAR(20) NOT NULL UNIQUE,
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    IdEspecialidad INT NOT NULL,
    Telefono VARCHAR(15) NULL,
    Correo VARCHAR(100) NULL,
    Estado BIT NOT NULL DEFAULT (1),
    FechaCreacion DATETIME NOT NULL DEFAULT (GETDATE()),
    FechaActualizacion DATETIME NULL,
    FechaBaja DATETIME NULL,
    RowVersion ROWVERSION,
    CONSTRAINT FK_Medicos_Especialidades
        FOREIGN KEY (IdEspecialidad) REFERENCES dbo.Especialidades(IdEspecialidad)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


/* =========================
   ESTADOS DE CITA (catálogo)
   ========================= */
CREATE TABLE EstadosCita (
    IdEstadoCita INT IDENTITY(1,1) PRIMARY KEY,
    Nombre       VARCHAR(50) NOT NULL UNIQUE
);

/* =========================
   CITAS
   ========================= */
CREATE TABLE Citas (
    IdCita         INT IDENTITY(1,1) PRIMARY KEY,
    IdPaciente     INT       NOT NULL,
    IdMedico       INT       NOT NULL,
    Fecha          DATE      NOT NULL,
    HoraInicio     TIME      NOT NULL,
    HoraFin        TIME      NULL,      -- recomendado para duración
    IdEstadoCita   INT       NOT NULL,
    Motivo         VARCHAR(255) NULL,
    Observaciones  VARCHAR(500) NULL,
    Estado         BIT       NOT NULL DEFAULT (1),
    FechaCreacion      DATETIME    NOT NULL DEFAULT (GETDATE()),
    FechaActualizacion DATETIME    NULL,
    FechaBaja          DATETIME    NULL,
    RowVersion         ROWVERSION,

    CONSTRAINT FK_Citas_Pacientes
        FOREIGN KEY (IdPaciente)   REFERENCES dbo.Pacientes(IdPaciente)
        ON UPDATE NO ACTION ON DELETE NO ACTION,

    CONSTRAINT FK_Citas_Medicos
        FOREIGN KEY (IdMedico)     REFERENCES dbo.Medicos(IdMedico)
        ON UPDATE NO ACTION ON DELETE NO ACTION,

    CONSTRAINT FK_Citas_EstadosCita
        FOREIGN KEY (IdEstadoCita) REFERENCES dbo.EstadosCita(IdEstadoCita)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

-- Índices útiles para listados y agenda
CREATE INDEX IX_Citas_Medico_Fecha ON dbo.Citas(IdMedico, Fecha);
CREATE INDEX IX_Citas_Paciente_Fecha ON dbo.Citas(IdPaciente, Fecha);

----INSERTAR ESPECIALIDADES----
INSERT INTO Especialidades (Nombre) VALUES
('Cardiología'),
('Pediatría'),
('Neurología'),
('Dermatología'),
('Traumatología'),
('Oftalmología'),
('Gastroenterología'),
('Oncología'),
('Medicina General'),
('Otorrinolaringología');

INSERT INTO Especialidades (Nombre) VALUES
('Psicología');


---ESPECIALIDADES ACTIVAS
CREATE PROCEDURE usp_Especialidades_Listar
AS
BEGIN
    SELECT IdEspecialidad, Nombre
    FROM Especialidades
    WHERE Estado = 1
    ORDER BY Nombre;
END
GO
---PROCEDURES MÉDICOS----
CREATE OR ALTER PROCEDURE usp_medicos
    @filtro VARCHAR(100) = ''
AS
BEGIN
    SELECT  m.IdMedico,
            m.CMP,
            m.Nombre,
            m.Apellido,
            m.IdEspecialidad,
            e.Nombre AS NombreEspecialidad,
            m.Telefono,
            m.Correo
    FROM dbo.Medicos m
    INNER JOIN dbo.Especialidades e ON e.IdEspecialidad = m.IdEspecialidad
    WHERE m.Estado = 1
      AND (
            @filtro = '' OR
            m.CMP LIKE '%' + @filtro + '%' OR
            m.Nombre LIKE '%' + @filtro + '%' OR
            m.Apellido LIKE '%' + @filtro + '%'
          )
    ORDER BY m.IdMedico;
END
GO


CREATE OR ALTER PROCEDURE usp_medicos_buscar
    @IdMedico INT
AS
BEGIN
    SELECT  m.IdMedico,
            m.CMP,
            m.Nombre,
            m.Apellido,
            m.IdEspecialidad,
            m.Telefono,
            m.Correo,
            m.FechaCreacion,
            m.FechaActualizacion,
            m.FechaBaja,
            e.Nombre AS NombreEspecialidad
    FROM Medicos m
    INNER JOIN Especialidades e ON e.IdEspecialidad = m.IdEspecialidad
    WHERE m.IdMedico = @IdMedico AND m.Estado = 1;
END
GO


CREATE OR ALTER PROCEDURE usp_medicos_agregar
    @CMP            VARCHAR(20),
    @Nombre         VARCHAR(100),
    @Apellido       VARCHAR(100),
    @IdEspecialidad INT,
    @Telefono       VARCHAR(15) = NULL,
    @Correo         VARCHAR(100) = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Medicos WHERE CMP = @CMP AND Estado = 1)
        RETURN -1; -- CMP duplicado

    IF EXISTS (SELECT 1 FROM Medicos WHERE Nombre=@Nombre AND Apellido=@Apellido AND Estado = 1)
        RETURN -2; -- Nombre+Apellido duplicado

    INSERT INTO Medicos(CMP,Nombre,Apellido,IdEspecialidad,Telefono,Correo)
    VALUES (@CMP,@Nombre,@Apellido,@IdEspecialidad,@Telefono,@Correo);

    RETURN 1;
END
GO

CREATE OR ALTER PROCEDURE usp_medicos_actualizar
    @IdMedico       INT,
    @CMP            VARCHAR(20),
    @Nombre         VARCHAR(100),
    @Apellido       VARCHAR(100),
    @IdEspecialidad INT,
    @Telefono       VARCHAR(15) = NULL,
    @Correo         VARCHAR(100) = NULL
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Medicos WHERE IdMedico=@IdMedico AND Estado=1)
        RETURN -99;

    IF EXISTS (SELECT 1 FROM Medicos WHERE CMP=@CMP AND IdMedico<>@IdMedico AND Estado=1)
        RETURN -1;

    IF EXISTS (SELECT 1 FROM Medicos
               WHERE Nombre=@Nombre AND Apellido=@Apellido AND IdMedico<>@IdMedico AND Estado=1)
        RETURN -2;

    UPDATE Medicos
       SET CMP=@CMP,
           Nombre=@Nombre,
           Apellido=@Apellido,
           IdEspecialidad=@IdEspecialidad,
           Telefono=@Telefono,
           Correo=@Correo,
           FechaActualizacion = GETDATE()
     WHERE IdMedico=@IdMedico AND Estado=1;

    RETURN 1;
END
GO

CREATE OR ALTER PROCEDURE usp_medicos_eliminar
    @IdMedico INT
AS
BEGIN
    UPDATE Medicos
       SET Estado = 0,
           FechaBaja = GETDATE()
     WHERE IdMedico = @IdMedico AND Estado = 1;
END
GO




CREATE OR ALTER PROCEDURE usp_medicos_contar
AS
BEGIN
    SELECT COUNT(1) FROM Medicos WHERE Estado = 1;
END
GO


INSERT INTO Medicos (CMP, Nombre, Apellido, IdEspecialidad, Telefono, Correo)
VALUES
('CMP001', 'Luis', 'García', 1, '987654321', 'luis.garcia@clinica.com'),
('CMP002', 'María', 'Pérez', 2, '912345678', 'maria.perez@clinica.com'),
('CMP003', 'Juan', 'Fernández', 3, '999888777', 'juan.fernandez@clinica.com'),
('CMP004', 'Ana', 'Torres', 4, '955112233', 'ana.torres@clinica.com'),
('CMP005', 'Pedro', 'Ramírez', 5, '944223344', 'pedro.ramirez@clinica.com'),
('CMP006', 'Carmen', 'Ruiz', 6, '933445566', 'carmen.ruiz@clinica.com'),
('CMP007', 'Jorge', 'Flores', 7, '922556677', 'jorge.flores@clinica.com'),
('CMP008', 'Laura', 'Gómez', 8, '911667788', 'laura.gomez@clinica.com'),
('CMP009', 'Roberto', 'Martínez', 9, '988776655', 'roberto.martinez@clinica.com'),
('CMP010', 'Patricia', 'Castillo', 10, '977665544', 'patricia.castillo@clinica.com'),
('CMP011', 'Diego', 'Morales', 1, '966554433', 'diego.morales@clinica.com'),
('CMP012', 'Sofía', 'Vega', 2, '955443322', 'sofia.vega@clinica.com'),
('CMP013', 'Andrés', 'Campos', 3, '944332211', 'andres.campos@clinica.com'),
('CMP014', 'Elena', 'Rojas', 4, '933221100', 'elena.rojas@clinica.com'),
('CMP015', 'Francisco', 'Navarro', 5, '922110099', 'francisco.navarro@clinica.com');

INSERT INTO Medicos (CMP, Nombre, Apellido, IdEspecialidad, Telefono, Correo)
VALUES
('CMP016', 'Mateo', 'Silva', 1, '987123456', 'mateo.silva@clinica.com'),
('CMP017', 'Isabella', 'Cruz', 2, '988234567', 'isabella.cruz@clinica.com'),
('CMP018', 'Gabriel', 'Ortega', 3, '989345678', 'gabriel.ortega@clinica.com'),
('CMP019', 'Valentina', 'Paredes', 4, '990456789', 'valentina.paredes@clinica.com'),
('CMP020', 'Sebastián', 'Herrera', 5, '991567890', 'sebastian.herrera@clinica.com');

SELECT * FROM Medicos