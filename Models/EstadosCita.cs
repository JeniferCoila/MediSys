using System.ComponentModel.DataAnnotations;

namespace AplicacionCitasMedicasDB.Models
{
    public class EstadosCita
    {
        [Display(Name = "ID")]
        public int IdEstadoCita { get; set; }

        [Required, StringLength(50)]
        [Display(Name = "Estado")]
        public string Nombre { get; set; } = default!;
    }
}
