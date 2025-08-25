--ALTER DATABASE CitasMedicasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
use master
drop database CitasMedicasDB;
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
GO

-- Insertar roles------
INSERT INTO Roles (NombreRol) VALUES 
('Administrador'),
('Médico'),
('Paciente');
GO


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
GO

-- Insertar con HASH 
INSERT INTO Usuarios (Username, Password, IdRol)
VALUES ('admin', CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', 'admin123'), 2), 1);
GO

INSERT INTO Usuarios (Username, Password, IdRol)
VALUES ('medico', CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', 'medico123'), 2), 2);
GO

INSERT INTO Usuarios (Username, Password, IdRol)
VALUES ('paciente', CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', 'paciente123'), 2), 3);
GO

--------------------------------------------------------------
/*Para validar credenciales*/
--------------------------------------------------------------
CREATE OR ALTER PROCEDURE usp_usuarios_login
    @username VARCHAR(50),
    @password VARCHAR(100) -- se convierte a hash
AS
BEGIN
    SELECT u.IdUsuario, u.Username, u.IdRol, r.NombreRol
    FROM Usuarios u
    JOIN Roles r ON u.IdRol = r.IdRol
    WHERE u.Username = @username
      AND u.Password = CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', @password), 2);
END
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
GO

-- Unicidad de DNI solo para activos (borrado lógico)
CREATE UNIQUE INDEX UX_Pacientes_DNI_Activos
    ON dbo.Pacientes(DNI)
    WHERE Estado = 1;
GO


CREATE UNIQUE INDEX UX_Pacientes_Identidad_Activos
ON dbo.Pacientes(Nombre, Apellido, FechaNacimiento)
WHERE Estado = 1;
GO


----PROCEDURES----
CREATE PROCEDURE usp_pacientes
    @filtro VARCHAR(100) = ''
AS
BEGIN
    SELECT IdPaciente, DNI, Nombre, Apellido, FechaNacimiento, Genero, Telefono, Correo, Direccion
    FROM Pacientes
    WHERE Estado = 1 AND (Nombre LIKE '%' + @filtro + '%' OR DNI LIKE '%' + @filtro + '%')
END
GO


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
GO


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
GO



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
GO


CREATE OR ALTER PROCEDURE usp_pacientes_eliminar
  @IdPaciente INT
AS
BEGIN
  SET NOCOUNT ON;

  UPDATE Pacientes
  SET Estado=0, FechaBaja=GETDATE()
  WHERE IdPaciente=@IdPaciente AND Estado=1;
END
GO


CREATE PROCEDURE usp_pacientes_contar
AS
BEGIN
    SELECT COUNT(*) AS Total
    FROM Pacientes
    WHERE Estado = 1;
END
GO


---DBCC CHECKIDENT ('dbo.Pacientes', RESEED, 0);
---DBCC CHECKIDENT ('dbo.Medicos', RESEED, 0);
---DBCC CHECKIDENT ('dbo.Especialidades', RESEED, 0);


INSERT INTO Pacientes (DNI, Nombre, Apellido, FechaNacimiento, Genero, Telefono, Correo, Direccion, Estado)
VALUES
('33445566','David','Cohen','1980-05-12','M','987654321','david.cohen@example.com','Calle Jerusalén 101',1),
('44556677','Sara','Levy','1992-07-08','F','988765432','sara.levy@example.com','Av. Israel 202',1),
('55667788','Yaakov','Goldstein','1975-03-19','M','989876543','yaakov.goldstein@example.com','Jr. Sion 303',1),
('66778899','Miriam','Katz','1988-11-25','F','990987654','miriam.katz@example.com','Calle Moriah 404',1),
('77889900','Eli','Rosenberg','1995-09-15','M','991098765','eli.rosenberg@example.com','Av. Shalom 505',1),
('88990011','Hannah','Weiss','1983-12-02','F','992109876','hannah.weiss@example.com','Jr. Canaán 606',1),
('99001122','Isaac','Kaplan','1979-08-22','M','993210987','isaac.kaplan@example.com','Calle Sinaí 707',1),
('12345678','Rachel','Friedman','1990-04-10','F','994321098','rachel.friedman@example.com','Av. Galilea 808',1),
('23456789','Daniel','Adler','1987-06-30','M','995432109','daniel.adler@example.com','Jr. Negev 909',1),
('34567890','Leah','Horowitz','1993-01-18','F','996543210','leah.horowitz@example.com','Calle Carmel 111',1),
('45678901','Benjamin','Shapiro','1976-10-05','M','997654321','benjamin.shapiro@example.com','Av. Monte 222',1),
('56789012','Esther','Stein','1989-03-28','F','998765432','esther.stein@example.com','Jr. Betel 333',1),
('67890123','Shlomo','Peretz','1984-07-14','M','999876543','shlomo.peretz@example.com','Calle Tabor 444',1),
('78901234','Naomi','Greenberg','1991-11-07','F','900987654','naomi.greenberg@example.com','Av. Keren 555',1),
('89012345','Yonatan','Leibowitz','1978-09-21','M','901098765','yonatan.leibowitz@example.com','Jr. Aravá 666',1),
('90123456','Deborah','Goren','1994-05-16','F','902109876','deborah.goren@example.com','Calle Kidron 777',1),
('11223344','Moshe','Mizrahi','1981-02-12','M','903210987','moshe.mizrahi@example.com','Av. Zion 888',1),
('22334455','Judith','Edelman','1992-08-03','F','904321098','judith.edelman@example.com','Jr. Hebrón 999',1),
('33445577','Samuel','Schwartz','1977-12-09','M','905432109','samuel.schwartz@example.com','Calle Gilboa 121',1),
('44556688','Ruth','Bernstein','1986-06-25','F','906543210','ruth.bernstein@example.com','Av. Tiberias 232',1),
('55667799','Ariel','Carmi','1990-09-13','M','907654321','ariel.carmi@example.com','Jr. Neot 343',1),
('66778800','Tamar','Zilberman','1985-04-04','F','908765432','tamar.zilberman@example.com','Calle Yehuda 454',1),
('77889911','Yosef','Grossman','1982-07-28','M','909876543','yosef.grossman@example.com','Av. Carmel 565',1),
('88990022','Rebecca','Dahan','1993-10-19','F','910987654','rebecca.dahan@example.com','Jr. Shira 676',1),
('99001133','Efraim','Halpern','1974-03-06','M','911098765','efraim.halpern@example.com','Calle Kedem 787',1),
('12344321','Levana','Amiel','1988-01-29','F','912109876','levana.amiel@example.com','Av. Hermón 898',1),
('23455432','Gideon','Yosefi','1991-09-09','M','913210987','gideon.yosefi@example.com','Jr. Migdal 909',1),
('34566543','Shira','Melamed','1987-12-18','F','914321098','shira.melamed@example.com','Calle Haifa 111',1),
('45677654','Noam','Barak','1995-06-24','M','915432109','noam.barak@example.com','Av. Moriah 222',1),
('56788765','Dina','Shohat','1989-02-14','F','916543210','dina.shohat@example.com','Jr. Tikva 333',1),
('67899876','Avraham','Tal','1976-10-11','M','917654321','avraham.tal@example.com','Calle Sharon 444',1),
('78900987','Orit','Neeman','1984-07-07','F','918765432','orit.neeman@example.com','Av. Carmel 555',1),
('89011098','Eliyahu','Rimon','1979-09-30','M','919876543','eliyahu.rimon@example.com','Jr. Golan 666',1),
('90122109','Batya','Armoni','1992-03-05','F','920987654','batya.armoni@example.com','Calle Jordan 777',1),
('11233220','Yitzhak','Dror','1983-12-01','M','921098765','yitzhak.dror@example.com','Av. Sharon 888',1),
('22344331','Hadassah','Luria','1987-08-16','F','922109876','hadassah.luria@example.com','Jr. Efrat 999',1),
('33455442','Natan','Peled','1990-05-20','M','923210987','natan.peled@example.com','Calle Sorek 121',1),
('44566553','Ziva','Baruch','1993-11-11','F','924321098','ziva.baruch@example.com','Av. Yehuda 232',1),
('55677664','Oren','Dayan','1981-04-22','M','925432109','oren.dayan@example.com','Jr. Netanya 343',1),
('66788775','Malka','Ashkenazi','1985-06-06','F','926543210','malka.ashkenazi@example.com','Calle Carmel 454',1);
GO

/* =========================
   ESPECIALIDADES
   ========================= */
CREATE TABLE Especialidades (
    IdEspecialidad  INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL UNIQUE,
    Estado          BIT NOT NULL DEFAULT (1)
);
GO


----INSERTAR ESPECIALIDADES----
INSERT INTO Especialidades (Nombre)
VALUES
('Cardiología'),
('Dermatología'),
('Neurología'),
('Pediatría'),
('Gastroenterología'),
('Traumatología'),
('Oncología'),
('Oftalmología'),
('Otorrinolaringología'),
('Nefrología'),
('Endocrinología'),
('Reumatología'),
('Ginecología'),
('Urología'),
('Neumología'),
('Hematología'),
('Psiquiatría'),
('Medicina Interna'),
('Medicina Familiar'),
('Alergología');
GO



/* =========================
   ESTADOS DE CITA (catálogo)
   ========================= */
 CREATE  TABLE EstadosCita (
    IdEstadoCita INT IDENTITY(1,1) PRIMARY KEY,
    Nombre       VARCHAR(50) NOT NULL UNIQUE,
    BloqueaAgenda BIT NOT NULL 
);
GO


INSERT INTO dbo.EstadosCita (Nombre, BloqueaAgenda)
VALUES 
    ('Programada', 1),   -- bloquea, las otras no
    ('Atendida',   0),
    ('Cancelada',  0),
    ('No asistió', 0);
GO



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
GO

-----------------------------
/*AGREGAR CAMPO PARA FOTO*/
-----------------------------
ALTER TABLE Medicos
ADD FotoUrl VARCHAR(200) NOT NULL
    CONSTRAINT DF_Medicos_FotoUrl DEFAULT ('');
GO


-- 1) Backfill: poner placeholder a los ya existentes sin foto
UPDATE dbo.Medicos
SET FotoUrl = '/uploads/medicos/default-medico.png'
WHERE FotoUrl IS NULL OR LTRIM(RTRIM(FotoUrl)) = '';
GO


-- 2) Default para nuevos inserts (defensa adicional)
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.Medicos')
      AND name = 'DF_Medicos_FotoUrl'
)
BEGIN
    ALTER TABLE dbo.Medicos
    ADD CONSTRAINT DF_Medicos_FotoUrl
        DEFAULT('/uploads/medicos/default-medico.png') FOR FotoUrl;
