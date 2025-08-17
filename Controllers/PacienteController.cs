using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Microsoft.AspNetCore.Mvc;
using Microsoft.CodeAnalysis.Elfie.Serialization;
using System.Reflection;

namespace AplicacionCitasMedicasDB.Controllers
{
    public class PacienteController : Controller
    {

        private readonly IPaciente _pacienteDAO;
        private const int PageSize = 15;

        public PacienteController(IPaciente pacienteDAO)
        {
            _pacienteDAO = pacienteDAO;
        }

        // ==== MENÚ PACIENTE ====
        public IActionResult Menu()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            return View();
        }

        // ==== LISTA + BÚSQUEDA + PAGINACIÓN ====
        [HttpGet]
        public async Task<IActionResult> Listado(string? filtro, int page = 1)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            ViewBag.Filtro = filtro;

            var lista = await Task.Run(() => _pacienteDAO.GetAll(filtro));
            int total = lista.Count();
            int totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)PageSize));
            page = Math.Clamp(page, 1, totalPages);

            var pacientesPagina = lista.Skip((page - 1) * PageSize).Take(PageSize).ToList();

            ViewBag.PaginaActual = page;
            ViewBag.TotalPaginas = totalPages;
            ViewBag.TotalRegistros = total;
            ViewBag.PageSize = PageSize;

            return View(pacientesPagina);
        }

        // ==== CREAR ====
        [HttpGet]
        public IActionResult Crear()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");
            return View(new Paciente());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Crear(Paciente paciente)
        {
         
            if (!ModelState.IsValid) return View(paciente);

            var result = await Task.Run(() => _pacienteDAO.Add(paciente));

            if (result.code == -1) { ModelState.AddModelError("DNI", result.message); return View(paciente); }
            if (result.code == -2) { ModelState.AddModelError(string.Empty, result.message); return View(paciente); }
            if (result.code != 1) { ModelState.AddModelError(string.Empty, result.message); return View(paciente); }

            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(Listado));


        }

        // ==== EDITAR ====
        [HttpGet]
        public async Task<IActionResult> Editar(int id)
        {
            
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var paciente = await Task.Run(() => _pacienteDAO.Search(id));
            if (paciente == null) return NotFound();
            return View(paciente);
            

        
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Editar(Paciente paciente)
        {
            /*
            // Si modelo no es válido, volver a mostrar vista con paciente
            if (!ModelState.IsValid)
                return View(paciente);

            // Ejecuta actualización  en segundo plano
            var msg = await Task.Run(() => _pacienteDAO.Update(paciente));

            // Mensaje temporal para mostrar envista
            TempData["mensaje"] = msg;

            // Redirige al listado después de actualizar
            return RedirectToAction(nameof(Listado));
            */

            if (!ModelState.IsValid) return View(paciente);

            var result = await Task.Run(() => _pacienteDAO.Update(paciente));

            if (result.code == -1) { ModelState.AddModelError("DNI", result.message); return View(paciente); }
            if (result.code == -2) { ModelState.AddModelError(string.Empty, result.message); return View(paciente); }
            if (result.code != 1) { ModelState.AddModelError(string.Empty, result.message); return View(paciente); }

            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(Listado));
        }

        // ==== DETALLE ====
        [HttpGet]
        public async Task<IActionResult> Detalle(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var paciente = await Task.Run(() => _pacienteDAO.Search(id));
            if (paciente == null) return NotFound();
            return View(paciente);
        }

        // ==== ELIMINACIÓN LÓGICA ====
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Eliminar(int id, string? filtro, int page = 1)
        {
            // Trae el paciente para validar existencia
            var paciente = await Task.Run(() => _pacienteDAO.Search(id));
            if (paciente == null)
                return NotFound();

            var msg = await Task.Run(() => _pacienteDAO.Delete(paciente));
            TempData["mensaje"] = msg;

            // Volver a lista conservando filtro/página (si los pasaste en form)
            return RedirectToAction(nameof(Listado), new { filtro, page });
        }

        // ==== CONTEO ====
        [HttpGet]
        public async Task<IActionResult> Conteo()
        {
            var total = await Task.Run(() => _pacienteDAO.Contar());
            return Json(new { total });
        }

    }
}
