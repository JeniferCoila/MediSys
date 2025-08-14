using AplicacionCitasMedicasDB.Models;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IPaciente
    {
        (int code, string message) Add(Paciente item);
        (int code, string message) Update(Paciente item);
        string Delete(Paciente item);
        IEnumerable<Paciente> GetAll();
        IEnumerable<Paciente> GetAll(string filtro);
        Paciente Search(object id);
        int Contar(); // conta registros activos
    }
}
