using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace AplicacionCitasMedicasDB.Models
{
    public class Paciente
    {
        [DisplayName("ID")]
        public int IdPaciente { get; set; }

        [Required(ErrorMessage = "El DNI es obligatorio")]
        public string DNI { get; set; }

        [Required(ErrorMessage = "El Nombre es obligatorio")]
        public string Nombre { get; set; }

        [Required(ErrorMessage = "El Apellido es obligatorio")]
        public string Apellido { get; set; }

        [Required(ErrorMessage = "La Fecha de Nacimiento es obligatoria")]
        [DataType(DataType.Date)]
        public DateTime FechaNacimiento { get; set; }

        public string? Genero { get; set; }
        public string? Telefono { get; set; }
        public string? Correo { get; set; }
        public string? Direccion { get; set; }

        [DisplayName("Fecha de Creación")]
        public DateTime FechaCreacion { get; set; }

        [DisplayName("Fecha de Actualización")]
        public DateTime? FechaActualizacion { get; set; }

        [DisplayName("Fecha de Baja")]
        public DateTime? FechaBaja { get; set; }

        // para concurrencia
        [Timestamp]                
        public byte[]? RowVersion { get; set; }
    }
}
