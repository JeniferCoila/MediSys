ALTER DATABASE CitasMedicasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
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
    SELECT  IdPaciente,
			DNI,
			Nombre,
			Apellido,
			FechaNacimiento,
			Genero,
			Telefono,
			Correo,
			Direccion,
			FechaCreacion,        
			FechaActualizacion,   
			FechaBaja             
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


INSERT INTO Pacientes
  (DNI, Nombre, Apellido, FechaNacimiento, Genero, Telefono, Correo, Direccion, Estado,
   FechaCreacion, FechaActualizacion, FechaBaja)
VALUES
-- MARZO 2025 (7) – 2 bajas
('33445566','David','Cohen','1980-05-12','M','987654321','david.cohen@example.com','Calle Jerusalén 101',1,'2025-03-04 09:15:00','2025-03-18 16:30:00',NULL),
('44556677','Sara','Levy','1992-07-08','F','988765432','sara.levy@example.com','Av. Israel 202',1,'2025-03-09 10:05:00','2025-03-27 18:20:00',NULL),
('55667788','Yaakov','Goldstein','1975-03-19','M','989876543','yaakov.goldstein@example.com','Jr. Sion 303',0,'2025-03-12 08:45:00','2025-03-20 14:10:00','2025-03-28 09:30:00'),
('66778899','Miriam','Katz','1988-11-25','F','990987654','miriam.katz@example.com','Calle Moriah 404',1,'2025-03-15 11:32:00','2025-03-24 17:05:00',NULL),
('77889900','Eli','Rosenberg','1995-09-15','M','991098765','eli.rosenberg@example.com','Av. Shalom 505',1,'2025-03-21 09:00:00','2025-03-29 12:40:00',NULL),
('88990011','Hannah','Weiss','1983-12-02','F','992109876','hannah.weiss@example.com','Jr. Canaán 606',0,'2025-03-23 15:25:00','2025-03-28 19:10:00','2025-03-30 10:05:00'),
('99001122','Isaac','Kaplan','1979-08-22','M','993210987','isaac.kaplan@example.com','Calle Sinaí 707',1,'2025-03-27 08:20:00','2025-03-31 16:45:00',NULL),

-- ABRIL 2025 (7) – 2 bajas
('12345678','Rachel','Friedman','1990-04-10','F','994321098','rachel.friedman@example.com','Av. Galilea 808',1,'2025-04-02 09:10:00','2025-04-15 17:30:00',NULL),
('23456789','Daniel','Adler','1987-06-30','M','995432109','daniel.adler@example.com','Jr. Negev 909',0,'2025-04-06 11:05:00','2025-04-21 18:00:00','2025-04-28 10:25:00'),
('34567890','Leah','Horowitz','1993-01-18','F','996543210','leah.horowitz@example.com','Calle Carmel 111',1,'2025-04-09 14:40:00','2025-04-25 16:50:00',NULL),
('45678901','Benjamin','Shapiro','1976-10-05','M','997654321','benjamin.shapiro@example.com','Av. Monte 222',1,'2025-04-12 08:55:00','2025-04-20 13:35:00',NULL),
('56789012','Esther','Stein','1989-03-28','F','998765432','esther.stein@example.com','Jr. Betel 333',0,'2025-04-18 10:22:00','2025-04-27 19:15:00','2025-04-30 09:45:00'),
('67890123','Shlomo','Peretz','1984-07-14','M','999876543','shlomo.peretz@example.com','Calle Tabor 444',1,'2025-04-22 09:05:00','2025-04-29 15:10:00',NULL),
('78901234','Naomi','Greenberg','1991-11-07','F','900987654','naomi.greenberg@example.com','Av. Keren 555',1,'2025-04-27 16:18:00','2025-04-30 18:40:00',NULL),

