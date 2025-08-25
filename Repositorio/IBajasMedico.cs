using AplicacionCitasMedicasDB.Models;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IBajasMedico
    {
        IEnumerable<Medico> GetAllBajas();
        IEnumerable<Medico> GetAllBajas(string filtro);
        (int code, string message) activar(Medico item);

        Medico SearchMedicoBaja(object id);
        //int Contar(); // conta registros activos

    }
}
