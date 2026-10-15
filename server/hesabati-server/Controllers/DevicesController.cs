using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Hesabati.Server.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Controllers;

[ApiController]
[Route("api/v1/devices")]
[Authorize]
public class DevicesController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly StoreAccessService _storeAccessService;

    public DevicesController(AppDbContext db, StoreAccessService storeAccessService)
    {
        _db = db;
        _storeAccessService = storeAccessService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDeviceRequest request)
    {
        var userId = Guid.Parse(User.FindFirst("sub")!.Value);
        var deviceKey = string.IsNullOrWhiteSpace(request.DeviceKey) ? Guid.NewGuid().ToString("N") : request.DeviceKey.Trim();

        var existing = await _db.Devices.SingleOrDefaultAsync(x => x.UserId == userId && x.DeviceKey == deviceKey);
        if (existing is not null)
        {
            if (existing.Status == DeviceStatus.Revoked || existing.Status == DeviceStatus.RebindPending)
            {
                return Conflict(new { error = "auth_device_revoked" });
            }

            return Ok(existing);
        }

        var device = new Device
        {
            UserId = userId,
            DeviceKey = deviceKey,
            DeviceName = request.DeviceName,
            Platform = request.Platform,
            Status = DeviceStatus.Active,
            CreatedUtc = DateTime.UtcNow
        };

        _db.Devices.Add(device);
        await _db.SaveChangesAsync();

        return Ok(device);
    }

    [HttpPost("{deviceId}/revoke")]
    public async Task<IActionResult> Revoke(Guid deviceId, [FromBody] DeviceRebindRequest request)
    {
        var userId = Guid.Parse(User.FindFirst("sub")!.Value);
        var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId);
        if (device is null)
        {
            return NotFound();
        }

        var authService = HttpContext.RequestServices.GetRequiredService<AuthService>();
        await authService.RevokeDeviceAsync(userId, deviceId, request.Reason);

        return Ok(new { success = true, deviceId, reason = request.Reason });
    }

    [HttpPost("rebind")]
    public async Task<IActionResult> Rebind([FromBody] DeviceRebindRequest request)
    {
        var userId = Guid.Parse(User.FindFirst("sub")!.Value);
        var iatClaim = User.FindFirst("iat");
        if (iatClaim is null || !long.TryParse(iatClaim.Value, out var issuedAtUnix))
        {
            return Unauthorized(new { error = "auth_recent_auth_required" });
        }

        if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() - issuedAtUnix > 900)
        {
            return Unauthorized(new { error = "auth_recent_auth_required" });
        }

        await _storeAccessService.RebindRevokedDeviceAsync(userId, request.DeviceId, request.Reason);
        return Ok(new { success = true, deviceId = request.DeviceId, rebindRequested = true });
    }
}

public sealed class RegisterDeviceRequest
{
    public string DeviceKey { get; set; } = string.Empty;
    public string DeviceName { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
}
