using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel;

namespace AplicacionCitasMedicasDB.Models
{
    public class Medico
    {
        [Key]
        public int IdMedico { get; set; }

        [Required(ErrorMessage = "El CMP es obligatorio.")]
        [StringLength(20, ErrorMessage = "El CMP no puede exceder los 20 caracteres.")]
        [DisplayName("Código Médico Profesional (CMP)")]
        public string CMP { get; set; } = string.Empty;

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(100, ErrorMessage = "El nombre no puede exceder los 100 caracteres.")]
        [DisplayName("Nombre")]
        public string Nombre { get; set; } = string.Empty;

        [Required(ErrorMessage = "El apellido es obligatorio.")]
        [StringLength(100, ErrorMessage = "El apellido no puede exceder los 100 caracteres.")]
        [DisplayName("Apellido")]
        public string Apellido { get; set; } = string.Empty;

        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar una especialidad válida.")]
        [DisplayName("Especialidad")]
        public int? IdEspecialidad { get; set; }

         public string? NombreEspecialidad { get; set; }


        [StringLength(20, ErrorMessage = "El teléfono no puede exceder los 20 caracteres.")]
        [DisplayName("Teléfono")]
        public string? Telefono { get; set; }

        [EmailAddress(ErrorMessage = "El correo electrónico no es válido.")]
        [StringLength(150, ErrorMessage = "El correo no puede exceder los 150 caracteres.")]
        [DisplayName("Correo Electrónico")]
        public string? Correo { get; set; }

 
        [DisplayName("Fecha de Creación")]
        public DateTime FechaCreacion { get; set; }

        [DisplayName("Fecha de Actualización")]
        public DateTime? FechaActualizacion { get; set; }

        [DisplayName("Fecha de Baja")]
        public DateTime? FechaBaja { get; set; }

        [Timestamp] // Marca para control de concurrencia
        public byte[]? RowVersion { get; set; }
    }
}
