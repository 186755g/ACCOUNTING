using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Hesabati.Server.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly AuthService _authService;
    private readonly AuditLogService _auditLogService;

    public AuthController(AppDbContext db, AuthService authService, AuditLogService auditLogService)
    {
        _db = db;
        _authService = authService;
        _auditLogService = auditLogService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            var result = await _authService.RegisterAsync(request);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        try
        {
            var result = await _authService.LoginAsync(request);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return Unauthorized(new { error = ex.Message });
        }
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshRequest request)
    {
        try
        {
            var result = await _authService.RefreshAsync(request);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return Unauthorized(new { error = ex.Message });
        }
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var userIdClaim = User.FindFirst("sub");
        if (userIdClaim is null)
        {
            return Unauthorized();
        }

        var userId = Guid.Parse(userIdClaim.Value);
        var sessionIdClaim = User.FindFirst("session_id");
        if (sessionIdClaim is not null)
        {
            await _authService.RevokeSessionAsync(userId, Guid.Parse(sessionIdClaim.Value), "logout");
        }

        await _auditLogService.WriteAsync(
            AuditAction.UserLoggedOut,
            actorType: "user",
            userId: userId,
            deviceId: null,
            storeId: null,
            sessionId: sessionIdClaim is null ? null : Guid.Parse(sessionIdClaim.Value),
            targetType: nameof(UserSession),
            targetId: sessionIdClaim?.Value ?? string.Empty,
            reason: "user_logout",
            details: null);

        return Ok(new { success = true });
    }
}