-- MAYO 2025 (7) – 2 bajas
('89012345','Yonatan','Leibowitz','1978-09-21','M','901098765','yonatan.leibowitz@example.com','Jr. Aravá 666',1,'2025-05-02 09:45:00','2025-05-19 16:25:00',NULL),
('90123456','Deborah','Goren','1994-05-16','F','902109876','deborah.goren@example.com','Calle Kidron 777',0,'2025-05-05 10:30:00','2025-05-22 18:05:00','2025-05-27 11:35:00'),
('11223344','Moshe','Mizrahi','1981-02-12','M','903210987','moshe.mizrahi@example.com','Av. Zion 888',1,'2025-05-08 08:50:00','2025-05-18 12:15:00',NULL),
('22334455','Judith','Edelman','1992-08-03','F','904321098','judith.edelman@example.com','Jr. Hebrón 999',1,'2025-05-12 11:20:00','2025-05-26 17:55:00',NULL),
('33445577','Samuel','Schwartz','1977-12-09','M','905432109','samuel.schwartz@example.com','Calle Gilboa 121',0,'2025-05-16 09:35:00','2025-05-28 15:05:00','2025-05-31 10:10:00'),
('44556688','Ruth','Bernstein','1986-06-25','F','906543210','ruth.bernstein@example.com','Av. Tiberias 232',1,'2025-05-21 13:10:00','2025-05-29 18:45:00',NULL),
('55667799','Ariel','Carmi','1990-09-13','M','907654321','ariel.carmi@example.com','Jr. Neot 343',1,'2025-05-27 08:05:00','2025-05-30 12:40:00',NULL),

-- JUNIO 2025 (7) – 2 bajas
('66778800','Tamar','Zilberman','1985-04-04','F','908765432','tamar.zilberman@example.com','Calle Yehuda 454',1,'2025-06-03 10:15:00','2025-06-20 16:30:00',NULL),
('77889911','Yosef','Grossman','1982-07-28','M','909876543','yosef.grossman@example.com','Av. Carmel 565',0,'2025-06-07 09:25:00','2025-06-22 14:20:00','2025-06-27 09:50:00'),
('88990022','Rebecca','Dahan','1993-10-19','F','910987654','rebecca.dahan@example.com','Jr. Shira 676',1,'2025-06-10 11:05:00','2025-06-24 17:05:00',NULL),
('99001133','Efraim','Halpern','1974-03-06','M','911098765','efraim.halpern@example.com','Calle Kedem 787',1,'2025-06-14 08:40:00','2025-06-26 16:10:00',NULL),
('12344321','Levana','Amiel','1988-01-29','F','912109876','levana.amiel@example.com','Av. Hermón 898',0,'2025-06-18 12:55:00','2025-06-29 18:35:00','2025-06-30 10:05:00'),
('23455432','Gideon','Yosefi','1991-09-09','M','913210987','gideon.yosefi@example.com','Jr. Migdal 909',1,'2025-06-22 09:50:00','2025-06-28 15:30:00',NULL),
('34566543','Shira','Melamed','1987-12-18','F','914321098','shira.melamed@example.com','Calle Haifa 111',1,'2025-06-26 10:12:00','2025-06-30 19:00:00',NULL),

-- JULIO 2025 (6) – 2 bajas
('45677654','Noam','Barak','1995-06-24','M','915432109','noam.barak@example.com','Av. Moriah 222',1,'2025-07-03 10:05:00','2025-07-18 16:25:00',NULL),
('56788765','Dina','Shohat','1989-02-14','F','916543210','dina.shohat@example.com','Jr. Tikva 333',0,'2025-07-07 11:40:00','2025-07-22 18:15:00','2025-07-29 09:20:00'),
('67899876','Avraham','Tal','1976-10-11','M','917654321','avraham.tal@example.com','Calle Sharon 444',1,'2025-07-12 09:00:00','2025-07-25 13:45:00',NULL),
('78900987','Orit','Neeman','1984-07-07','F','918765432','orit.neeman@example.com','Av. Carmel 555',1,'2025-07-19 15:10:00','2025-07-28 17:50:00',NULL),
('89011098','Eliyahu','Rimon','1979-09-30','M','919876543','eliyahu.rimon@example.com','Jr. Golan 666',0,'2025-07-23 08:35:00','2025-07-30 12:05:00','2025-07-31 10:30:00'),
('90122109','Batya','Armoni','1992-03-05','F','920987654','batya.armoni@example.com','Calle Jordan 777',1,'2025-07-27 11:20:00','2025-07-30 18:10:00',NULL),

