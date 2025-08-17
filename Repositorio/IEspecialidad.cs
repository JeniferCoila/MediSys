using AplicacionCitasMedicasDB.Models;
namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IEspecialidad
    {
       IEnumerable<Especialidad> GetAll();
       IEnumerable<Especialidad> GetAll(string filtro);
    }
}
