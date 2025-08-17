using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Azure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using System.Reflection;

namespace AplicacionCitasMedicasDB.Controllers
{
    public class MedicoController : Controller
    {

        private readonly IMedico _medicoDAO;
        private readonly IEspecialidad _espDAO;

        public MedicoController(IMedico medicoDAO, IEspecialidad espDAO)
        {
            _medicoDAO = medicoDAO;
            _espDAO = espDAO;
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

            const int pageSize = 15;

            var medicos = await Task.Run(() => _medicoDAO.GetAll(filtro ?? string.Empty));
            var ordered = medicos.OrderBy(m => m.IdMedico).ToList();

            int totalRegistros = ordered.Count;
            int totalPaginas = (int)Math.Ceiling(totalRegistros / (double)pageSize);
            if (totalPaginas == 0) totalPaginas = 1;
            if (page < 1) page = 1;
            if (page > totalPaginas) page = totalPaginas;

            var pagina = ordered.Skip((page - 1) * pageSize).Take(pageSize).ToList();

            ViewBag.Filtro = filtro ?? string.Empty;
            ViewBag.PaginaActual = page;
            ViewBag.TotalPaginas = totalPaginas;
            ViewBag.TotalRegistros = totalRegistros;

            return View(pagina);
        }

        private void CargarEspecialidades()
        {
            var lista = _espDAO.GetAll();
            ViewBag.Especialidades = new SelectList(lista, "IdEspecialidad", "Nombre");
        }

        private void CargarEspecialidades(int? selectedId)
        {
            var lista = _espDAO.GetAll();
            ViewBag.Especialidades = new SelectList(lista, "IdEspecialidad", "Nombre", selectedId);
        }


        [HttpGet]
        public IActionResult Crear()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            CargarEspecialidades();
            return View();
        }


        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Crear(Medico medico)
        {

            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            if (!ModelState.IsValid)
            {
                CargarEspecialidades();
                return View(medico);
            }

            var result = await Task.Run(() => _medicoDAO.Add(medico));

            if (result.code == -1)
            {
                ModelState.AddModelError("CMP", result.message);
                CargarEspecialidades();
                return View(medico);
            }
            if (result.code == -2)
            {
                ModelState.AddModelError(string.Empty, result.message);
                CargarEspecialidades();
                return View(medico);
            }
            if (result.code != 1)
            {
                ModelState.AddModelError(string.Empty, result.message);
                CargarEspecialidades();
                return View(medico);
            }

            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(Listado));


        }

        // 
        [HttpGet]
        public async Task<IActionResult> Editar(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var medico = await Task.Run(() => _medicoDAO.Search(id));
            if (medico is null) return NotFound();

            CargarEspecialidades(medico.IdEspecialidad);
            return View(medico);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Editar(Medico medico, string? filtro, int page = 1)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            if (!ModelState.IsValid)
            {
                CargarEspecialidades(medico.IdEspecialidad);
                return View(medico);
            }

            var (code, message) = await Task.Run(() => _medicoDAO.Update(medico));

            if (code != 1)
            {
                // Uniformidad con Pacientes:
                if (code == -1) ModelState.AddModelError("CMP", message);       
                else if (code == -2) ModelState.AddModelError(string.Empty, message); 
                else ModelState.AddModelError(string.Empty, message);             

                CargarEspecialidades(medico.IdEspecialidad);
                return View(medico);
            }

            TempData["mensaje"] = message;
            return RedirectToAction(nameof(Listado), new { filtro, page });
        }


        // GET:
        [HttpGet]
        public async Task<IActionResult> Detalle(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var medico = await Task.Run(() => _medicoDAO.Search(id));
            if (medico == null) return NotFound();

            return View(medico);
        }

        // ===== ELIMINAR (BAJA LÓGICA) =====
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Eliminar(int id, string? filtro, int page = 1)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var msg = await Task.Run(() => _medicoDAO.Delete(new Medico { IdMedico = id }));
            TempData["mensaje"] = msg;

            // Volver al mismo filtro/página
            return RedirectToAction(nameof(Listado), new { filtro, page });
        }

    }
}
