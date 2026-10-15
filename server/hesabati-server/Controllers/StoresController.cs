using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Hesabati.Server.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Controllers;

[ApiController]
[Route("api/v1/stores")]
[Authorize]
public class StoresController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly StoreAccessService _storeAccessService;

    public StoresController(AppDbContext db, StoreAccessService storeAccessService)
    {
        _db = db;
        _storeAccessService = storeAccessService;
    }

    [HttpGet]
    public async Task<IActionResult> GetStores()
    {
        var userId = Guid.Parse(User.FindFirst("sub")!.Value);
        var stores = await _db.StoreMemberships
            .Where(x => x.UserId == userId && x.IsActive)
            .Include(x => x.Store)
            .Select(x => x.Store)
            .ToListAsync();

        return Ok(stores);
    }

    [HttpPost]
    public async Task<IActionResult> CreateStore([FromBody] CreateStoreRequest request)
    {
        var userId = Guid.Parse(User.FindFirst("sub")!.Value);
        var store = await _storeAccessService.CreateStoreAsync(userId, request.Name, request.Currency);
        return Ok(store);
    }

    [HttpPost("{storeId}/switch")]
    public async Task<IActionResult> SwitchStore(Guid storeId, [FromBody] StoreSwitchRequest request)
    {
        var userId = Guid.Parse(User.FindFirst("sub")!.Value);
        var deviceClaim = User.FindFirst("device_id");
        if (deviceClaim is null)
        {
            return Unauthorized();
        }

        if (request.StoreId != Guid.Empty && request.StoreId != storeId)
        {
            return BadRequest(new { error = "store_id_mismatch" });
        }

        await _storeAccessService.ValidateStoreAccessAsync(userId, Guid.Parse(deviceClaim.Value), storeId);
        return Ok(new { storeId, switched = true });
    }
}

public sealed class CreateStoreRequest
{
    public string Name { get; set; } = string.Empty;
    public string Currency { get; set; } = "EGP";
}