-- AGOSTO 2025 (6) – 2 bajas
('11233220','Yitzhak','Dror','1983-12-01','M','921098765','yitzhak.dror@example.com','Av. Sharon 888',1,'2025-08-02 09:15:00','2025-08-15 16:40:00',NULL),
('22344331','Hadassah','Luria','1987-08-16','F','922109876','hadassah.luria@example.com','Jr. Efrat 999',0,'2025-08-06 10:55:00','2025-08-20 18:25:00','2025-08-26 09:45:00'),
('33455442','Natan','Peled','1990-05-20','M','923210987','natan.peled@example.com','Calle Sorek 121',1,'2025-08-10 08:25:00','2025-08-22 14:30:00',NULL),
('44566553','Ziva','Baruch','1993-11-11','F','924321098','ziva.baruch@example.com','Av. Yehuda 232',1,'2025-08-14 11:45:00','2025-08-24 17:05:00',NULL),
('55677664','Oren','Dayan','1981-04-22','M','925432109','oren.dayan@example.com','Jr. Netanya 343',0,'2025-08-19 09:35:00','2025-08-27 12:55:00','2025-08-30 10:15:00'),
('66788775','Malka','Ashkenazi','1985-06-06','F','926543210','malka.ashkenazi@example.com','Calle Carmel 454',1,'2025-08-24 10:10:00','2025-08-29 18:20:00',NULL);

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
			m.FotoUrl,
			m.FechaCreacion,        -- NUEVO
			m.FechaActualizacion,   -- NUEVO
			m.FechaBaja             -- NUEVO
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