END
GO


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
            m.Correo,
			m.FotoUrl
    FROM dbo.Medicos m
    INNER JOIN dbo.Especialidades e ON e.IdEspecialidad = m.IdEspecialidad
    WHERE m.Estado = 1
      AND (
            @filtro = '' OR
            m.CMP LIKE '%' + @filtro + '%' OR
            m.Nombre LIKE '%' + @filtro + '%' OR
            m.Apellido LIKE '%' + @filtro + '%' OR
			e.Nombre LIKE '%'+@filtro+'%'
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
            e.Nombre AS NombreEspecialidad,
			m.FotoUrl
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
    @Correo         VARCHAR(100) = NULL,
	@FotoUrl        VARCHAR(200)  
AS
BEGIN
	IF (NULLIF(@FotoUrl,'') IS NULL) 
        RETURN -10;  -- Foto requerida

    IF EXISTS (SELECT 1 FROM Medicos WHERE CMP = @CMP AND Estado = 1)
        RETURN -1; -- CMP duplicado

    IF EXISTS (SELECT 1 FROM Medicos WHERE Nombre=@Nombre AND Apellido=@Apellido AND Estado = 1)
        RETURN -2; -- Nombre+Apellido duplicado

    INSERT INTO Medicos(CMP,Nombre,Apellido,IdEspecialidad,Telefono,Correo,FotoUrl)
    VALUES (@CMP,@Nombre,@Apellido,@IdEspecialidad,@Telefono,@Correo,@FotoUrl);

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

---INSERTAR MÉDICOS
INSERT INTO Medicos (CMP, Nombre, Apellido, IdEspecialidad, Telefono, Correo)
VALUES
('CMP101', 'Eitan',      'Levy',          1,  '987111001', 'eitan.levy@clinica.com'),
('CMP102', 'Yael',       'Cohen',         2,  '987111002', 'yael.cohen@clinica.com'),
('CMP103', 'Ariel',      'Mizrahi',       3,  '987111003', 'ariel.mizrahi@clinica.com'),
('CMP104', 'Noa',        'Ben-David',     4,  '987111004', 'noa.bendavid@clinica.com'),
('CMP105', 'Nadav',      'Katz',          5,  '987111005', 'nadav.katz@clinica.com'),
('CMP106', 'Tamar',      'Azoulay',       6,  '987111006', 'tamar.azoulay@clinica.com'),
('CMP107', 'Lior',       'Baruch',        7,  '987111007', 'lior.baruch@clinica.com'),
('CMP108', 'Shira',      'Gabbay',        8,  '987111008', 'shira.gabbay@clinica.com'),
('CMP109', 'Yonatan',    'Dayan',         9,  '987111009', 'yonatan.dayan@clinica.com'),
('CMP110', 'Michal',     'Halevi',        10, '987111010', 'michal.halevi@clinica.com'),
('CMP111', 'Itai',       'Shalev',        11, '987111011', 'itai.shalev@clinica.com'),
('CMP112', 'Rivka',      'Zohar',         12, '987111012', 'rivka.zohar@clinica.com'),
('CMP113', 'Omer',       'Avraham',       13, '987111013', 'omer.avraham@clinica.com'),
('CMP114', 'Gal',        'Peretz',        14, '987111014', 'gal.peretz@clinica.com'),
('CMP115', 'Leah',       'Bar-On',        15, '987111015', 'leah.baron@clinica.com'),
('CMP116', 'Amir',       'Goldstein',     16, '987111016', 'amir.goldstein@clinica.com'),
('CMP117', 'Maya',       'Yehuda',        17, '987111017', 'maya.yehuda@clinica.com'),
('CMP118', 'Ziv',        'Hadad',         18, '987111018', 'ziv.hadad@clinica.com'),
('CMP119', 'Dana',       'Malka',         19, '987111019', 'dana.malka@clinica.com'),
('CMP120', 'Noam',       'Biton',         20, '987111020', 'noam.biton@clinica.com');
GO



/* =========================
   CITAS
   ========================= */

-- Citas (Estado=1 activa, 0 cancelada)
CREATE TABLE dbo.Citas (
        IdCita              INT IDENTITY(1,1) PRIMARY KEY,
        IdPaciente          INT         NOT NULL,
        IdMedico            INT         NOT NULL,
        Fecha               DATE        NOT NULL,
        HoraInicio          TIME(0)     NOT NULL,
        HoraFin             TIME(0)     NULL,          -- si NULL, asumirá duración  defecto (30 min)
        IdEstadoCita        INT         NOT NULL CONSTRAINT DF_Citas_IdEstadoCita DEFAULT (1), -- Pendiente
        Motivo              VARCHAR(200) NULL,
        Observaciones       VARCHAR(500) NULL,
        Estado              BIT         NOT NULL DEFAULT (1),  -- 1=activo, 0=baja lógica
        FechaCreacion       DATETIME    NOT NULL DEFAULT (GETDATE()),
        FechaActualizacion  DATETIME    NULL,
        FechaBaja           DATETIME    NULL,
        RowVersion          ROWVERSION,

        CONSTRAINT FK_Citas_Pacientes
            FOREIGN KEY (IdPaciente) REFERENCES dbo.Pacientes(IdPaciente)
            ON UPDATE NO ACTION ON DELETE NO ACTION,

        CONSTRAINT FK_Citas_Medicos
            FOREIGN KEY (IdMedico)   REFERENCES dbo.Medicos(IdMedico)
            ON UPDATE NO ACTION ON DELETE NO ACTION,

        CONSTRAINT FK_Citas_EstadosCita
            FOREIGN KEY (IdEstadoCita) REFERENCES dbo.EstadosCita(IdEstadoCita)
            ON UPDATE NO ACTION ON DELETE NO ACTION,

        -- Validación: si HoraFin no es NULL debe ser mayor a HoraInicio
        CONSTRAINT CK_Citas_RangoHora CHECK (HoraFin IS NULL OR HoraFin > HoraInicio)
    );

    -- Índices para agenda y listados
    CREATE INDEX IX_Citas_Medico_Fecha ON dbo.Citas (IdMedico, Fecha, HoraInicio);
    CREATE INDEX IX_Citas_Paciente_Fecha ON dbo.Citas (IdPaciente, Fecha);
GO

------------------------------------------------------------------------------------------------------------------------------
/*PROCEDURES CITAS*/
------------------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_citas
    @filtro VARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.IdCita,
        c.IdPaciente,
        p.DNI                   AS PacienteDNI,
		(p.Nombre + ' ' + p.Apellido) AS PacienteNombreCompleto,
        c.IdMedico,
        m.CMP                   AS MedicoCMP,
        (m.Nombre + ' ' + m.Apellido) AS MedicoNombreCompleto,
        c.Fecha,
        c.HoraInicio,
        c.HoraFin,
        c.IdEstadoCita,
        e.Nombre                AS NombreEstado,
        c.Motivo,
        c.Observaciones
    FROM dbo.Citas c
    JOIN dbo.Pacientes p ON p.IdPaciente = c.IdPaciente
    JOIN dbo.Medicos   m ON m.IdMedico   = c.IdMedico
    JOIN dbo.EstadosCita e ON e.IdEstadoCita = c.IdEstadoCita
    WHERE c.Estado = 1
      AND (
            @filtro = '' OR
            p.Nombre   LIKE '%' + @filtro + '%' OR
            p.Apellido LIKE '%' + @filtro + '%' OR
            m.Nombre   LIKE '%' + @filtro + '%' OR
            m.Apellido LIKE '%' + @filtro + '%' OR
            c.Motivo   LIKE '%' + @filtro + '%'
          )
    ORDER BY c.Fecha DESC, c.HoraInicio DESC, c.IdCita DESC;
END
GO


CREATE OR ALTER PROCEDURE dbo.usp_citas_buscar
    @IdCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         c.IdCita,
        c.IdPaciente,
        p.DNI                   AS PacienteDNI,
		(p.Nombre + ' ' + p.Apellido) AS PacienteNombreCompleto,
        c.IdMedico,
        m.CMP                   AS MedicoCMP,
        (m.Nombre + ' ' + m.Apellido) AS MedicoNombreCompleto,
        c.Fecha,
        c.HoraInicio,
        c.HoraFin,
        c.IdEstadoCita,
        e.Nombre                AS NombreEstado,
        c.Motivo,
        c.Observaciones,
        c.Estado,
        c.FechaCreacion,
        c.FechaActualizacion,
        c.FechaBaja
    FROM dbo.Citas c
    JOIN dbo.Pacientes p ON p.IdPaciente = c.IdPaciente
    JOIN dbo.Medicos   m ON m.IdMedico   = c.IdMedico
    JOIN dbo.EstadosCita e ON e.IdEstadoCita = c.IdEstadoCita
    WHERE c.IdCita = @IdCita;
END
GO

/* =========================================================
   REGLA DE SOLAPE (utilizada en AGREGAR/ACTUALIZAR)
   Se considera solape cuando hay cita ACTIVA del mismo médico y fecha
   que cumple: @Inicio < HoraFin_existente  AND  @Fin > HoraInicio_existente
   ========================================================= */

/* =========================================================
   SP: AGREGAR CITA
   Códigos de retorno (RETURN):
      1  = OK
     -1  = Paciente no existe o está inactivo
     -2  = Médico no existe o está inactivo
     -3  = Estado de cita inválido
     -4  = Solape para el MÉDICO
     -5  = Solape para el PACIENTE (opcional, activado abajo)
   ========================================================= */


CREATE OR ALTER PROCEDURE dbo.usp_citas_agregar
    @IdPaciente     INT,
    @IdMedico       INT,
    @Fecha          DATE,
    @HoraInicio     TIME(0),
    @HoraFin        TIME(0) = NULL,        -- si NULL, se asumen 30 min
    @IdEstadoCita   INT = 1,               -- por defecto 'Programada'
    @Motivo         VARCHAR(200) = NULL,
    @Observaciones  VARCHAR(500) = NULL
AS
BEGIN
    /*
      RETURN codigos:
        1  = OK
       -1  = Paciente inválido o inactivo
       -2  = Médico inválido o inactivo
       -3  = Estado de cita inválido
       -4  = Conflicto: Solape con agenda del MÉDICO (en estados que bloquean)
       -5  = Conflicto: Solape con agenda del PACIENTE (en estados que bloquean)
       -6  = Rango de hora inválido (HoraFin <= HoraInicio)
    */
    -- Normalizar HoraFin (30 minutos por defecto)
    IF @HoraFin IS NULL
        SET @HoraFin = DATEADD(MINUTE, 30, @HoraInicio);

    -- Validar rango
    IF (@HoraFin <= @HoraInicio)
        RETURN -6;

    -- Validar Paciente activo
    IF NOT EXISTS (SELECT 1 FROM dbo.Pacientes WHERE IdPaciente=@IdPaciente AND Estado=1)
        RETURN -1;

    -- Validar Médico activo
    IF NOT EXISTS (SELECT 1 FROM dbo.Medicos WHERE IdMedico=@IdMedico AND Estado=1)
        RETURN -2;

    -- Validar Estado de cita
    IF NOT EXISTS (SELECT 1 FROM dbo.EstadosCita WHERE IdEstadoCita=@IdEstadoCita)
        RETURN -3;

    -- Solape MÉDICO (solo estados que BLOQUEAN agenda)
    IF EXISTS (
        SELECT 1
        FROM dbo.Citas c
        JOIN dbo.EstadosCita e ON e.IdEstadoCita = c.IdEstadoCita
        WHERE c.Estado       = 1
          AND e.BloqueaAgenda = 1
          AND c.IdMedico     = @IdMedico
          AND c.Fecha        = @Fecha
          AND @HoraInicio < ISNULL(c.HoraFin, DATEADD(MINUTE,30,c.HoraInicio))
          AND @HoraFin    >  c.HoraInicio
    )
        RETURN -4;

    -- Solape PACIENTE (solo estados que BLOQUEAN agenda)
    IF EXISTS (
        SELECT 1
        FROM dbo.Citas c
        JOIN dbo.EstadosCita e ON e.IdEstadoCita = c.IdEstadoCita
        WHERE c.Estado       = 1
          AND e.BloqueaAgenda = 1
          AND c.IdPaciente   = @IdPaciente
          AND c.Fecha        = @Fecha
          AND @HoraInicio < ISNULL(c.HoraFin, DATEADD(MINUTE,30,c.HoraInicio))
          AND @HoraFin    >  c.HoraInicio
    )
        RETURN -5;

    INSERT INTO dbo.Citas
        (IdPaciente, IdMedico, Fecha, HoraInicio, HoraFin, IdEstadoCita, Motivo, Observaciones)
    VALUES
        (@IdPaciente, @IdMedico, @Fecha, @HoraInicio, @HoraFin, @IdEstadoCita, @Motivo, @Observaciones);

    RETURN 1;
END
GO




/* =========================================================
   SP: ACTUALIZAR CITA
   Códigos de retorno (RETURN):
      1  = OK
     -1  = Paciente no existe o está inactivo
     -2  = Médico no existe o está inactivo
     -3  = Estado de cita inválido
     -4  = Solape para el MÉDICO
     -5  = Solape para el PACIENTE
    -99  = Cita inexistente o dada de baja
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.usp_citas_actualizar
    @IdCita        INT,
    @IdPaciente    INT,
    @IdMedico      INT,
    @Fecha         DATE,
    @HoraInicio    TIME(0),
    @HoraFin       TIME(0) = NULL,
    @IdEstadoCita  INT,
    @Motivo        VARCHAR(255) = NULL,
    @Observaciones VARCHAR(500) = NULL
AS
BEGIN
    /*
      RETURn codigos:
        1  = OK
       -1  = Cita inexistente o dada de baja
       -2  = Paciente inválido o inactivo
       -3  = Médico inválido o inactivo
       -4  = Rango de hora inválido (HoraFin <= HoraInicio)
       -5  = Conflicto: Solape con agenda del MÉDICO (excluye la misma cita; solo estados que bloquean)
       -6  = Conflicto: Solape con agenda del PACIENTE (excluye la misma cita; solo estados que bloquean)
       -7  = Estado de cita inválido
    */
    -- Normalizar HoraFin
    IF @HoraFin IS NULL
        SET @HoraFin = DATEADD(MINUTE, 30, @HoraInicio);

    -- Validar cita existente/activa
    IF NOT EXISTS (SELECT 1 FROM dbo.Citas WHERE IdCita=@IdCita AND Estado=1)
        RETURN -1;

    -- Validar Paciente y Médico activos
    IF NOT EXISTS (SELECT 1 FROM dbo.Pacientes WHERE IdPaciente=@IdPaciente AND Estado=1) RETURN -2;
    IF NOT EXISTS (SELECT 1 FROM dbo.Medicos   WHERE IdMedico  =@IdMedico   AND Estado=1) RETURN -3;

    -- Validar Estado de cita
    IF NOT EXISTS (SELECT 1 FROM dbo.EstadosCita WHERE IdEstadoCita=@IdEstadoCita)
        RETURN -7;

    -- Validar rango
    IF (@HoraFin <= @HoraInicio)
        RETURN -4;

    -- Solape MÉDICO (excluye misma cita; solo estados que BLOQUEAN agenda)
    IF EXISTS (
        SELECT 1
        FROM dbo.Citas c
        JOIN dbo.EstadosCita e ON e.IdEstadoCita = c.IdEstadoCita
        WHERE c.Estado        = 1
          AND e.BloqueaAgenda = 1
          AND c.IdMedico      = @IdMedico
          AND c.Fecha         = @Fecha
          AND c.IdCita       <> @IdCita
          AND @HoraInicio < ISNULL(c.HoraFin, DATEADD(MINUTE,30,c.HoraInicio))
          AND @HoraFin    >  c.HoraInicio
    )
        RETURN -5;

    -- Solape PACIENTE (excluye misma cita; solo estados que BLOQUEAN agenda)
    IF EXISTS (
        SELECT 1
        FROM dbo.Citas c
        JOIN dbo.EstadosCita e ON e.IdEstadoCita = c.IdEstadoCita
        WHERE c.Estado        = 1
          AND e.BloqueaAgenda = 1
          AND c.IdPaciente    = @IdPaciente
          AND c.Fecha         = @Fecha
          AND c.IdCita       <> @IdCita
          AND @HoraInicio < ISNULL(c.HoraFin, DATEADD(MINUTE,30,c.HoraInicio))
          AND @HoraFin    >  c.HoraInicio
    )
        RETURN -6;

    -- Actualizar
    UPDATE dbo.Citas
       SET IdPaciente         = @IdPaciente,
           IdMedico           = @IdMedico,
           Fecha              = @Fecha,
           HoraInicio         = @HoraInicio,
           HoraFin            = @HoraFin,
           IdEstadoCita       = @IdEstadoCita,
           Motivo             = @Motivo,
           Observaciones      = @Observaciones,
           FechaActualizacion = GETDATE()
     WHERE IdCita = @IdCita;

    RETURN 1;
END
GO




/* =========================================================
   SP: ELIMINAR (BAJA LÓGICA)
   Códigos de retorno (RETURN):
      1  = OK
    -99  = Cita inexistente o ya dada de baja
  ========================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_citas_eliminar
    @IdCita INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Citas WHERE IdCita=@IdCita AND Estado=1)
        RETURN -99;

    UPDATE dbo.Citas
    SET Estado=0, FechaBaja=GETDATE()
    WHERE IdCita = @IdCita;

    RETURN 1;
END
GO


CREATE OR ALTER PROCEDURE dbo.usp_citas_contar
AS
BEGIN
    SELECT COUNT(*) FROM dbo.Citas WHERE Estado = 1;
END
GO

-- Catálogo de estados de cita (solo lectura para combos)
-- Ajusta el WHERE si tu tabla no tiene columna Estado (BIT)
CREATE OR ALTER PROCEDURE dbo.usp_estadoscita_listar
AS
BEGIN
    SELECT  IdEstadoCita,
            Nombre
    FROM    dbo.EstadosCita
    ORDER BY Nombre;
END
GO



/*
DELETE FROM dbo.Citas;
DELETE FROM dbo.Pacientes;
DELETE FROM dbo.Medicos;
DELETE FROM dbo.Usuarios;
DELETE FROM dbo.Especialidades;
*/


-- ----------------------------------------------------------------------------------------
/*SCRIPT SOBRE BAJAS  */

-- MEDICO DE BAJAS

/* LISTAR MEDICOS QUE FUERON DADOS DE BAJA */
CREATE OR ALTER PROC usp_listar_medicos_baja
    @filtro VARCHAR(150) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.IdMedico, m.CMP, m.Nombre,m.Apellido, e.Nombre AS 'Especialidad', m.Telefono, m.Correo, m.FechaBaja
    FROM medicos m 
    JOIN Especialidades e
    ON m.IdEspecialidad=e.IdEspecialidad
    WHERE  m.Estado = 0 
     AND (
                M.CMP COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%' 
                OR M.Nombre COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%' 
                OR M.Apellido COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%'
                OR E.Nombre COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%'
            );
END;
GO

/* RESTAURAR MEDICOS QUE FUERON DADOS DE BAJA */
 CREATE OR ALTER PROC usp_restaurar_medico
@IdMedico INT  
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Medicos WHERE IdMedico = @IdMedico AND Estado = 0)
    BEGIN
        UPDATE medicos
        set 
        Estado = 1,
        FechaBaja = NULL,
        FechaActualizacion = GETDATE()
        where IdMedico = @IdMedico

        RETURN 0; --exitoso
    END

    ELSE 
    BEGIN
      RETURN -1; -- medico no existe o ya esta activo
    END

