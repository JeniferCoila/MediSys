using AplicacionCitasMedicasDB.Models;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IMedico
    {
        (int code, string message) Add(Medico item);
        (int code, string message) Update(Medico item);
        string Delete(Medico item);
        IEnumerable<Medico> GetAll();
        IEnumerable<Medico> GetAll(string filtro);
        Medico Search(object id);
        int Contar(); // conta registros activos
    }
}
