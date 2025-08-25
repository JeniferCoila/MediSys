using AplicacionCitasMedicasDB.Filtros;
using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Azure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using System.Reflection;

namespace AplicacionCitasMedicasDB.Controllers
{
    [Administrador]
 
    public class MedicoController : Controller
    {

        private readonly IMedico _medicoDAO;
        private readonly IEspecialidad _espDAO;
        private readonly IWebHostEnvironment _env;

        public MedicoController(IMedico medicoDAO, IEspecialidad espDAO, IWebHostEnvironment env)
        {
            _medicoDAO = medicoDAO;
            _espDAO = espDAO;
            _env = env;
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

        /*
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Crear(Medico medico, IFormFile? foto)
        {

            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            // Validar foto obligatoria
            if (foto == null || foto.Length == 0)
                ModelState.AddModelError(string.Empty, "La foto es obligatoria.");

            // Validar extensión y tamaño
            if (foto != null)
            {
                var ext = Path.GetExtension(foto.FileName).ToLowerInvariant();
                var ok = new[] { ".jpg", ".jpeg", ".png", ".webp" }.Contains(ext);
                if (!ok) ModelState.AddModelError(string.Empty, "Formato de imagen inválido (use .jpg, .jpeg, .png o .webp).");
                if (foto.Length > 2 * 1024 * 1024) ModelState.AddModelError(string.Empty, "La imagen no debe superar 2MB.");
            }


            if (!ModelState.IsValid)
            {
                CargarEspecialidades();
                return View(medico);
            }


            // Guardar archivo en wwwroot/uploads/medicos
            var uploads = Path.Combine(_env.WebRootPath, "uploads", "medicos");
            Directory.CreateDirectory(uploads);

            var fileName = $"{medico.CMP}_{Guid.NewGuid():N}{Path.GetExtension(foto!.FileName)}";
            var filePath = Path.Combine(uploads, fileName);
            using (var fs = new FileStream(filePath, FileMode.Create))
                await foto.CopyToAsync(fs);

            // Ruta pública
            medico.FotoUrl = $"/uploads/medicos/{fileName}";



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
        */

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Crear(Medico medico, IFormFile? foto)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            // Validar foto obligatoria
            if (foto == null || foto.Length == 0)
                ModelState.AddModelError(string.Empty, "La foto es obligatoria.");

            // Validar extensión y tamaño
            if (foto != null)
            {
                var ext = Path.GetExtension(foto.FileName).ToLowerInvariant();
                var ok = new[] { ".jpg", ".jpeg", ".png", ".webp" }.Contains(ext);
                if (!ok) ModelState.AddModelError(string.Empty, "Formato de imagen inválido (use .jpg, .jpeg, .png o .webp).");
                if (foto.Length > 2 * 1024 * 1024) ModelState.AddModelError(string.Empty, "La imagen no debe superar 2MB.");
            }

            if (!ModelState.IsValid)
            {
                CargarEspecialidades();
                return View(medico);
            }

            // Preparar rutas
            var uploads = Path.Combine(_env.WebRootPath, "uploads", "medicos");
            Directory.CreateDirectory(uploads);
            var fileName = $"{medico.CMP}_{Guid.NewGuid():N}{Path.GetExtension(foto!.FileName)}";
            var filePath = Path.Combine(uploads, fileName);

            // Intentar guardar el archivo
            try
            {
                using var fs = new FileStream(filePath, FileMode.Create);
                await foto.CopyToAsync(fs);
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"No se pudo guardar la imagen: {ex.Message}");
                CargarEspecialidades();
                return View(medico);
            }

            // Ruta pública para BD
            medico.FotoUrl = $"/uploads/medicos/{fileName}";

            var result = await Task.Run(() => _medicoDAO.Add(medico));

            // Si falla el insert, eliminamos el archivo para no dejarlo huérfano
            if (result.code != 1)
            {
                try { System.IO.File.Delete(filePath); } catch { /* ignore */ }
            }

            if (result.code == -10) // foto requerida desde SP (doble seguridad)
            {
                ModelState.AddModelError(string.Empty, result.message);
                CargarEspecialidades();
                return View(medico);
            }
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
