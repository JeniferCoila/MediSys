using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace AplicacionCitasMedicasDB.Filtros
{
    public class AdministradorAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuting(ActionExecutingContext context)
        {
            var rol = context.HttpContext.Session.GetString("rol");

            var username = context.HttpContext.Session.GetString("username");

            if (string.IsNullOrEmpty(username) || rol != "Administrador" )
            {
                context.Result = new RedirectToActionResult("Index", "Home", null);
                return;
            }
            base.OnActionExecuting(context);
        }
    }
}
