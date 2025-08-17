using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class PacienteDAO : IPaciente
    {

        private readonly IConfiguration _config;

        public PacienteDAO(IConfiguration config)
        {
            _config = config;
        }

        public (int code, string message) Add(Paciente item)
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_pacientes_agregar", cn, tr) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.Add("@DNI", SqlDbType.VarChar, 10).Value = item.DNI;
                cmd.Parameters.Add("@Nombre", SqlDbType.VarChar, 100).Value = item.Nombre;
                cmd.Parameters.Add("@Apellido", SqlDbType.VarChar, 100).Value = item.Apellido;
                cmd.Parameters.Add("@FechaNacimiento", SqlDbType.Date).Value = item.FechaNacimiento.Date;
                cmd.Parameters.Add("@Genero", SqlDbType.Char, 1).Value = (object?)item.Genero ?? DBNull.Value;
                cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 15).Value = (object?)item.Telefono ?? DBNull.Value;
                cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object?)item.Correo ?? DBNull.Value;
                cmd.Parameters.Add("@Direccion", SqlDbType.VarChar, 200).Value = (object?)item.Direccion ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery(); tr.Commit();
                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Paciente agregado!"),
                    -1 => (-1, "El DNI ya está registrado."),
                    -2 => (-2, "Ya existe un paciente con el mismo nombre, apellido y fecha."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627) // índice único
            { tr.Rollback(); return (-1, "Violación de unicidad (DNI o identidad duplicada)."); }
            catch (Exception ex)
            { tr.Rollback(); return (0, $"Error: {ex.Message}"); }
        }

        public int Contar()
        {
            int total = 0;
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_pacientes_contar", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cn.Open();
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }
            }
            return total;
        }

        public string Delete(Paciente item)
        {
            string mensaje = "";
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                cn.Open();
                using (SqlTransaction tr = cn.BeginTransaction())
                {
                    try
                    {
                        using (SqlCommand cmd = new SqlCommand("usp_pacientes_eliminar", cn, tr))
                        {
                            cmd.CommandType = CommandType.StoredProcedure;
                            cmd.Parameters.AddWithValue("@IdPaciente", item.IdPaciente);

                            int i = cmd.ExecuteNonQuery();
                            tr.Commit();
                            mensaje = $"¡{i} Paciente eliminado correctamente!";
                        }
                    }
                    catch (Exception ex)
                    {
                        tr.Rollback();
                        mensaje = $"Error: {ex.Message}";
                    }
                }
            }
            return mensaje;
        }

        public IEnumerable<Paciente> GetAll()
        {
            return GetAll(""); // reutiliza método con filtro vacío
        }

        public IEnumerable<Paciente> GetAll(string filtro)
        {
            List<Paciente> lista = new List<Paciente>();
            using (SqlConnection cn = new SqlConnection(_config.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_pacientes", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@filtro", filtro ?? "");

                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Paciente
                            {
                                IdPaciente = dr.GetInt32(0),
                                DNI = dr.GetString(1),
                                Nombre = dr.GetString(2),
                                Apellido = dr.GetString(3),
                                FechaNacimiento = dr.GetDateTime(4),
                                Genero = dr.IsDBNull(5) ? null : dr.GetString(5),
                                Telefono = dr.IsDBNull(6) ? null : dr.GetString(6),
                                Correo = dr.IsDBNull(7) ? null : dr.GetString(7),
                                Direccion = dr.IsDBNull(8) ? null : dr.GetString(8)
                            });
                        }
                    }
                }
            }
            return lista;
        }

        public Paciente? Search(object id)
        {
            Paciente? paciente = null;

            using (var cn = new SqlConnection(_config.GetConnectionString("cadena")))
            using (var cmd = new SqlCommand("usp_pacientes_buscar", cn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdPaciente", id);
                cn.Open();

                using (var dr = cmd.ExecuteReader())
                {
                    if (dr.Read())
                    {
                        paciente = new Paciente
                        {
                            IdPaciente = dr.GetInt32(0),
                            DNI = dr.GetString(1),
                            Nombre = dr.GetString(2),
                            Apellido = dr.GetString(3),
                            FechaNacimiento = dr.GetDateTime(4),
                            Genero = dr.IsDBNull(5) ? null : dr.GetString(5),
                            Telefono = dr.IsDBNull(6) ? null : dr.GetString(6),
                            Correo = dr.IsDBNull(7) ? null : dr.GetString(7),
                            Direccion = dr.IsDBNull(8) ? null : dr.GetString(8)
                        };
                        if (dr.FieldCount > 9)
                            paciente.FechaCreacion = dr.GetDateTime(9);
                        if (dr.FieldCount > 10 && !dr.IsDBNull(10))
                            paciente.FechaActualizacion = dr.GetDateTime(10);
                        if (dr.FieldCount > 11 && !dr.IsDBNull(11))
                            paciente.FechaBaja = dr.GetDateTime(11);
                    }
                }
            }
            return paciente;
        }


        public (int code, string message) Update(Paciente item)
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_pacientes_actualizar", cn, tr) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.Add("@IdPaciente", SqlDbType.Int).Value = item.IdPaciente;
                cmd.Parameters.Add("@DNI", SqlDbType.VarChar, 10).Value = item.DNI;
                cmd.Parameters.Add("@Nombre", SqlDbType.VarChar, 100).Value = item.Nombre;
                cmd.Parameters.Add("@Apellido", SqlDbType.VarChar, 100).Value = item.Apellido;
                cmd.Parameters.Add("@FechaNacimiento", SqlDbType.Date).Value = item.FechaNacimiento.Date;
                cmd.Parameters.Add("@Genero", SqlDbType.Char, 1).Value = (object?)item.Genero ?? DBNull.Value;
                cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 15).Value = (object?)item.Telefono ?? DBNull.Value;
                cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object?)item.Correo ?? DBNull.Value;
                cmd.Parameters.Add("@Direccion", SqlDbType.VarChar, 200).Value = (object?)item.Direccion ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery(); tr.Commit();
                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Paciente actualizado!"),
                    -1 => (-1, "El DNI ya está registrado por otro paciente."),
                    -2 => (-2, "Ya existe otro paciente con ese nombre, apellido y fecha."),
                    -99 => (-99, "El paciente no existe o está inactivo."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627)
            { tr.Rollback(); return (-1, "Violación de unicidad (DNI o identidad duplicada)."); }
            catch (Exception ex)
            { tr.Rollback(); return (0, $"Error: {ex.Message}"); }
        }
    }
}
