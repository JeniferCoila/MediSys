namespace AplicacionCitasMedicasDB.Models
{
    public class Usuario
    {
        public int IdUsuario { get; set; }
        public string? Username { get; set; }
        public string? Password { get; set; }
        public int IdRol { get; set; }
        public string? NombreRol { get; set; }
    }
}
