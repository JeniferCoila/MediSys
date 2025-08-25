using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace AplicacionCitasMedicasDB.Models
{
    public class Medico
    {
        [DisplayName("ID")]
        public int IdMedico { get; set; }

        [Required(ErrorMessage = "El CMP es obligatorio")]
        [MaxLength(20)]
        public string CMP { get; set; } = string.Empty;

        [Required(ErrorMessage = "El nombre es obligatorio")]
        [MaxLength(100)]
        public string Nombre { get; set; } = string.Empty;

        [Required(ErrorMessage = "El apellido es obligatorio")]
        [MaxLength(100)]
        public string Apellido { get; set; } = string.Empty;

        [DisplayName("Especialidad")]
        [Required(ErrorMessage = "Debe seleccionar una especialidad")]
        public int IdEspecialidad { get; set; }

        [MaxLength(15)]
        public string? Telefono { get; set; }

        [EmailAddress(ErrorMessage = "Correo inválido")]
        [MaxLength(100)]
        public string? Correo { get; set; }

        public string? FotoUrl { get; set; }

        // Auditoría (opcional mostrar en Details)
        public DateTime? FechaCreacion { get; set; }
        public DateTime? FechaActualizacion { get; set; }
        public DateTime? FechaBaja { get; set; }

        // Solo para mostrar en listas/detalle
        public string? NombreEspecialidad { get; set; }
    }
}
