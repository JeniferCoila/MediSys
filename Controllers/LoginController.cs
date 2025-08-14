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
            //muestra form login
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Index(string username, string password) //recibe credenciales
        {
            var usuario = _usuarioDAO.ValidarLogin(username, password);

            if (usuario != null) //si existe se guarda el user y rol
            {
                HttpContext.Session.SetString("username", usuario.Username!);
                HttpContext.Session.SetString("rol", usuario.NombreRol!);

                if (usuario.NombreRol == "Administrador")
                    return RedirectToAction("Menu", "Admin");
                else if (usuario.NombreRol == "Médico")
                    return RedirectToAction("Menu", "Medico");
                else if (usuario.NombreRol == "Paciente")
                    return RedirectToAction("Menu", "Paciente");
            }

            //de ser incorrectos
            ViewBag.Error = "Usuario o contraseña incorrectos";
            return View();
        }


        public IActionResult Logout()
        {
            HttpContext.Session.Clear(); //limpia sesión
            return RedirectToAction("Index"); //redirige a login
        }

    }
}
