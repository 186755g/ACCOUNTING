using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Services;

public sealed class StoreSwitchRequest
{
    public Guid StoreId { get; set; }
}

public sealed class DeviceRebindRequest
{
    public Guid DeviceId { get; set; }
    public string Reason { get; set; } = string.Empty;
}

public class StoreAccessService
{
    private readonly AppDbContext _db;
    private readonly AuditLogService _auditLogService;

    public StoreAccessService(AppDbContext db, AuditLogService auditLogService)
    {
        _db = db;
        _auditLogService = auditLogService;
    }

    public async Task<Store> CreateStoreAsync(Guid userId, string name, string currency)
    {
        var user = await _db.Users.SingleOrDefaultAsync(x => x.Id == userId && x.IsActive);
        if (user is null)
        {
            throw new InvalidOperationException("user_inactive");
        }

        var store = new Store
        {
            Name = name,
            Currency = string.IsNullOrWhiteSpace(currency) ? "EGP" : currency,
            OwnerUserId = userId,
            IsActive = true,
            CreatedUtc = DateTime.UtcNow
        };

        _db.Stores.Add(store);
        _db.StoreMemberships.Add(new StoreMembership
        {
            StoreId = store.Id,
            UserId = userId,
            Role = StoreRole.Owner,
            IsActive = true,
            CreatedUtc = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();

        await _auditLogService.WriteAsync(
            AuditAction.StoreCreated,
            actorType: "user",
            userId: userId,
            deviceId: null,
            storeId: store.Id,
            sessionId: null,
            targetType: nameof(Store),
            targetId: store.Id.ToString(),
            reason: "store_created",
            details: null);

        return store;
    }

    public async Task ValidateStoreAccessAsync(Guid userId, Guid deviceId, Guid requestedStoreId)
    {
        var store = await _db.Stores.SingleOrDefaultAsync(x => x.Id == requestedStoreId && x.IsActive);
        if (store is null)
        {
            throw new InvalidOperationException("store_not_found");
        }

        var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId);
        if (device is null || device.Status != DeviceStatus.Active)
        {
            throw new InvalidOperationException("auth_device_revoked");
        }

        var membership = await _db.StoreMemberships.SingleOrDefaultAsync(x => x.UserId == userId && x.StoreId == requestedStoreId && x.IsActive);
        if (membership is null)
        {
            throw new InvalidOperationException("store_membership_required");
        }

        var access = await _db.DeviceStoreAccess.SingleOrDefaultAsync(x => x.DeviceId == deviceId && x.StoreId == requestedStoreId && x.UserId == userId && x.Status == DeviceAccessStatus.Active);
        if (access is null)
        {
            throw new InvalidOperationException("auth_store_access_denied");
        }
    }

    public async Task GrantDeviceAccessAsync(Guid userId, Guid deviceId, Guid storeId)
    {
        var store = await _db.Stores.SingleOrDefaultAsync(x => x.Id == storeId && x.IsActive);
        if (store is null)
        {
            throw new InvalidOperationException("store_not_found");
        }

        var membership = await _db.StoreMemberships.SingleOrDefaultAsync(x => x.UserId == userId && x.StoreId == storeId && x.IsActive);
        if (membership is null)
        {
            throw new InvalidOperationException("store_membership_required");
        }

        if (membership.Role != StoreRole.Owner)
        {
            throw new InvalidOperationException("store_owner_required");
        }

        var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId && x.Status == DeviceStatus.Active);
        if (device is null)
        {
            throw new InvalidOperationException("auth_device_revoked");
        }

        var existing = await _db.DeviceStoreAccess.SingleOrDefaultAsync(x => x.DeviceId == deviceId && x.StoreId == storeId && x.UserId == userId);
        if (existing is null)
        {
            existing = new DeviceStoreAccess
            {
                DeviceId = deviceId,
                StoreId = storeId,
                UserId = userId,
                Status = DeviceAccessStatus.Active,
                CreatedUtc = DateTime.UtcNow
            };
            _db.DeviceStoreAccess.Add(existing);
        }
        else
        {
            existing.Status = DeviceAccessStatus.Active;
            existing.RevokedAtUtc = null;
        }

        await _db.SaveChangesAsync();

        await _auditLogService.WriteAsync(
            AuditAction.StoreAccessGranted,
            actorType: "user",
            userId: userId,
            deviceId: deviceId,
            storeId: storeId,
            sessionId: null,
            targetType: nameof(DeviceStoreAccess),
            targetId: existing.Id.ToString(),
            reason: "store_access_granted",
            details: null);
    }

    public async Task RevokeDeviceAccessAsync(Guid userId, Guid deviceId, Guid storeId, string reason)
    {
        var store = await _db.Stores.SingleOrDefaultAsync(x => x.Id == storeId && x.IsActive);
        if (store is null)
        {
            throw new InvalidOperationException("store_not_found");
        }

        var membership = await _db.StoreMemberships.SingleOrDefaultAsync(x => x.UserId == userId && x.StoreId == storeId && x.IsActive);
        if (membership is null)
        {
            throw new InvalidOperationException("store_membership_required");
        }

        if (membership.Role != StoreRole.Owner)
        {
            throw new InvalidOperationException("store_owner_required");
        }

        var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId && x.Status == DeviceStatus.Active);
        if (device is null)
        {
            throw new InvalidOperationException("auth_device_revoked");
        }

        var access = await _db.DeviceStoreAccess.SingleOrDefaultAsync(x => x.DeviceId == deviceId && x.StoreId == storeId && x.UserId == userId);
        if (access is null)
        {
            return;
        }

        access.Status = DeviceAccessStatus.Revoked;
        access.RevokedAtUtc = DateTime.UtcNow;

        await _auditLogService.WriteAsync(
            AuditAction.StoreAccessRevoked,
            actorType: "user",
            userId: userId,
            deviceId: deviceId,
            storeId: storeId,
            sessionId: null,
            targetType: nameof(DeviceStoreAccess),
            targetId: access.Id.ToString(),
            reason: reason,
            details: null);

        await _db.SaveChangesAsync();
    }

    public async Task RebindRevokedDeviceAsync(Guid userId, Guid deviceId, string reason)
    {
        var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId);
        if (device is null)
        {
            throw new InvalidOperationException("device_not_registered");
        }

        if (device.Status != DeviceStatus.Revoked)
        {
            throw new InvalidOperationException("device_rebind_required");
        }

        device.Status = DeviceStatus.RebindPending;
        device.RebindApprovedUtc = null;

        await _auditLogService.WriteAsync(
            AuditAction.DeviceRebound,
            actorType: "user",
            userId: userId,
            deviceId: device.Id,
            storeId: null,
            sessionId: null,
            targetType: nameof(Device),
            targetId: device.Id.ToString(),
            reason: reason,
            details: "revoked-device-rebind-requested");

        await _db.SaveChangesAsync();
    }
}
