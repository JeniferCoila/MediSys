using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public interface IEspecialidad
    {
        IEnumerable<Especialidad> GetAll();
    }

    public class EspecialidadDAO : IEspecialidad
    {
        private readonly IConfiguration _config;
        public EspecialidadDAO(IConfiguration config) => _config = config;

        public IEnumerable<Especialidad> GetAll()
        {
            var lista = new List<Especialidad>();
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_especialidades_listar", cn) { CommandType = CommandType.StoredProcedure };
            cn.Open();
            using var dr = cmd.ExecuteReader();
            while (dr.Read())
            {
                lista.Add(new Especialidad
                {
                    IdEspecialidad = dr.GetInt32(0),
                    Nombre = dr.GetString(1)
                });
            }
            return lista;
        }
    }

}
