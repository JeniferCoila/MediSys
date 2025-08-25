using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{

    public class BajasMedicoDAO : IBajasMedico
    {

        private readonly IConfiguration _config;
        public BajasMedicoDAO(IConfiguration config)
        {
            _config = config;
        }

        public (int code, string message) activar(Medico item)
        {
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                cn.Open();

                using SqlTransaction tr = cn.BeginTransaction();
                try
                {
                    using SqlCommand cmd = new SqlCommand("usp_restaurar_medico", cn, tr)
                    {
                        CommandType = CommandType.StoredProcedure
                    };
                    cmd.Parameters.AddWithValue("@idMedico", item.IdMedico);

                    var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                    ret.Direction = ParameterDirection.ReturnValue;

                    cmd.ExecuteNonQuery();
                    tr.Commit();
                    int code = (int)ret.Value;
                    return code switch
                    {
                        0 => (code, "Se restauro el medico: " + item.Nombre + " " + item.Apellido),
                        -1 => (code, "El médico ya esta restaurado"),
                        _ => (code, "Error no identificado")
                    };
                }
                catch (SqlException ex)
                {
                    tr.Rollback();
                    return (-99, ex.Message);

                }
            }
        }

        public IEnumerable<Medico> GetAllBajas()
        {
            return GetAllBajas("");
        }

        public IEnumerable<Medico> GetAllBajas(string filtro)
        {

            List<Medico> listaMedicosBajas = new List<Medico>();
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_listar_medicos_baja", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@filtro", filtro);

                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            listaMedicosBajas.Add(new Medico
                            {
                                IdMedico = dr.GetInt32(0),
                                CMP = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                NombreEspecialidad = dr.IsDBNull(4) ? null : dr.GetString(4),
                                Telefono = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Correo = dr.IsDBNull(6) ? null : dr.GetString(6),
                                FechaBaja = dr.IsDBNull(7) ? null : dr.GetDateTime(7)
                            });
                        }
                    }
                }
            }

            return listaMedicosBajas;
        }

        public Medico SearchMedicoBaja(object id)
        {
            Medico medicoBaja = null;
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_medicos_baja_buscar_por_id", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@idMedico", id);
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            medicoBaja = new Medico
                            {
                                IdMedico = dr.GetInt32(0),
                                CMP = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                NombreEspecialidad = dr.IsDBNull(4) ? null : dr.GetString(4),
                                Telefono = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Correo = dr.IsDBNull(6) ? null : dr.GetString(6),
                                FechaBaja = dr.IsDBNull(7) ? null : dr.GetDateTime(7),
                            };
                        }
                    }
                }
            }

            return medicoBaja;
        }
  
    }
}
