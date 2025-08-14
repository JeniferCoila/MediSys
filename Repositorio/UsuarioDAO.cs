using AplicacionCitasMedicasDB.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class UsuarioDAO : IUsuario
    {

        private readonly IConfiguration _iconfig;

        public UsuarioDAO(IConfiguration iconfig)
        {
            _iconfig = iconfig;
        }

        public Usuario? ValidarLogin(string username, string password)
        {
            Usuario? usuario = null;

            using (SqlConnection cn = new SqlConnection(_iconfig.GetConnectionString("cadena")))
            {
                using (SqlCommand cmd = new SqlCommand("usp_usuarios_login", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@username", username);
                    cmd.Parameters.AddWithValue("@password", password);

                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            usuario = new Usuario
                            {
                                IdUsuario = dr.GetInt32(0),
                                Username = dr.GetString(1),
                                IdRol = dr.GetInt32(2),
                                NombreRol = dr.GetString(3)
                            };
                        }
                    }
                }
            }

            return usuario;
        }
    }
}