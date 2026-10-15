using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;

namespace Hesabati.Server.Services;

public class AuditLogService
{
    private readonly AppDbContext _db;

    public AuditLogService(AppDbContext db)
    {
        _db = db;
    }

    public Task WriteAsync(
        AuditAction action,
        string actorType,
        Guid? userId,
        Guid? deviceId,
        Guid? storeId,
        Guid? sessionId,
        string targetType,
        string targetId,
        string? reason,
        string? details)
    {
        var entry = new AuditLogEntry
        {
            Action = action,
            ActorType = actorType,
            UserId = userId,
            DeviceId = deviceId,
            StoreId = storeId,
            SessionId = sessionId,
            TargetType = targetType,
            TargetId = targetId,
            Reason = reason,
            Details = details,
            CreatedUtc = DateTime.UtcNow
        };

        _db.AuditLogs.Add(entry);
        return Task.CompletedTask;
    }
}