INSERT INTO Medicos
(CMP, Nombre, Apellido, IdEspecialidad, Telefono, Correo, Estado, FechaCreacion, FechaActualizacion, FechaBaja, FotoUrl)
VALUES
-- Especialidades 1–20 (mínimo 1 c/u)
('CMP101','Eitan','Levy',1,'987111001','eitan.levy@medisys.com',1,'2025-05-03 09:10:00','2025-05-18 16:20:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP102','Yael','Cohen',2,'987111002','yael.cohen@medisys.com',1,'2025-05-05 10:05:00','2025-05-22 17:45:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP103','Ariel','Mizrahi',3,'987111003','ariel.mizrahi@medisys.com',0,'2025-05-07 08:40:00','2025-06-15 12:30:00','2025-07-10 10:00:00','/uploads/medicos/male-medico.png'),
('CMP104','Noa','Ben-David',4,'987111004','noa.bendavid@medisys.com',1,'2025-05-09 11:20:00','2025-05-26 18:05:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP105','Nadav','Katz',5,'987111005','nadav.katz@medisys.com',1,'2025-05-10 09:00:00','2025-05-27 16:10:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP106','Tamar','Azoulay',6,'987111006','tamar.azoulay@medisys.com',1,'2025-05-12 10:15:00','2025-05-28 17:25:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP107','Lior','Baruch',7,'987111007','lior.baruch@medisys.com',0,'2025-05-13 08:55:00','2025-07-30 11:40:00','2025-08-18 09:30:00','/uploads/medicos/male-medico.png'),
('CMP108','Shira','Gabbay',8,'987111008','shira.gabbay@medisys.com',1,'2025-05-14 14:05:00','2025-05-29 19:10:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP109','Yonatan','Dayan',9,'987111009','yonatan.dayan@medisys.com',1,'2025-05-16 09:45:00','2025-06-02 15:20:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP110','Michal','Halevi',10,'987111010','michal.halevi@medisys.com',1,'2025-05-17 08:30:00','2025-06-01 11:50:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP111','Itai','Shalev',11,'987111011','itai.shalev@medisys.com',1,'2025-05-18 10:40:00','2025-05-30 16:55:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP112','Rivka','Zohar',12,'987111012','rivka.zohar@medisys.com',0,'2025-05-19 09:25:00','2025-06-18 13:35:00','2025-06-22 11:00:00','/uploads/medicos/female-medico.png'),
('CMP113','Omer','Avraham',13,'987111013','omer.avraham@medisys.com',1,'2025-05-20 11:05:00','2025-06-05 12:30:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP114','Gal','Peretz',14,'987111014','gal.peretz@medisys.com',1,'2025-05-22 09:15:00','2025-06-07 18:00:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP115','Leah','Bar-On',15,'987111015','leah.baron@medisys.com',0,'2025-05-23 10:55:00','2025-07-22 17:20:00','2025-08-05 14:15:00','/uploads/medicos/female-medico.png'),
('CMP116','Amir','Goldstein',16,'987111016','amir.goldstein@medisys.com',1,'2025-05-24 08:45:00','2025-06-10 16:35:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP117','Maya','Yehuda',17,'987111017','maya.yehuda@medisys.com',1,'2025-05-25 09:20:00','2025-06-12 15:40:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP118','Ziv','Hadad',18,'987111018','ziv.hadad@medisys.com',0,'2025-05-26 10:00:00','2025-07-15 12:10:00','2025-07-25 16:20:00','/uploads/medicos/male-medico.png'),
('CMP119','Dana','Malka',19,'987111019','dana.malka@medisys.com',0,'2025-05-27 08:50:00','2025-06-25 17:45:00','2025-06-30 09:45:00','/uploads/medicos/female-medico.png'),
('CMP120','Noam','Biton',20,'987111020','noam.biton@medisys.com',1,'2025-05-28 09:35:00','2025-06-18 18:25:00',NULL,'/uploads/medicos/male-medico.png'),

-- 5 extras en especialidades comunes (1–5) con nombres latinos
('CMP133','Carlos','Herrera',1,'987131001','carlos.herrera@medisys.com',1,'2025-06-03 09:20:00','2025-06-18 16:30:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP134','Valentina','Rojas',2,'987131002','valentina.rojas@medisys.com',1,'2025-06-06 10:05:00','2025-06-22 18:10:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP135','José','Ramírez',3,'987131003','jose.ramirez@medisys.com',1,'2025-06-09 08:50:00','2025-06-25 15:40:00',NULL,'/uploads/medicos/male-medico.png'),
('CMP136','Camila','Fernández',4,'987131004','camila.fernandez@medisys.com',1,'2025-06-12 11:15:00','2025-06-28 17:25:00',NULL,'/uploads/medicos/female-medico.png'),
('CMP137','Luis','García',5,'987131005','luis.garcia@medisys.com',1,'2025-06-15 09:05:00','2025-06-30 12:55:00',NULL,'/uploads/medicos/male-medico.png');
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

    SELECT m.IdMedico, m.CMP, m.Nombre,m.Apellido, e.Nombre AS 'Especialidad', m.Telefono, m.Correo, m.FotoUrl,                                   -- <== necesario para avatar
      m.FechaCreacion,                            
      m.FechaActualizacion,
      m.FechaBaja                                   
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

-- Datos de ejemplo: Citas en las últimas 8 semanas (hoy: 2025-08-30)
-- IdEstadoCita: 1=Programada, 2=Atendida, 3=Cancelada, 4=No asistió