END;
Go

/* BUSCAR POR ID MEDICOS QUE FUERON DADOS DE BAJA */
CREATE OR ALTER PROCEDURE usp_medicos_baja_buscar_por_id
@IDMedico INT
AS
BEGIN
    SET NOCOUNT ON

    SELECT m.IdMedico, m.CMP, m.Nombre,m.Apellido, e.Nombre AS 'Especialidad', 
            m.Telefono, m.Correo, m.FechaBaja
    FROM medicos m 
    JOIN Especialidades e
    ON m.IdEspecialidad=e.IdEspecialidad
    WHERE m.IdMedico = @IDMedico AND m.Estado = 0;
END
GO

CREATE INDEX IX_Medicos_Estado_Inactivo 
ON Medicos(IdMedico) 
WHERE Estado = 0;
GO

/* EJECUCION DE PROCEDURE DE MEDICOS QUE FUERON DADOS DE BAJA */
/*
exec dbo.usp_medicos_eliminar 15
go

exec usp_medicos
go

exec usp_listar_medicos_baja
go

exec usp_medicos_baja_buscar_por_id 15
go

exec usp_restaurar_medico 15
go
*/

-- PACIENTE DE BAJAS

/* LISTAR PACIENTES QUE FUERON DADOS DE BAJA */
CREATE OR ALTER PROC usp_listar_pacientes_baja
    @filtro VARCHAR(150) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.IdPaciente, p.DNI, p.Nombre, p.Apellido, p.FechaNacimiento, p.Genero, 
           p.Telefono, p.Correo, p.Direccion, p.FechaBaja
    FROM dbo.Pacientes p
    WHERE p.Estado = 0
     AND (
                p.DNI COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%' 
                OR p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%' 
                OR p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%' + @filtro + '%'
             );
