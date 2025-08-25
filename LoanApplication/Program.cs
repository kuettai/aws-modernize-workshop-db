using Microsoft.EntityFrameworkCore;
using LoanApplication.Data;
using LoanApplication.Services;
using LoanApplication.Repositories;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();

// Add Entity Framework
builder.Services.AddDbContext<LoanApplicationContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register context factory for read replica support
builder.Services.AddScoped<ApplicationDbContextFactory>();

// Add repositories
builder.Services.AddScoped<IApplicationRepository, ApplicationRepository>();
builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();

// Add services
builder.Services.AddScoped<ILoanService, LoanService>();
builder.Services.AddScoped<IDSRCalculationService, DSRCalculationService>();
builder.Services.AddScoped<ICreditCheckService, CreditCheckService>();
builder.Services.AddScoped<IReportingService, ReportingService>();

// Add memory cache for reporting
builder.Services.AddMemoryCache();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();