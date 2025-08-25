using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class BajasPacienteDAO : IBajasPaciente
    {

        private readonly IConfiguration _config;
        public BajasPacienteDAO(IConfiguration config)
        {
            _config = config;
        }


        public (int code, string message) activar(Paciente item)
        {
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                cn.Open();

                using SqlTransaction tr = cn.BeginTransaction();
                try
                {
                    using SqlCommand cmd = new SqlCommand("usp_restaurar_paciente", cn, tr)
                    {
                        CommandType = CommandType.StoredProcedure
                    };
                    cmd.Parameters.AddWithValue("@IdPaciente", item.IdPaciente);

                    var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                    ret.Direction = ParameterDirection.ReturnValue;

                    cmd.ExecuteNonQuery();
                    tr.Commit();
                    int code = (int)ret.Value;
                    return code switch
                    {
                        0 => (code, "Se restauro el paciente: " + item.Nombre + " " + item.Apellido),
                        -1 => (code, "El paciente ya esta restaurado"),
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

        public IEnumerable<Paciente> GetAllBajas()
        {
            return GetAllBajas("");
        }

        public IEnumerable<Paciente> GetAllBajas(string filtro)
        {

            List<Paciente> listaPacientesBajas = new List<Paciente>();
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_listar_pacientes_baja", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@filtro", filtro);

                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            listaPacientesBajas.Add(new Paciente
                            {
                                IdPaciente = dr.GetInt32(0),
                                DNI = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                FechaNacimiento =  dr.GetDateTime(4),
                                Genero = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Telefono = dr.IsDBNull(6) ? null : dr.GetString(6),
                                Correo = dr.IsDBNull(7) ? null : dr.GetString(7),
                                Direccion = dr.IsDBNull(8) ? null : dr.GetString(8),
                                FechaBaja = dr.IsDBNull(9) ? null : dr.GetDateTime(9)
                            });
                        }
                    }
                }
            }


            return listaPacientesBajas;
        }

        public Paciente SearchPacienteBaja(object id)
        {
            Paciente pacienteBaja = null;
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_paciente_baja_buscar_por_id", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdPaciente", id);
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            pacienteBaja = new Paciente
                            {
                                IdPaciente = dr.GetInt32(0),
                                DNI = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                FechaNacimiento = dr.GetDateTime(4),
                                Genero = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Telefono = dr.IsDBNull(6) ? null : dr.GetString(6),
                                Correo = dr.IsDBNull(7) ? null : dr.GetString(7),
                                Direccion = dr.IsDBNull(8) ? null : dr.GetString(8),
                                FechaBaja = dr.IsDBNull(9) ? null : dr.GetDateTime(9)
                            };
                        }
                    }
                }
            }
 

            return pacienteBaja;
        }

    }
}