INSERT INTO dbo.Citas (IdPaciente, IdMedico, Fecha, HoraInicio, HoraFin, IdEstadoCita, Motivo, Observaciones) VALUES
-- Semana 8 (2025-07-05 a 2025-07-11)
(1, 1, '2025-07-05', '09:00', '09:30', 2, 'Control general',         'Consulta sin novedades'),
(2, 2, '2025-07-07', '10:00', '10:30', 3, 'Rinitis alérgica',        'Cancelada por paciente'),
(3, 3, '2025-07-09', '11:00', '11:30', 2, 'Dermatitis',              'Tratamiento tópico'),
(4, 4, '2025-07-11', '15:00', '15:30', 4, 'Cefalea',                 'No asistió'),

-- Semana 7 (2025-07-12 a 2025-07-18)
(5, 5, '2025-07-12', '09:30', '10:00', 2, 'Gastritis',               'Dieta indicada'),
(6, 6, '2025-07-14', '10:30', '11:00', 2, 'Dolor lumbar',            'Ejercicios sugeridos'),
(7, 7, '2025-07-16', '16:00', '16:30', 3, 'Conjuntivitis',           'Cancelada por médico'),
(8, 8, '2025-07-18', '08:30', '09:00', 4, 'Otalgia',                 'Ausencia sin aviso'),

-- Semana 6 (2025-07-19 a 2025-07-25)
(9, 1, '2025-07-19', '09:00', '09:30', 2, 'Chequeo anual',           'Exámenes solicitados'),
(10,2, '2025-07-21', '10:00', '10:30', 2, 'Reflujo',                 'Plan de alimentación'),
(11,3, '2025-07-23', '11:30', '12:00', 3, 'Migraña',                 'Reprogramación solicitada'),
(12,4, '2025-07-25', '14:00', '14:30', 4, 'Lumbalgia',               'No llegó a tiempo'),

-- Semana 5 (2025-07-26 a 2025-08-01)
(13,5, '2025-07-26', '09:00', '09:30', 2, 'Control pediátrico',      'Crecimiento ok'),
(14,6, '2025-07-28', '10:30', '11:00', 2, 'Rinitis',                 'Antihistamínico'),
(15,7, '2025-07-30', '12:00', '12:30', 3, 'Irritación ocular',       'Cancelada por teletrabajo'),
(16,8, '2025-08-01', '15:30', '16:00', 4, 'Dolor abdominal',         'No asistió'),

-- Semana 4 (2025-08-02 a 2025-08-08)
(1, 1, '2025-08-02', '09:00', '09:30', 2, 'Control cardiología',     'ECG normal'),
(2, 2, '2025-08-04', '10:00', '10:30', 2, 'Dermatitis de contacto',  'Mejora visible'),
(3, 3, '2025-08-06', '11:00', '11:30', 3, 'Trauma rodilla',          'Cancelada (lluvia)'),
(4, 4, '2025-08-08', '16:00', '16:30', 4, 'Otitis',                  'Ausencia del paciente'),

-- Semana 3 (2025-08-09 a 2025-08-15)
(5, 5, '2025-08-09', '09:30', '10:00', 2, 'Cefalea tensional',       'Higiene del sueño'),
(6, 6, '2025-08-11', '10:30', '11:00', 2, 'Chequeo rutina',          'Resultado favorable'),
(7, 7, '2025-08-13', '12:30', '13:00', 3, 'Gastroenteritis',         'Cancelada por paciente'),
(8, 8, '2025-08-15', '15:00', '15:30', 4, 'Ojo rojo',                'No asistió'),

-- Semana 2 (2025-08-16 a 2025-08-22)
(9, 1, '2025-08-16', '09:00', '09:30', 2, 'Seguimiento endocrino',   'TSH estable'),
(10,2, '2025-08-18', '10:00', '10:30', 2, 'Dolor cervical',          'Fisioterapia'),
(11,3, '2025-08-20', '11:00', '11:30', 3, 'Lesión cutánea',          'Reprogramada'),
(12,4, '2025-08-22', '16:00', '16:30', 4, 'Rinitis',                 'Ausencia sin aviso'),

