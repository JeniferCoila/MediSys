using AplicacionCitasMedicasDB.Repositorio;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();
builder.Services.AddSession();
//Cuando necesite IUsuario dale una instancia de UsuarioDAO
builder.Services.AddScoped<IUsuario, UsuarioDAO>();
builder.Services.AddScoped<IPaciente, PacienteDAO>();
builder.Services.AddScoped<IMedico, MedicoDAO>();
builder.Services.AddScoped<IEspecialidad, EspecialidadDAO>();


var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();
app.UseSession(); //ACTIVAR SESIONES

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Login}/{action=Index}/{id?}");

app.Run();
