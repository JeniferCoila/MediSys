using Microsoft.AspNetCore.Mvc;
using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;


namespace AplicacionCitasMedicasDB.Controllers
{
    public class LoginController : Controller
    {

        private readonly IUsuario _usuarioDAO;

        //Inyecta dependencia IUsuario en constructor para acceder a métodos
        public LoginController(IUsuario usuarioDAO)
        {
            _usuarioDAO = usuarioDAO;
        }


        [HttpGet]
        public IActionResult Index()
        {
            // Verifica si ya hay sesión activa
            var rol = HttpContext.Session.GetString("rol");

            if (!string.IsNullOrEmpty(rol))
            {
                // Redirige directamente al menú según el rol
                return rol switch
                {
                    "Administrador" => RedirectToAction("Menu", "Admin"),
                    "Médico" => RedirectToAction("Menu", "Medico"),
                    "Paciente" => RedirectToAction("Menu", "Paciente"),
                    _ => RedirectToAction("Index", "Home")
                };
            }

            // Si no hay sesión → muestra form de login
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Index(string username, string password) //recibe credenciales
        {
            var usuario = _usuarioDAO.ValidarLogin(username, password);

            if (usuario == null)
            {
                ViewBag.Error = "Usuario o contraseña incorrectos";
                return View();
            }

            // Guardar en sesión
            HttpContext.Session.SetString("username", usuario.Username ?? string.Empty);
            HttpContext.Session.SetString("rol", usuario.NombreRol ?? string.Empty);

            // Decidir destino según rol
            return usuario.NombreRol switch
            {
                "Administrador" => RedirectToAction("Menu", "Admin"),
                "Médico" => RedirectToAction("Menu", "Medico"),
                "Paciente" => RedirectToAction("Menu", "Paciente"),
                _ => RedirectToAction("Index", "Home") // fallback por si llega algo inesperado
            };
        }

        public IActionResult Logout()
        {
            HttpContext.Session.Clear(); //limpia sesión
            return RedirectToAction("Index"); //redirige a login
        }

    }
}