-- Semana 1 (2025-08-23 a 2025-08-30)
(13,5, '2025-08-24', '09:00', '09:30', 2, 'Control general',         'Consulta resuelta'),
(14,6, '2025-08-26', '10:00', '10:30', 2, 'Dolor lumbar',            'Ejercicios indicados'),
(15,7, '2025-08-28', '11:00', '11:30', 3, 'Rinitis alérgica',        'Cancelada por paciente'),
(16,8, '2025-08-30', '15:00', '15:30', 1, 'Chequeo pre-viaje',       'Programada hoy');
GO

INSERT INTO Pacientes
  (DNI, Nombre, Apellido, FechaNacimiento, Genero, Telefono, Correo, Direccion, Estado,
   FechaCreacion, FechaActualizacion, FechaBaja)
VALUES
-- ENERO (3)
('98210001','Mateo','Luna','1987-02-17','M','932200001','mateo.luna01@example.com','Av. Primavera 101',1,'2025-01-07 10:14:00','2025-01-22 16:45:00',NULL),
('98210002','Diana','Huerta','1990-01-26','F','932200002','diana.huerta02@example.com','Jr. Los Sauces 202',1,'2025-01-13 08:32:00','2025-01-30 18:10:00',NULL),
('98210003','Lucía','Flores','1987-01-29','F','932200003','lucia.flores03@example.com','Calle Arboleda 303',1,'2025-01-25 09:05:00','2025-01-27 12:40:00',NULL),

-- FEBRERO (2)
('98210004','Valentina','Prado','1993-10-12','F','932200004','valentina.prado04@example.com','Av. Los Héroes 404',1,'2025-02-06 11:20:00','2025-02-18 17:35:00',NULL),
('98210005','Jimena','Paredes','1996-11-05','F','932200005','jimena.paredes05@example.com','Jr. El Parque 505',0,'2025-02-12 10:10:00','2025-02-20 15:22:00','2025-02-25 09:30:00'),

-- MARZO (5)
('98210006','Tomás','Salcedo','1979-03-22','M','932200006','tomas.salcedo06@example.com','Av. Miguel Grau 606',0,'2025-03-05 08:55:00','2025-03-20 16:05:00','2025-03-26 10:00:00'),
('98210007','Álvaro','Rivas','1983-04-14','M','932200007','alvaro.rivas07@example.com','Calle Los Tulipanes 707',1,'2025-03-09 13:40:00','2025-03-25 19:10:00',NULL),
('98210008','Sofía','León','1991-03-19','F','932200008','sofia.leon08@example.com','Av. Libertad 808',0,'2025-03-15 09:25:00','2025-03-22 14:55:00','2025-03-31 11:15:00'),
('98210009','Renato','Campos','1986-02-03','M','932200009','renato.campos09@example.com','Jr. Central 909',1,'2025-03-20 10:18:00','2025-03-28 16:48:00',NULL),
('98210010','Paola','Quintana','1988-09-25','F','932200010','paola.quintana10@example.com','Pasaje Las Flores 010',1,'2025-03-27 08:05:00','2025-03-30 13:22:00',NULL),

-- ABRIL (4)
('98210011','Carlos','Mena','1985-07-18','M','932200011','carlos.mena11@example.com','Av. Arequipa 111',1,'2025-04-04 10:00:00','2025-04-18 17:30:00',NULL),
('98210012','Andrea','Vargas','1994-05-07','F','932200012','andrea.vargas12@example.com','Jr. Amazonas 212',1,'2025-04-10 09:35:00','2025-04-27 18:20:00',NULL),
('98210013','César','Ordoñez','1983-09-19','M','932200013','cesar.ordonez13@example.com','Calle Los Cedros 313',1,'2025-04-16 14:12:00','2025-04-29 19:05:00',NULL),
('98210014','Belén','Salazar','1996-04-27','F','932200014','belen.salazar14@example.com','Av. La Marina 414',1,'2025-04-28 08:45:00','2025-04-30 12:18:00',NULL),

