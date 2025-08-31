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
                        int Ord(string col) { try { return dr.GetOrdinal(col); } catch { return -1; } }  // NUEVO
                        string? S(string col) { var i = Ord(col); return (i < 0 || dr.IsDBNull(i)) ? null : dr.GetString(i); }  // NUEVO
                        DateTime? D(string col) { var i = Ord(col); return (i < 0 || dr.IsDBNull(i)) ? (DateTime?)null : dr.GetDateTime(i); }  // NUEVO
                        int I(string col) { var i = Ord(col); return (i < 0 || dr.IsDBNull(i)) ? 0 : dr.GetInt32(i); }  // NUEVO

                        while (dr.Read())
                        {
                            listaMedicosBajas.Add(new Medico
                            {
                                IdMedico = I("IdMedico"),                 
                                CMP = S("CMP") ?? "",                
                                Nombre = S("Nombre") ?? "",             
                                Apellido = S("Apellido") ?? "",           

                                IdEspecialidad = I("IdEspecialidad"),          
                                NombreEspecialidad = S("NombreEspecialidad"),       

                                Telefono = S("Telefono"),                 
                                Correo = S("Correo"),                   
                                FotoUrl = S("FotoUrl"),                 

                                FechaCreacion = D("FechaCreacion"),            
                                FechaActualizacion = D("FechaActualizacion"),       
                                FechaBaja = D("FechaBaja")                 
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
                            // NUEVO: helpers por nombre de columna
                            int Ord(string col) { try { return dr.GetOrdinal(col); } catch { return -1; } }   // NUEVO
                            string? S(string col) { var i = Ord(col); return (i < 0 || dr.IsDBNull(i)) ? null : dr.GetString(i); }  // NUEVO
                            DateTime? D(string col) { var i = Ord(col); return (i < 0 || dr.IsDBNull(i)) ? (DateTime?)null : dr.GetDateTime(i); } // NUEVO
                            int I(string col) { var i = Ord(col); return (i < 0 || dr.IsDBNull(i)) ? 0 : dr.GetInt32(i); }  // NUEVO

                            medicoBaja = new Medico
                            {
                                IdMedico = I("IdMedico"),            // CAMBIO: antes dr.GetInt32(0)
                                CMP = S("CMP") ?? "",           // CAMBIO: antes dr.GetString(1)
                                Nombre = S("Nombre") ?? "",        // CAMBIO: antes dr.GetString(2)
                                Apellido = S("Apellido") ?? "",      // CAMBIO: antes dr.GetString(3)

                                IdEspecialidad = I("IdEspecialidad"),      // NUEVO: antes no se mapeaba
                                NombreEspecialidad = S("NombreEspecialidad"),  // CAMBIO: antes índice 4

                                Telefono = S("Telefono"),            // CAMBIO: antes índice 5
                                Correo = S("Correo"),              // CAMBIO: antes índice 6
                                FotoUrl = S("FotoUrl"),             // NUEVO: avatar en bajas

                                FechaCreacion = D("FechaCreacion"),       // NUEVO: auditoría
                                FechaActualizacion = D("FechaActualizacion"),  // NUEVO: auditoría
                                FechaBaja = D("FechaBaja")            // CAMBIO: antes índice 7
                            };
                        }
                    }
                    }
                }

                return medicoBaja;
        }
  
    }
}