END;
GO

/* RESTAURAR PACIENTES QUE FUERON DADOS DE BAJA */
CREATE OR ALTER PROC usp_restaurar_paciente
@IdPaciente INT  
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 
                FROM Pacientes p 
                WHERE p.IdPaciente = @IdPaciente AND p.Estado = 0
                )
    BEGIN
        UPDATE Pacientes 
        set 
        Estado = 1,
        FechaBaja = NULL,
        FechaActualizacion = GETDATE()
        where IdPaciente = @IdPaciente

        RETURN 0; -- exitoso
    END

    ELSE 
    BEGIN
      RETURN -1; -- paciente no existe o ya esta activo
    END

END;
Go

/* BUSCAR POR ID PACIENTE QUE FUERON DADOS DE BAJA */
CREATE OR ALTER PROCEDURE usp_paciente_baja_buscar_por_id
@IdPaciente INT
AS
BEGIN
    SET NOCOUNT ON

    SELECT p.IdPaciente, p.DNI, p.Nombre, p.Apellido, p.FechaNacimiento, p.Genero, 
           p.Telefono, p.Correo, p.Direccion, p.FechaBaja
    FROM Pacientes p
    WHERE p.IdPaciente = @IdPaciente AND p.Estado = 0;

END
GO

CREATE INDEX IX_Pacientes_Estado_Inactivo 
ON Pacientes (IdPaciente) 
WHERE Estado = 0;
GO

/* EJECUCION DE PROCEDURE DE MEDICOS QUE FUERON DADOS DE BAJA */
/*exec usp_pacientes
go

exec usp_pacientes_eliminar 13
go

exec usp_listar_pacientes_baja
go

exec usp_paciente_baja_buscar_por_id 15
go

exec usp_restaurar_paciente 'RETURN_VALUE'
go
*/

 