using AplicacionCitasMedicasDB.Models;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IBajasPaciente
    {

        IEnumerable<Paciente> GetAllBajas();
        IEnumerable<Paciente> GetAllBajas(string filtro);
        (int code, string message) activar(Paciente item);

        Paciente SearchPacienteBaja(object id);
        //int Contar(); // conta registros activos


    }
}
