using AplicacionCitasMedicasDB.Filtros;
using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Microsoft.AspNetCore.Mvc;


namespace AplicacionCitasMedicasDB.Controllers
{

    [Administrador]
    public class AdminController : Controller
    {
        private readonly IBajasMedico _bajasMedicoDAO;
        private readonly IBajasPaciente _bajasPacienteDAO;

        private readonly IDashboardDAO _dashboardDAO;


        private const int PageSize = 15;

        public AdminController(
            IBajasMedico bajasMedicoDAO,
            IBajasPaciente bajasPacienteDAO,
            IDashboardDAO dashboardDAO)
        {
            _bajasMedicoDAO = bajasMedicoDAO;
            _bajasPacienteDAO = bajasPacienteDAO;
            _dashboardDAO = dashboardDAO;

        }

        public IActionResult Menu()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");
            var vm = _dashboardDAO.Build();

            return View(vm);
        }

        /* VISTA PARA LISTAR MEDICOS DADOS DE BAJA */
        [HttpGet]
        public async Task<IActionResult> ListadoMedicosBajas(string? filtro, int page = 1)
        {
          
 
            ViewBag.Filtro = filtro;

            var lista = await Task.Run(() => _bajasMedicoDAO.GetAllBajas(filtro));
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

 
        /* METODO PARA ACTIVAR MEDICO */
        [HttpPost]
        public async Task<IActionResult> ActivarMedico(int id, string? filtro, int page = 1)
        {
            Medico medico = await Task.Run(() => _bajasMedicoDAO.SearchMedicoBaja(id));
            if (medico == null)
            {
                TempData["mensaje"] = "El médico no existe o ya está activo.";
                return RedirectToAction(nameof(ListadoMedicosBajas));
            }
            var result = await Task.Run(() => _bajasMedicoDAO.activar(medico));
            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(ListadoMedicosBajas), new { filtro, page });

        }




        /* VISTA PARA LISTAR PACIENTES DADOS DE BAJA */
        [HttpGet]
        public async Task<IActionResult> ListadoPacientesBajas(string? filtro, int page = 1)
        {


            ViewBag.Filtro = filtro;

            var lista = await Task.Run(() => _bajasPacienteDAO.GetAllBajas(filtro));
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


        /* METODO PARA ACTIVAR MEDICO */
        [HttpPost]
        public async Task<IActionResult> ActivarPaciente(int id, string? filtro, int page = 1)
        {
            Paciente paciente = await Task.Run(() => _bajasPacienteDAO.SearchPacienteBaja(id));
            if (paciente == null)
            {
                TempData["mensaje"] = "El paciente no existe o ya está activo.";
                return RedirectToAction(nameof(ListadoPacientesBajas));
            }
            var result = await Task.Run(() => _bajasPacienteDAO.activar(paciente));
            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(ListadoPacientesBajas), new { filtro, page });

        }




    }
}
