using System.ComponentModel.DataAnnotations;

namespace AplicacionCitasMedicasDB.Models
{
    public class Especialidad
    {
        public int IdEspecialidad { get; set; }

        [Required]
        [StringLength(100)]
        public string Nombre { get; set; }

        public bool Estado { get; set; }
    }
}
