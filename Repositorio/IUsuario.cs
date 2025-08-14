using AplicacionCitasMedicasDB.Models;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IUsuario
    {
        Usuario? ValidarLogin(string username, string password);
    }
}
