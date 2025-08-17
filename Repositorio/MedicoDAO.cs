using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class MedicoDAO : IMedico
    {

        private readonly IConfiguration _config;

        public MedicoDAO(IConfiguration config)
        {
            _config = config;
        }


        public (int code, string message) Add(Medico item)
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_medicos_agregar", cn, tr)

                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.Add("@CMP", SqlDbType.VarChar, 20).Value = item.CMP;
                cmd.Parameters.Add(@"Nombre", SqlDbType.VarChar, 100).Value = item.Nombre;
                cmd.Parameters.Add(@"Apellido", SqlDbType.VarChar, 100).Value = item.Apellido;
                cmd.Parameters.Add("@IdEspecialidad", SqlDbType.Int).Value = item.IdEspecialidad ?? (object)DBNull.Value;
                cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 15).Value = (object)item.Telefono ?? DBNull.Value;
                cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object)item.Correo ?? DBNull.Value;

 

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery(); tr.Commit();
                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Médico agregado!"),
                    -1 => (-1, "El CMP ya está registrado."),
                    -2 => (-2, "Ya existe un medico con el mismo nombre, apellido y especialidad."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627) // Unique constraint violation
            {
                tr.Rollback();
                return (-1, "El CMP ya está registrado.");
            }
            catch (Exception ex)
            {
                tr.Rollback();
                return (0, $"Error al agregar médico: {ex.Message}");
            }
        }

        // contar registros activos
        public int Contar()
        {
            int total = 0;
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using(SqlCommand cmd = new SqlCommand("usp_medicos_contar", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cn.Open();
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }
            }
            return total;
        }

        public string Delete(Medico item)
        {
            string mensaje = "";
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                cn.Open();
                using (SqlTransaction tr = cn.BeginTransaction())
                {
                    try
                    {
                        using (SqlCommand cmd = new SqlCommand("usp_medicos_eliminar", cn, tr))
                        {
                            cmd.CommandType = CommandType.StoredProcedure;
                            cmd.Parameters.AddWithValue("@IdMedico", item.IdMedico);
                            
                          

                            int i = cmd.ExecuteNonQuery();
                            tr.Commit();

                            mensaje = $"¡Paciente: {"'"+item.Nombre+"'"} eliminado correctamente!";
                        }
                    }
                    catch (SqlException ex) when (ex.Number == 547) // Foreign key violation
                    {
                        tr.Rollback();
                        mensaje = "El médico tiene citas asociadas y no puede ser eliminado";
                     }
                    return mensaje;
                }
            }
        }

        // listar todos los medicos sin filtro
        public IEnumerable<Medico> GetAll()
        {
            return GetAll("");
        }

        // listar todos los medicos con filtro
        public IEnumerable<Medico> GetAll(string filtro)
        {
            

            List<Medico> listaMedicos = new List<Medico>();
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_listarMedicos", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@filtro", filtro);

                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while(dr.Read())
                        {
                           listaMedicos.Add(new Medico
                            {
                                IdMedico = dr.GetInt32(0),
                                CMP = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                NombreEspecialidad = dr.IsDBNull(4) ? null : dr.GetString(4),
                                Telefono = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Correo = dr.IsDBNull(6) ? null : dr.GetString(6),
                           });
                        }
                    }
                }
            }

            return listaMedicos;
        }

        public Medico Search(object id)
        {
            Medico medico = null;
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using(SqlCommand cmd = new SqlCommand("usp_medicos_buscar_por_id", cn))
                {
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IDMedico", id);
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            medico = new Medico
                            {
                                IdMedico = dr.GetInt32(0),
                                CMP = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                IdEspecialidad = dr.IsDBNull(4) ? null : dr.GetInt32(4),
                                NombreEspecialidad = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Telefono = dr.IsDBNull(6) ? null : dr.GetString(6),
                                Correo = dr.IsDBNull(7) ? null : dr.GetString(7)
                            
                            };
                            if (dr.FieldCount > 8)
                                medico.FechaCreacion =  dr.GetDateTime(8);
                            if (dr.FieldCount > 9 && !dr.IsDBNull(9) )
                                medico.FechaActualizacion = dr.GetDateTime(9);
                            if (dr.FieldCount > 10 && !dr.IsDBNull(10))
                                medico.FechaBaja =  dr.GetDateTime(10);

                        }
                    }
                }
            }
            return medico;
        }


        public (int code, string message) Update(Medico item)
        {
            using SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using SqlTransaction tr = cn.BeginTransaction();
            try
            {
                using SqlCommand cmd = new SqlCommand("usp_medicos_actualizar", cn, tr)
                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.Add("@IdMedico", SqlDbType.Int).Value = item.IdMedico;
                cmd.Parameters.Add("@CMP", SqlDbType.VarChar, 10).Value = item.CMP;
                cmd.Parameters.Add(@"Nombre", SqlDbType.VarChar, 100).Value = item.Nombre;
                cmd.Parameters.Add(@"Apellido", SqlDbType.VarChar, 100).Value = item.Apellido;
                cmd.Parameters.Add("@IdEspecialidad", SqlDbType.Int).Value = item.IdEspecialidad ?? (object)DBNull.Value;
                cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 15).Value = (object)item.Telefono ?? DBNull.Value;
                cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object)item.Correo ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery();
                tr.Commit();
                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Médico actualizado!"),
                    -1 => (-1, "El CMP ya está registrado."),
                    -2 => (-2, "Ya existe un medico con el mismo nombre, apellido y especialidad."),
                    -99 => (-99, "El médico no existe."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex)
            when (ex.Number is 2601 or 2627) // Unique constraint violation
            {
                tr.Rollback();
                return (-1, "El CMP ya está registrado.");
            }
            catch (Exception ex)
            {
                tr.Rollback();
                return (0, $"Error al actualizar médico: {ex.Message}");
            }
          
        }
    }
}
