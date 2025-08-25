using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;

namespace AplicacionCitasMedicasDB.Models
{
    public class Cita
    {
        [Display(Name = "ID")]
        public int IdCita { get; set; }

        // ==== Relaciones requeridas ====
        [Required(ErrorMessage = "Seleccione un paciente.")]
        [Display(Name = "Paciente")]
        public int IdPaciente { get; set; }

        [Required(ErrorMessage = "Seleccione un médico.")]
        [Display(Name = "Médico")]
        public int IdMedico { get; set; }

        // ===== Fecha y horas =====
        [Required(ErrorMessage = "La fecha es obligatoria.")]
        [DataType(DataType.Date)]
        [Display(Name = "Fecha")]
        public DateTime Fecha { get; set; }


        [Required(ErrorMessage = "La hora de inicio es obligatoria.")]
        [DataType(DataType.Time)]
        [Display(Name = "Hora de inicio")]
        public TimeSpan HoraInicio { get; set; }

        [DataType(DataType.Time)]
        [Display(Name = "Hora fin")]
        public TimeSpan? HoraFin { get; set; }   // si es null, en SP se asume 30 minutos

        // ==== Estado de la cita ====
        [Required(ErrorMessage = "Seleccione el estado de la cita.")]
        [Display(Name = "Estado de la cita")]
        public int IdEstadoCita { get; set; }

        // ==== Información adicional ====
        [StringLength(200, ErrorMessage = "Máximo 200 caracteres.")]
        [Display(Name = "Motivo")]
        public string? Motivo { get; set; }

        [StringLength(500, ErrorMessage = "Máximo 500 caracteres.")]
        [Display(Name = "Observaciones")]
        public string? Observaciones { get; set; }

        // ==== Auditoría / Lógico ====
        [Display(Name = "Activo")]
        public bool Estado { get; set; } = true;

        [Display(Name = "Fecha de creación")]
        public DateTime? FechaCreacion { get; set; }

        [Display(Name = "Fecha de actualización")]
        public DateTime? FechaActualizacion { get; set; }

        [Display(Name = "Fecha de baja")]
        public DateTime? FechaBaja { get; set; }

        [Timestamp]
        public byte[]? RowVersion { get; set; }

        // ==== Propiedades de sólo lectura para vistas (no mapeadas) ====
        [NotMapped, Display(Name = "Paciente")]
        public string? PacienteNombreCompleto { get; set; }   // p.ej. "Juan Pérez"

        [NotMapped, Display(Name = "DNI Paciente")]
        public string? PacienteDNI { get; set; }

        [NotMapped, Display(Name = "Médico")]
        public string? MedicoNombreCompleto { get; set; }     // p.ej. "Dra. Ana Torres"

        [NotMapped, Display(Name = "CMP")]
        public string? MedicoCMP { get; set; }

        [NotMapped, Display(Name = "Estado")]
        public string? NombreEstado { get; set; }

        // Conveniencia para vistas/validaciones simples
        [NotMapped]
        [Display(Name = "Duración (min)")]
        public int DuracionMinutos =>
            (int)((HoraFin ?? HoraInicio.Add(TimeSpan.FromMinutes(30))) - HoraInicio).TotalMinutes;
    }
}
