using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class CitaDAO : ICita
    {

        private readonly IConfiguration _config;

        public CitaDAO(IConfiguration config)
        {
            _config = config;
        }


        public (int code, string message) Add(Cita item)
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_citas_agregar", cn, tr)
                { CommandType = CommandType.StoredProcedure };

                cmd.Parameters.Add("@Fecha", SqlDbType.Date).Value = item.Fecha.Date;
                cmd.Parameters.Add("@IdMedico", SqlDbType.Int).Value = item.IdMedico;
                cmd.Parameters.Add("@HoraInicio", SqlDbType.Time).Value = item.HoraInicio;
                cmd.Parameters.Add("@HoraFin", SqlDbType.Time).Value = (object?)item.HoraFin ?? DBNull.Value;
                cmd.Parameters.Add("@IdEstadoCita", SqlDbType.Int).Value = item.IdEstadoCita;
                cmd.Parameters.Add("@Motivo", SqlDbType.VarChar, 255).Value = (object?)item.Motivo ?? DBNull.Value;
                cmd.Parameters.Add("@Observaciones", SqlDbType.VarChar, 500).Value = (object?)item.Observaciones ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery(); tr.Commit();

                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Cita registrada!"),
                    -1 => (-1, "Paciente inválido o inactivo."),
                    -2 => (-2, "Médico inválido o inactivo."),
                    -3 => (-3, "Rango de hora inválido (HoraFin <= HoraInicio)."),
                    -4 => (-4, "Conflicto: el Médico ya tiene una cita en ese horario."),
                    -5 => (-5, "Conflicto: el Paciente ya tiene una cita en ese horario."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627)
            { tr.Rollback(); return (-1, "Violación de unicidad."); }
            catch (Exception ex)
            { tr.Rollback(); return (0, $"Error: {ex.Message}"); }
        }

        public int Contar()
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_citas_contar", cn) { CommandType = CommandType.StoredProcedure };
            cn.Open();
            return Convert.ToInt32(cmd.ExecuteScalar());
        }

        public string Delete(Cita item)
        {
            string mensaje = "";
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_citas_eliminar", cn, tr)
                { CommandType = CommandType.StoredProcedure };

                cmd.Parameters.AddWithValue("@IdCita", item.IdCita);

                int i = cmd.ExecuteNonQuery();
                tr.Commit();
                mensaje = (i > 0) ? "Cita eliminada correctamente." :
                                    "No se pudo eliminar la cita.";
            }
            catch (Exception ex)
            {
                tr.Rollback();
                mensaje = $"Error: {ex.Message}";
            }
            return mensaje;
        }

        public IEnumerable<Cita> GetAll()
        {
            return GetAll("");
        }

        public IEnumerable<Cita> GetAll(string filtro)
        {
            var lista = new List<Cita>();
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_citas", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddWithValue("@filtro", filtro ?? "");

            cn.Open();
            using var dr = cmd.ExecuteReader();
            while (dr.Read())
            {
              
                int i = 0;
                var cita = new Cita
                {
                    IdCita = dr.GetInt32(0),
                    IdPaciente = dr.GetInt32(1),
                    PacienteDNI = dr.IsDBNull(2) ? null : dr.GetString(2),
                    PacienteNombreCompleto = dr.IsDBNull(3) ? null : dr.GetString(3),

                    IdMedico = dr.GetInt32(4),
                    MedicoCMP = dr.IsDBNull(5) ? null : dr.GetString(5),
                    MedicoNombreCompleto = dr.IsDBNull(6) ? null : dr.GetString(6),

                    Fecha = dr.GetDateTime(7),
                    HoraInicio = dr.GetTimeSpan(8),
                    HoraFin = dr.IsDBNull(9) ? (TimeSpan?)null : dr.GetTimeSpan(9),

                    IdEstadoCita = dr.GetInt32(10),
                    NombreEstado = dr.IsDBNull(11) ? null : dr.GetString(11),

                    Motivo = dr.IsDBNull(12) ? null : dr.GetString(12),
                    Observaciones = dr.IsDBNull(13) ? null : dr.GetString(13)
                };
                lista.Add(cita);
            }
            return lista;
        }

        public IEnumerable<EstadosCita> GetEstados()
        {
            var lista = new List<EstadosCita>();
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_estadoscita_listar", cn) { CommandType = CommandType.StoredProcedure };
            cn.Open();

            using var dr = cmd.ExecuteReader();
            while (dr.Read())
            {
                lista.Add(new EstadosCita
                {
                    IdEstadoCita = dr.GetInt32(0),
                    Nombre = dr.GetString(1)
                });
            }
            return lista;
        }

        public Cita? Search(object id)
        {
            Cita? cita = null;
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            using var cmd = new SqlCommand("usp_citas_buscar", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddWithValue("@IdCita", id);
            cn.Open();

            using var dr = cmd.ExecuteReader();
            if (dr.Read())
            {
                // Orden coherente con el SP de buscs
                int i = 0;
                cita = new Cita
                {
                    IdCita = dr.GetInt32(0),
                    IdPaciente = dr.GetInt32(1),
                    PacienteDNI = dr.IsDBNull(2) ? null : dr.GetString(2),
                    PacienteNombreCompleto = dr.IsDBNull(3) ? null : dr.GetString(3),

                    IdMedico = dr.GetInt32(4),
                    MedicoCMP = dr.IsDBNull(5) ? null : dr.GetString(5),
                    MedicoNombreCompleto = dr.IsDBNull(6) ? null : dr.GetString(6),

                    Fecha = dr.GetDateTime(7),
                    HoraInicio = dr.GetTimeSpan(8),
                    HoraFin = dr.IsDBNull(9) ? (TimeSpan?)null : dr.GetTimeSpan(9),

                    IdEstadoCita = dr.GetInt32(10),
                    NombreEstado = dr.IsDBNull(11) ? null : dr.GetString(11),

                    Motivo = dr.IsDBNull(12) ? null : dr.GetString(12),
                    Observaciones = dr.IsDBNull(13) ? null : dr.GetString(13),

                    Estado = !dr.IsDBNull(14) && dr.GetBoolean(14),
                    FechaCreacion = dr.IsDBNull(15) ? (DateTime?)null : dr.GetDateTime(15),
                    FechaActualizacion = dr.IsDBNull(16) ? (DateTime?)null : dr.GetDateTime(16),
                    FechaBaja = dr.IsDBNull(17) ? (DateTime?)null : dr.GetDateTime(17)
                };
            }

            return cita;
        }

        public (int code, string message) Update(Cita item)
        {
            using var cn = new SqlConnection(_config.GetConnectionString("cadena"));
            cn.Open();
            using var tr = cn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand("usp_citas_actualizar", cn, tr)
                { CommandType = CommandType.StoredProcedure };

                cmd.Parameters.Add("@IdCita", SqlDbType.Int).Value = item.IdCita;
                cmd.Parameters.Add("@IdPaciente", SqlDbType.Int).Value = item.IdPaciente;
                cmd.Parameters.Add("@IdMedico", SqlDbType.Int).Value = item.IdMedico;
                cmd.Parameters.Add("@Fecha", SqlDbType.Date).Value = item.Fecha.Date;
                cmd.Parameters.Add("@HoraInicio", SqlDbType.Time).Value = item.HoraInicio;
                cmd.Parameters.Add("@HoraFin", SqlDbType.Time).Value = (object?)item.HoraFin ?? DBNull.Value;
                cmd.Parameters.Add("@IdEstadoCita", SqlDbType.Int).Value = item.IdEstadoCita;
                cmd.Parameters.Add("@Motivo", SqlDbType.VarChar, 255).Value = (object?)item.Motivo ?? DBNull.Value;
                cmd.Parameters.Add("@Observaciones", SqlDbType.VarChar, 500).Value = (object?)item.Observaciones ?? DBNull.Value;

                var ret = cmd.Parameters.Add("RETURN_VALUE", SqlDbType.Int);
                ret.Direction = ParameterDirection.ReturnValue;

                cmd.ExecuteNonQuery(); tr.Commit();

                int code = (int)ret.Value;
                return code switch
                {
                    1 => (1, "¡Cita actualizada!"),
                    -1 => (-1, "Cita inexistente o inactiva."),
                    -2 => (-2, "Paciente inválido o inactivo."),
                    -3 => (-3, "Médico inválido o inactivo."),
                    -4 => (-4, "Rango de hora inválido (HoraFin <= HoraInicio)."),
                    -5 => (-5, "Conflicto: el Médico ya tiene una cita en ese horario."),
                    -6 => (-6, "Conflicto: el Paciente ya tiene una cita en ese horario."),
                    _ => (0, "No se pudo completar la operación.")
                };
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627)
            { tr.Rollback(); return (-1, "Violación de unicidad."); }
            catch (Exception ex)
            { tr.Rollback(); return (0, $"Error: {ex.Message}"); }
        }
    }
}
