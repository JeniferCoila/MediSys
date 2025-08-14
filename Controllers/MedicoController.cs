using Microsoft.AspNetCore.Mvc;

namespace AplicacionCitasMedicasDB.Controllers
{
    public class MedicoController : Controller
    {
        public IActionResult Menu()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            return View();
        }
    }
}
