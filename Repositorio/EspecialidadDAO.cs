using AplicacionCitasMedicasDB.Models;
using Microsoft.CodeAnalysis.Elfie.Serialization;
using Microsoft.Data.SqlClient;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class EspecialidadDAO : IEspecialidad
    {
        private readonly IConfiguration _config;

        public EspecialidadDAO(IConfiguration config)
        {
            _config = config;
        }
        public IEnumerable<Especialidad> GetAll()
        {
            return GetAll("");
        }

        public IEnumerable<Especialidad> GetAll(string filtro)
        {

            List<Especialidad> listaEspecialidades = new List<Especialidad>();
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_listarEspecialidades", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@filtro", filtro);

                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            listaEspecialidades.Add(new Especialidad
                            {
                                IdEspecialidad = dr.GetInt32(0),
                                Nombre = dr.GetString(1)
                            });
                        }
                    }
                }
            }

            return listaEspecialidades;
        }


    }
}