-- MAYO (4)
('98210015','Gonzalo','Reyes','1984-09-09','M','932200015','gonzalo.reyes15@example.com','Av. Cusco 515',0,'2025-05-03 09:28:00','2025-05-21 16:04:00','2025-05-24 10:50:00'),
('98210016','Mónica','Salazar','1992-06-02','F','932200016','monica.salazar16@example.com','Jr. Moquegua 616',1,'2025-05-09 11:42:00','2025-05-29 17:11:00',NULL),
('98210017','Alan','Campos','1978-03-13','M','932200017','alan.campos17@example.com','Calle Lima 717',0,'2025-05-14 08:20:00','2025-05-26 15:40:00','2025-05-27 09:35:00'),
('98210018','Mariana','Castillo','1985-10-08','F','932200018','mariana.castillo18@example.com','Av. Progreso 818',0,'2025-05-20 10:55:00','2025-05-28 18:30:00','2025-05-29 08:10:00'),

-- JUNIO (5)
('98210019','Elena','Paredes','1986-06-17','F','932200019','elena.paredes19@example.com','Av. Tacna 919',1,'2025-06-02 09:10:00','2025-06-19 16:15:00',NULL),
('98210020','Diego','Cornejo','1989-12-28','M','932200020','diego.cornejo20@example.com','Jr. Ica 020',1,'2025-06-07 08:58:00','2025-06-21 14:40:00',NULL),
('98210021','Camila','Torres','1995-06-16','F','932200021','camila.torres21@example.com','Calle Piura 121',1,'2025-06-12 11:30:00','2025-06-26 18:10:00',NULL),
('98210022','Jorge','Medina','1977-12-02','M','932200022','jorge.medina22@example.com','Av. Bolognesi 222',1,'2025-06-18 10:05:00','2025-06-29 19:00:00',NULL),
('98210023','Laura','Hidalgo','1992-12-15','F','932200023','laura.hidalgo23@example.com','Jr. Bolívar 323',0,'2025-06-24 09:25:00','2025-06-30 11:55:00','2025-06-30 16:10:00'),

-- JULIO (4)
('98210024','Sebastián','Cruz','1984-08-03','M','932200024','sebastian.cruz24@example.com','Av. Junín 424',1,'2025-07-03 10:44:00','2025-07-18 16:40:00',NULL),
('98210025','Nicole','Cabrera','1992-08-09','F','932200025','nicole.cabrera25@example.com','Jr. Ayacucho 525',1,'2025-07-09 09:35:00','2025-07-22 15:20:00',NULL),
('98210026','Diego','Soto','1983-03-05','M','932200026','diego.soto26@example.com','Calle Cajamarca 626',0,'2025-07-15 11:12:00','2025-07-28 17:05:00','2025-07-29 09:15:00'),
('98210027','Ana','Velarde','1989-06-24','F','932200027','ana.velarde27@example.com','Av. Miraflores 727',1,'2025-07-23 08:30:00','2025-07-30 18:15:00',NULL),

-- AGOSTO (3)
('98210028','Gabriel','Molina','1990-07-13','M','932200028','gabriel.molina28@example.com','Calle Ancash 828',1,'2025-08-04 10:45:00','2025-08-18 16:25:00',NULL),
('98210029','Carla','Espinoza','1993-02-21','F','932200029','carla.espinoza29@example.com','Av. Los Olivos 929',0,'2025-08-10 09:20:00','2025-08-20 14:50:00','2025-08-26 09:40:00'),
('98210030','Mauricio','Palacios','1981-09-09','M','932200030','mauricio.palacios30@example.com','Jr. Cuzco 030',1,'2025-08-22 11:15:00','2025-08-29 18:35:00',NULL);
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

 