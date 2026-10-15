using System.Security.Cryptography;
using System.Text;
using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Hesabati.Server.Options;
using Hesabati.Server.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("Missing required database connection string 'ConnectionStrings:DefaultConnection'. Set it via environment variable 'ConnectionStrings__DefaultConnection' or a secure secret store.");
}

var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwtOptions.Key) || jwtOptions.Key.Length < 32)
{
    throw new InvalidOperationException("Missing or invalid JWT signing key. Set environment variable 'Jwt__Key' to a secure value of at least 32 characters in a secure secret store.");
}

builder.WebHost.ConfigureKestrel(options =>
{
    // Current Sync Push contract allows up to 200 events, with each payload capped at 64 KiB.
    // 200 * 64 KiB = 12.8 MiB, plus JSON overhead and multiple payloads in one request.
    // A 16 MiB limit keeps the server protected without being unnecessarily tight for the current design.
    options.Limits.MaxRequestBodySize = 16 * 1024 * 1024;
});

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.MaxDepth = 16;
    });

builder.Services.AddOpenApi();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Key)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var db = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
                var userIdClaim = context.Principal?.FindFirst("sub");
                var deviceIdClaim = context.Principal?.FindFirst("device_id");
                var sessionIdClaim = context.Principal?.FindFirst("session_id");

                if (userIdClaim is null || !Guid.TryParse(userIdClaim.Value, out var userId)
                    || deviceIdClaim is null || !Guid.TryParse(deviceIdClaim.Value, out var deviceId)
                    || sessionIdClaim is null || !Guid.TryParse(sessionIdClaim.Value, out var sessionId))
                {
                    context.Fail("auth_invalid_token_context");
                    return;
                }

                var user = await db.Users.SingleOrDefaultAsync(x => x.Id == userId && x.IsActive);
                if (user is null)
                {
                    context.Fail("user_inactive");
                    return;
                }

                var device = await db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId && x.Status == DeviceStatus.Active);
                if (device is null)
                {
                    context.Fail("auth_device_revoked");
                    return;
                }

                var session = await db.UserSessions.SingleOrDefaultAsync(x => x.Id == sessionId && x.UserId == userId && x.DeviceId == deviceId && x.Status == SessionStatus.Active);
                if (session is null)
                {
                    context.Fail("auth_session_revoked");
                    return;
                }

                var authorizationHeader = context.Request.Headers.Authorization.ToString();
                if (!authorizationHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                {
                    context.Fail("auth_missing_bearer_token");
                    return;
                }

                var rawToken = authorizationHeader["Bearer ".Length..].Trim();
                if (string.IsNullOrWhiteSpace(rawToken))
                {
                    context.Fail("auth_missing_bearer_token");
                    return;
                }

                var accessTokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawToken)));
                if (!string.Equals(session.AccessTokenHash, accessTokenHash, StringComparison.OrdinalIgnoreCase))
                {
                    context.Fail("auth_session_invalid");
                    return;
                }

                if (session.ExpiresAtUtc <= DateTime.UtcNow)
                {
                    context.Fail("auth_session_expired");
                    return;
                }
            }
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<StoreAccessService>();
builder.Services.AddScoped<SyncSequencingService>();
builder.Services.AddScoped<AuditLogService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseHttpsRedirection();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
