using AplicacionCitasMedicasDB.Models;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface ICita
    {
        (int code, string message) Add(Cita item);
        (int code, string message) Update(Cita item);
        string Delete(Cita item);

        IEnumerable<Cita> GetAll();
        IEnumerable<Cita> GetAll(string filtro);

        Cita? Search(object id);

        int Contar();

        // Catálogo para combos
        IEnumerable<EstadosCita> GetEstados();
    }
}
