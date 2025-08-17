# Medisys
_Plataforma web para gestión de pacientes y citas médicas en ASP.NET Core MVC (.NET 8)._

> Este README parte del proyecto **AplicacionCitasMedicasDB** y lo orienta a la marca **Medisys**. Señalo lo **implementado hoy** y la **lógica de negocio propuesta** para evolucionar a un sistema de citas completo.

---

## 🧩 Stack
- .NET 8 / ASP.NET Core MVC (Razor)
- C# + ADO.NET (sin Entity Framework)
- SQL Server (script: `BDCitasMedicas.sql`)
- Bootstrap

---

## ⚙️ Instalación rápida
1) **Base de datos**  
   - Abrir **SSMS** y ejecutar `BDCitasMedicas.sql`.  
   - El script crea la BD **`CitasMedicasDB`** e inserta roles/usuarios de ejemplo.

2) **Cadena de conexión**  
   Edita `appsettings.json`:
   ```json
   "ConnectionStrings": {
     "cadena": "Server=TU_SERVIDOR;Database=CitasMedicasDB;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;MultipleActiveResultSets=True"
   }
   ```
   > El código usa **`ConnectionStrings.cadena`**.

3) **Ejecutar**
   ```bash
   dotnet restore
   dotnet build
   dotnet run
   ```
   Navega a `https://localhost:5001` o `http://localhost:5000`.

---

## 📦 Estructura (actual)
```
Controllers/
  AdminController.cs
  HomeController.cs
  LoginController.cs
  MedicoController.cs
  PacienteController.cs

Models/
  Paciente.cs
  Usuario.cs
  ErrorViewModel.cs

Repositorio/
  IPaciente.cs / PacienteDAO.cs
  IUsuario.cs  / UsuarioDAO.cs

Views/
  Admin/   Home/   Login/   Medico/   Paciente/   Shared/
(_Layout.cshtml, _PagerWithTotal.cshtml, Error.cshtml)

appsettings.json
Program.cs
```
**Implementado:** Autenticación básica + CRUD de Pacientes (listado paginado, crear, editar, detalle).  
**Pendiente/Propuesto:** Citas, Agendas de médicos, Reportes, Auditoría ampliada.

---

## 🔐 Credenciales de ejemplo (del script)
| Usuario     | Contraseña   | Rol            |
|-------------|--------------|----------------|
| `admin`     | `admin123`   | Administrador  |
| `medico1`   | `medico123`  | Médico         |
| `paciente1` | `paciente123`| Paciente       |

> El script también contiene inserciones con `HASHBYTES('SHA2_256', ...)`. Si usas hash, ajusta la validación de login para comparar el hash en DB.

---

## 🧠 Lógica de negocio — **Medisys**
### Núcleo propuesto
1. **Agendas por médico**
   - Horarios configurables por día/especialidad.
   - Bloqueos (feriados, licencias, congresos).
   - Regla: no se aceptan turnos fuera de rango ni solapamientos.

2. **Citas**
   - Slot configurable (15/20/30 min).
   - Sugerencia automática de la **mejor siguiente disponibilidad** según preferencia de paciente.
   - Reglas de reprogramación (n cambios máx.) y ventana mínima (p.ej., 2 h antes).
   - **No-show**: marcar inasistencia; opcional multa o prioridad reducida.

3. **Roles y permisos**
   - **Admin**: usuarios, médicos, reportes, parámetros.
   - **Médico**: su agenda, pacientes del día, historial básico.
   - **Paciente**: reservar, cancelar/reprogramar, historial personal.

4. **Auditoría y trazabilidad**
   - Bitácora: creación/edición/eliminación de pacientes y citas.
   - Huella de usuario, fecha/hora, valores previos y nuevos.

5. **Reportes**
   - Ocupación por médico/especialidad.
   - Tasa de no-show, tiempos de espera, volumen por franja horaria.

> Implementación incremental, conservando Pacientes y Login existentes.

---

## 🗺️ Diagramas (Mermaid)

### (A) Flujo de **Login** (actual)
```mermaid
flowchart TD
    A[Usuario] --> B[GET /Login]
    B --> C[Ingresa credenciales]
    C --> D[POST /Login/Index]
    D --> E[UsuarioDAO.Validar]
    E --> F{¿Válido?}
    F -- No --> G[Error en Login]
    F -- Sí --> H{Rol}
    H -- Admin --> I[/Admin/Menu]
    H -- Médico --> J[/Medico/Menu]
    H -- Paciente --> K[/Paciente/Menu]
```

