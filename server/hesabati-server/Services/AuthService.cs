using System.Data;
using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Services;

public sealed class RegisterRequest
{
    public string Email { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public sealed class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string DeviceKey { get; set; } = string.Empty;
    public string DeviceName { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
}

public sealed class RefreshRequest
{
    public string RefreshToken { get; set; } = string.Empty;
    public Guid DeviceId { get; set; }
}

public sealed class AuthResult
{
    public Guid UserId { get; set; }
    public Guid SessionId { get; set; }
    public Guid DeviceId { get; set; }
    public string AccessToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
}

public class AuthService
{
    private readonly AppDbContext _db;
    private readonly TokenService _tokenService;
    private readonly AuditLogService _auditLogService;

    public AuthService(AppDbContext db, TokenService tokenService, AuditLogService auditLogService)
    {
        _db = db;
        _tokenService = tokenService;
        _auditLogService = auditLogService;
    }

    public async Task<AuthResult> RegisterAsync(RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
        {
            throw new InvalidOperationException("email-and-password-required");
        }

        if (await _db.Users.AnyAsync(x => x.Email == request.Email))
        {
            throw new InvalidOperationException("duplicate-email");
        }

        if (!string.IsNullOrWhiteSpace(request.PhoneNumber) && await _db.Users.AnyAsync(x => x.PhoneNumber == request.PhoneNumber))
        {
            throw new InvalidOperationException("duplicate-phone");
        }

        var user = new User
        {
            Email = request.Email.Trim(),
            PhoneNumber = request.PhoneNumber.Trim(),
            DisplayName = string.IsNullOrWhiteSpace(request.DisplayName) ? request.Email : request.DisplayName.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            IsActive = true,
            CreatedUtc = DateTime.UtcNow
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        await _auditLogService.WriteAsync(
            AuditAction.UserRegistered,
            actorType: "system",
            userId: user.Id,
            deviceId: null,
            storeId: null,
            sessionId: null,
            targetType: nameof(User),
            targetId: user.Id.ToString(),
            reason: "user_registered",
            details: null);

        return new AuthResult { UserId = user.Id, SessionId = Guid.Empty, DeviceId = Guid.Empty, AccessToken = string.Empty, RefreshToken = string.Empty, ExpiresAtUtc = DateTime.UtcNow };
    }

    public async Task<AuthResult> LoginAsync(LoginRequest request)
    {
        var user = await _db.Users.FirstOrDefaultAsync(x => x.Email == request.Email && x.IsActive);
        if (user is null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            throw new InvalidOperationException("auth_invalid_credentials");
        }

        var deviceKey = string.IsNullOrWhiteSpace(request.DeviceKey) ? Guid.NewGuid().ToString("N") : request.DeviceKey.Trim();
        var device = await _db.Devices.SingleOrDefaultAsync(x => x.UserId == user.Id && x.DeviceKey == deviceKey);

        if (device is not null)
        {
            if (device.Status == DeviceStatus.Revoked || device.Status == DeviceStatus.RebindPending)
            {
                throw new InvalidOperationException("auth_device_revoked");
            }
        }
        else
        {
            device = new Device
            {
                UserId = user.Id,
                DeviceKey = deviceKey,
                DeviceName = string.IsNullOrWhiteSpace(request.DeviceName) ? "Unknown Device" : request.DeviceName.Trim(),
                Platform = string.IsNullOrWhiteSpace(request.Platform) ? "unknown" : request.Platform.Trim(),
                Status = DeviceStatus.Active,
                CreatedUtc = DateTime.UtcNow
            };

            _db.Devices.Add(device);
            await _db.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                AuditAction.DeviceRegistered,
                actorType: "system",
                userId: user.Id,
                deviceId: device.Id,
                storeId: null,
                sessionId: null,
                targetType: nameof(Device),
                targetId: device.Id.ToString(),
                reason: "device_registered_on_login",
                details: null);
        }

        var sessionId = Guid.NewGuid();
        var accessToken = _tokenService.CreateAccessToken(user.Id, device.Id, sessionId, Guid.Empty);
        var refreshToken = _tokenService.CreateRefreshToken();
        var refreshTokenHash = _tokenService.HashToken(refreshToken);

        var session = new UserSession
        {
            Id = sessionId,
            UserId = user.Id,
            DeviceId = device.Id,
            StoreId = null,
            AccessTokenHash = _tokenService.HashToken(accessToken),
            RefreshTokenHash = refreshTokenHash,
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(15),
            Status = SessionStatus.Active,
            CreatedUtc = DateTime.UtcNow
        };

        var refreshRecord = new RefreshToken
        {
            UserId = user.Id,
            DeviceId = device.Id,
            StoreId = null,
            TokenHash = refreshTokenHash,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(14),
            CreatedUtc = DateTime.UtcNow,
            ReuseCount = 0
        };

        _db.UserSessions.Add(session);
        _db.RefreshTokens.Add(refreshRecord);
        await _db.SaveChangesAsync();

        await _auditLogService.WriteAsync(
            AuditAction.UserLoggedIn,
            actorType: "user",
            userId: user.Id,
            deviceId: device.Id,
            storeId: null,
            sessionId: session.Id,
            targetType: nameof(UserSession),
            targetId: session.Id.ToString(),
            reason: "user_login",
            details: null);

        return new AuthResult
        {
            UserId = user.Id,
            SessionId = session.Id,
            DeviceId = device.Id,
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresAtUtc = session.ExpiresAtUtc
        };
    }

    public async Task<AuthResult> RefreshAsync(RefreshRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            throw new InvalidOperationException("auth_invalid_refresh_token");
        }

        var tokenHash = _tokenService.HashToken(request.RefreshToken.Trim());
        using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

        try
        {
            var refreshToken = await _db.RefreshTokens
                .SingleOrDefaultAsync(x => x.TokenHash == tokenHash && x.DeviceId == request.DeviceId);

            if (refreshToken is null)
            {
                throw new InvalidOperationException("auth_session_revoked");
            }

            if (refreshToken.RevokedAtUtc is not null)
            {
                throw new InvalidOperationException(refreshToken.RevocationReason == "refresh-token-reused" ? "auth_refresh_reused" : "auth_session_revoked");
            }

            if (refreshToken.ExpiresAtUtc <= DateTime.UtcNow)
            {
                throw new InvalidOperationException("auth_session_revoked");
            }

            var user = await _db.Users.SingleOrDefaultAsync(x => x.Id == refreshToken.UserId && x.IsActive);
            if (user is null)
            {
                throw new InvalidOperationException("user_inactive");
            }

            var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == request.DeviceId && x.UserId == user.Id && x.Status == DeviceStatus.Active);
            if (device is null)
            {
                throw new InvalidOperationException("auth_device_revoked");
            }

            refreshToken.ReuseCount += 1;
            refreshToken.RevokedAtUtc = DateTime.UtcNow;
            refreshToken.RevocationReason = "refresh-token-rotated";

            var sessionId = Guid.NewGuid();
            var newAccessToken = _tokenService.CreateAccessToken(user.Id, device.Id, sessionId, Guid.Empty);
            var newRefreshToken = _tokenService.CreateRefreshToken();
            var newRefreshHash = _tokenService.HashToken(newRefreshToken);

            var newSession = new UserSession
            {
                Id = sessionId,
                UserId = user.Id,
                DeviceId = device.Id,
                StoreId = null,
                AccessTokenHash = _tokenService.HashToken(newAccessToken),
                RefreshTokenHash = newRefreshHash,
                ExpiresAtUtc = DateTime.UtcNow.AddMinutes(15),
                Status = SessionStatus.Active,
                CreatedUtc = DateTime.UtcNow
            };

            var rotation = new RefreshToken
            {
                UserId = user.Id,
                DeviceId = device.Id,
                StoreId = null,
                TokenHash = newRefreshHash,
                ExpiresAtUtc = DateTime.UtcNow.AddDays(14),
                CreatedUtc = DateTime.UtcNow,
                ReuseCount = 0
            };

            _db.UserSessions.Add(newSession);
            _db.RefreshTokens.Add(rotation);

            await _auditLogService.WriteAsync(
                AuditAction.RefreshTokenRotated,
                actorType: "system",
                userId: user.Id,
                deviceId: device.Id,
                storeId: null,
                sessionId: newSession.Id,
                targetType: nameof(RefreshToken),
                targetId: rotation.Id.ToString(),
                reason: "refresh-token-rotated",
                details: null);

            await _db.SaveChangesAsync();
            await transaction.CommitAsync();

            return new AuthResult
            {
                UserId = user.Id,
                SessionId = newSession.Id,
                DeviceId = device.Id,
                AccessToken = newAccessToken,
                RefreshToken = newRefreshToken,
                ExpiresAtUtc = newSession.ExpiresAtUtc
            };
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task RevokeSessionAsync(Guid userId, Guid sessionId, string reason)
    {
        using var transaction = await _db.Database.BeginTransactionAsync();

        try
        {
            var session = await _db.UserSessions.SingleOrDefaultAsync(x => x.Id == sessionId && x.UserId == userId);
            if (session is null)
            {
                return;
            }

            session.Status = SessionStatus.Revoked;
            session.RevokedAtUtc = DateTime.UtcNow;
            session.RevokedReason = reason;

            var activeRefreshTokens = await _db.RefreshTokens
                .Where(x => x.UserId == userId && x.DeviceId == session.DeviceId && x.RevokedAtUtc == null && x.ExpiresAtUtc > DateTime.UtcNow)
                .ToListAsync();

            foreach (var refreshToken in activeRefreshTokens)
            {
                refreshToken.RevokedAtUtc = DateTime.UtcNow;
                refreshToken.RevocationReason = reason;
            }

            await _auditLogService.WriteAsync(
                AuditAction.SessionRevoked,
                actorType: "user",
                userId: userId,
                deviceId: session.DeviceId,
                storeId: session.StoreId,
                sessionId: session.Id,
                targetType: nameof(UserSession),
                targetId: session.Id.ToString(),
                reason: reason,
                details: null);

            await _db.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task RevokeDeviceAsync(Guid userId, Guid deviceId, string reason)
    {
        using var transaction = await _db.Database.BeginTransactionAsync();

        try
        {
            var device = await _db.Devices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId);
            if (device is null)
            {
                return;
            }

            device.Status = DeviceStatus.Revoked;
            device.RevokedAtUtc = DateTime.UtcNow;

            var activeSessions = await _db.UserSessions
                .Where(x => x.UserId == userId && x.DeviceId == deviceId && x.Status == SessionStatus.Active)
                .ToListAsync();

            foreach (var session in activeSessions)
            {
                session.Status = SessionStatus.Revoked;
                session.RevokedAtUtc = DateTime.UtcNow;
                session.RevokedReason = reason;
            }

            var activeRefreshTokens = await _db.RefreshTokens
                .Where(x => x.UserId == userId && x.DeviceId == deviceId && x.RevokedAtUtc == null && x.ExpiresAtUtc > DateTime.UtcNow)
                .ToListAsync();

            foreach (var refreshToken in activeRefreshTokens)
            {
                refreshToken.RevokedAtUtc = DateTime.UtcNow;
                refreshToken.RevocationReason = reason;
            }

            var activeAccess = await _db.DeviceStoreAccess
                .Where(x => x.UserId == userId && x.DeviceId == deviceId && x.Status == DeviceAccessStatus.Active)
                .ToListAsync();

            foreach (var access in activeAccess)
            {
                access.Status = DeviceAccessStatus.Revoked;
                access.RevokedAtUtc = DateTime.UtcNow;
            }

            await _auditLogService.WriteAsync(
                AuditAction.DeviceRevoked,
                actorType: "user",
                userId: userId,
                deviceId: device.Id,
                storeId: null,
                sessionId: null,
                targetType: nameof(Device),
                targetId: device.Id.ToString(),
                reason: reason,
                details: "device_revoked_all_sessions_and_access");

            await _db.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }
}
