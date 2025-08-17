using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Microsoft.AspNetCore.Mvc;

namespace AplicacionCitasMedicasDB.Controllers
{
    public class MedicoController : Controller
    {

        private readonly IMedico _medicoDAO;
        private readonly IEspecialidad _especialidadDAO;
        private const int PageSize = 15;

        public MedicoController(IMedico medicoDAO, IEspecialidad especialidadDAO)
        {
            _medicoDAO = medicoDAO;
            _especialidadDAO = especialidadDAO;
        }


        /* -- MEDICO -- */
        public IActionResult Menu()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            return View();
        }

        /* ----------- LISTADO ----------- */
        [HttpGet]
        public async Task<IActionResult> Listado(string? filtro, int page = 1)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            ViewBag.Filtro = filtro;

            var lista = await Task.Run(() => _medicoDAO.GetAll(filtro));
            int total = lista.Count();
            int totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)PageSize));
            page = Math.Clamp(page, 1, totalPages);

            var medicosPagina = lista.Skip((page - 1) * PageSize).Take(PageSize).ToList();

            ViewBag.PaginaActual = page;
            ViewBag.TotalPaginas = totalPages;
            ViewBag.TotalRegistros = total;
            ViewBag.PageSize = PageSize;

            return View(medicosPagina);
        }

        /* ----------- CREAR ----------- */
        //Vista para crear un nuevo médico
        [HttpGet]
        public IActionResult Crear()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");


            ViewBag.Especialidades = _especialidadDAO.GetAll();
            return View(new Medico());
        }

        // Procesar el formulario de creacion
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Crear(Medico medico)
        {
            // ModelState.Remove(nameof(Medico.NombreEspecialidad));

            if (!ModelState.IsValid)
            {
                ViewBag.Especialidades = _especialidadDAO.GetAll();
                return View(medico);
            }
            var result = await Task.Run(() => _medicoDAO.Add(medico));

            if (result.code == -1)
            {
                ViewBag.Especialidades = _especialidadDAO.GetAll();
                ModelState.AddModelError("CMP", result.message);
                return View(medico);
            }
            if (result.code == -2)
            {
                ViewBag.Especialidades = _especialidadDAO.GetAll();
                ModelState.AddModelError(string.Empty, result.message);
                return View(medico);
            }
            if (result.code != 1)
            {
                ViewBag.Especialidades = _especialidadDAO.GetAll();
                ModelState.AddModelError(string.Empty, result.message);
                return View(medico);
            }

            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(Listado));


        }

        /* ----------- EDITAR----------- */
        [HttpGet]
        public async Task<IActionResult> Editar(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var medico = await Task.Run(() => _medicoDAO.Search(id));
            if (medico == null)
            {
                return RedirectToAction(nameof(Listado));
            }
            ViewBag.Especialidades = _especialidadDAO.GetAll();
            return View(medico);
        }

        [HttpPost]
        public async Task<IActionResult> EdItar(Medico medico)
        {
            if (!ModelState.IsValid)
            {
                return View(medico);
            }
            var result = await Task.Run(() => _medicoDAO.Update(medico));
            if (result.code == -1)
            {
                ModelState.AddModelError("CMP", result.message);
                return View(medico);
            }
            if (result.code == -2)
            {
                ModelState.AddModelError(string.Empty, result.message);
                return View(medico);
            }
            if (result.code != 1)
            {
                ModelState.AddModelError(string.Empty, result.message);
                return View(medico);
            }

            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(Listado));


        }

        /* ----------- DETALLE ----------- */
        [HttpGet]
        public async Task<IActionResult> Detalle(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");
            Medico medico = await Task.Run(() => _medicoDAO.Search(id));
            if (medico == null)
            {
                return NotFound();
            }
  

            return View(medico);
        }

        /* ----------- ELIMINAR ----------- */
        [HttpPost]
        public async Task<IActionResult> Eliminar(int id, string? filtro, int page = 1)
        {
            Medico medico = await Task.Run(() => _medicoDAO.Search(id));
            if (medico == null)
            {
                TempData["mensaje"] = "Médico no encontrado.";
                return RedirectToAction(nameof(Listado));
            }
            var msg = await Task.Run(() => _medicoDAO.Delete(medico));
            TempData["mensaje"] = msg;
            return RedirectToAction(nameof(Listado), new { filtro, page });

        }
    }
}