### (B) Flujo **Pacientes (CRUD)** (actual)
```mermaid
flowchart TD
    A[Auth OK] --> B[GET /Paciente/Listado]
    B --> C[PacienteDAO.Listar + Paginación]
    C --> D[Vista Listado]

    D --> E[GET /Paciente/Crear] --> F[POST /Paciente/Crear]
    F --> G{Insertar?}
    G -- Sí --> H[Redirect Listado con alerta]
    G -- No --> I[Volver a formulario con error]

    D --> J[GET /Paciente/Editar/{id}] --> K[POST /Paciente/Editar]
    K --> L{Actualizar?}
    L -- Sí --> H
    L -- No --> J

    D --> M[GET /Paciente/Detalle/{id}] --> N[Vista Detalle]
```

### (C) **Modelo de Datos (propuesto)**
```mermaid
erDiagram
    ROLES ||--o{ USUARIOS : tiene
    USUARIOS {
        int IdUsuario PK
        varchar Username
        varchar PasswordHash
        int IdRol FK
    }
    ROLES {
        int IdRol PK
        varchar NombreRol
    }

    MEDICOS {
        int IdMedico PK
        varchar Nombres
        varchar Apellidos
        varchar Especialidad
        varchar CMP
        bit Activo
    }

    PACIENTES {
        int IdPaciente PK
        varchar Dni UNIQUE
        varchar Nombres
        varchar Apellidos
        date FechaNacimiento
        char Genero
        varchar Telefono
        varchar Correo
        varchar Direccion
        bit Activo
    }

    AGENDAS {
        int IdAgenda PK
        int IdMedico FK
        date Fecha
        time HoraInicio
        time HoraFin
        varchar Estado  -- Disponible/Bloqueado
    }

    CITAS {
        int IdCita PK
        int IdAgenda FK
        int IdPaciente FK
        varchar Estado   -- Reservada/Confirmada/Atendida/Cancelada/NoShow
        datetime CreadaEn
        datetime? ModificadaEn
        varchar Observaciones
    }

    MEDICOS ||--o{ AGENDAS : define
    AGENDAS ||--o{ CITAS : recibe
    PACIENTES ||--o{ CITAS : agenda
```

---

## ▶️ Rutas (actuales)
- `/Login/Index` (GET/POST) — inicio de sesión  
- `/Paciente/Listado` (GET) — paginado  
- `/Paciente/Crear` (GET/POST) — alta  
- `/Paciente/Editar/{id}` (GET/POST) — edición  
- `/Paciente/Detalle/{id}` (GET) — detalle  
- `/Admin/Menu`, `/Medico/Menu` — menús de rol

---

## 🔒 Notas técnicas
- ADO.NET con `SqlConnection`, `SqlCommand` y **parámetros** (evita inyección SQL).
- Paginación y conteo en `PacienteController` + `_PagerWithTotal.cshtml`.
- Recomendado: transacciones y códigos de retorno desde SP en Citas/Agendas.

---

## 🛣️ Roadmap corto
1. **Citas**: `sp_Cita_Reservar`, `sp_Cita_Reprogramar`, `sp_Cita_Cancelar`, `sp_Cita_NoShow` con control de colisiones.  
2. **Agenda**: generación masiva de slots por rango/médico/especialidad.  
3. **Auditoría**: tabla `AuditLog` + filtros.  
4. **Reportes**: ocupación, no-show, tiempos de espera.  
5. **Seguridad**: hash + salt; expiración de sesión; bloqueo por intentos.

---

## 🧽 Checklist para renombrar a “Medisys”
1. Renombrar **solución** y **proyecto** en Visual Studio.  
2. Cambiar **Assembly Name** y **Default Namespace** a `Medisys`.  
3. Reemplazar `namespace AplicacionCitasMedicasDB` → `Medisys`.  
4. Renombrar carpetas y actualizar referencias en `.csproj`.  
5. Revisar `appsettings.json` y rutas en `Program.cs`.  
6. Probar `dotnet build` y `dotnet run`.

---

## 📄 Licencia
Uso académico/educativo.
