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
                using var cmd = new SqlCommand("usp_medicos_agregar", cn, tr) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.Add("@CMP", SqlDbType.VarChar, 20).Value = item.CMP;
                cmd.Parameters.Add("@Nombre", SqlDbType.VarChar, 100).Value = item.Nombre;
                cmd.Parameters.Add("@Apellido", SqlDbType.VarChar, 100).Value = item.Apellido;
                cmd.Parameters.Add("@IdEspecialidad", SqlDbType.Int).Value = item.IdEspecialidad;
                cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 15).Value = (object?)item.Telefono ?? DBNull.Value;
                cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object?)item.Correo ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery();
                tr.Commit();

                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Médico agregado!"),
                    -1 => (-1, "El CMP ya está registrado."),
                    -2 => (-2, "Ya existe un médico con el mismo nombre y apellido."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627)
            { tr.Rollback(); return (-1, "Violación de unicidad (CMP o identidad duplicada)."); }
            catch (Exception ex)
            { tr.Rollback(); return (0, $"Error: {ex.Message}"); }
        }

        public int Contar()
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_medicos_contar", cn) { CommandType = CommandType.StoredProcedure };
            cn.Open();
            return Convert.ToInt32(cmd.ExecuteScalar());
        }

        public string Delete(Medico item)
        {
            string mensaje = "";
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_medicos_eliminar", cn, tr) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@IdMedico", item.IdMedico);
                int i = cmd.ExecuteNonQuery();
                tr.Commit();
                mensaje = $"¡{i} Médico eliminado correctamente!";
            }
            catch (Exception ex)
            { tr.Rollback(); mensaje = $"Error: {ex.Message}"; }

            return mensaje;
        }

        public IEnumerable<Medico> GetAll()
        {
            return GetAll("");
        }

        public IEnumerable<Medico> GetAll(string filtro)
        {
            var lista = new List<Medico>();
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_medicos", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddWithValue("@filtro", filtro ?? "");

            cn.Open();
            using var dr = cmd.ExecuteReader();
            while (dr.Read())
            {
                lista.Add(new Medico
                {
                    IdMedico = dr.GetInt32(0),
                    CMP = dr.GetString(1),
                    Nombre = dr.GetString(2),
                    Apellido = dr.GetString(3),
                    IdEspecialidad = dr.GetInt32(4),
                    NombreEspecialidad = dr.IsDBNull(5) ? null : dr.GetString(5),
                    Telefono = dr.IsDBNull(6) ? null : dr.GetString(6),
                    Correo = dr.IsDBNull(7) ? null : dr.GetString(7),
                });
            }
            return lista;
        }

        public Medico? Search(object id)
        {
            Medico? medico = null;
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_medicos_buscar", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddWithValue("@IdMedico", id);
            cn.Open();

            using var dr = cmd.ExecuteReader();
            if (dr.Read())
            {
                medico = new Medico
                {
                    IdMedico = dr.GetInt32(0),
                    CMP = dr.GetString(1),
                    Nombre = dr.GetString(2),
                    Apellido = dr.GetString(3),
                    IdEspecialidad = dr.GetInt32(4),
                    Telefono = dr.IsDBNull(5) ? null : dr.GetString(5),
                    Correo = dr.IsDBNull(6) ? null : dr.GetString(6),
                    FechaCreacion = dr.FieldCount > 7 && !dr.IsDBNull(7) ? dr.GetDateTime(7) : null,
                    FechaActualizacion = dr.FieldCount > 8 && !dr.IsDBNull(8) ? dr.GetDateTime(8) : null,
                    FechaBaja = dr.FieldCount > 9 && !dr.IsDBNull(9) ? dr.GetDateTime(9) : null,
                    NombreEspecialidad = dr.FieldCount > 10 && !dr.IsDBNull(10) ? dr.GetString(10) : null
                };
            }
            return medico;
        }

        public (int code, string message) Update(Medico item)
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_medicos_actualizar", cn, tr) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.Add("@IdMedico", SqlDbType.Int).Value = item.IdMedico;
                cmd.Parameters.Add("@CMP", SqlDbType.VarChar, 20).Value = item.CMP;
                cmd.Parameters.Add("@Nombre", SqlDbType.VarChar, 100).Value = item.Nombre;
                cmd.Parameters.Add("@Apellido", SqlDbType.VarChar, 100).Value = item.Apellido;
                cmd.Parameters.Add("@IdEspecialidad", SqlDbType.Int).Value = item.IdEspecialidad;
                cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 15).Value = (object?)item.Telefono ?? DBNull.Value;
                cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object?)item.Correo ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery();
                tr.Commit();

                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Médico actualizado!"),
                    -1 => (-1, "El CMP ya está registrado por otro médico."),
                    -2 => (-2, "Ya existe otro médico con ese nombre y apellido."),
                    -99 => (-99, "El médico no existe o está inactivo."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627)
            { tr.Rollback(); return (-1, "Violación de unicidad (CMP o identidad duplicada)."); }
            catch (Exception ex)
            { tr.Rollback(); return (0, $"Error: {ex.Message}"); }
        }
    }
}
