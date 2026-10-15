namespace Hesabati.Server.Data.Entities;

public enum StoreRole
{
    Owner = 1
}

public enum DeviceStatus
{
    Active = 1,
    Revoked = 2,
    RebindPending = 3
}

public enum SessionStatus
{
    Active = 1,
    Revoked = 2,
    Expired = 3
}

public enum DeviceAccessStatus
{
    Active = 1,
    Revoked = 2,
    Suspended = 3
}

public enum AuditAction
{
    UserRegistered,
    UserLoggedIn,
    UserLoggedOut,
    SessionRevoked,
    RefreshTokenRotated,
    DeviceRegistered,
    DeviceRevoked,
    DeviceRebound,
    StoreCreated,
    StoreSwitched,
    StoreAccessGranted,
    StoreAccessRevoked,
    ValidationFailed
}

public enum SyncOperationResultStatus
{
    Accepted = 1,
    Rejected = 2,
    Conflict = 3,
    Duplicate = 4
}

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    public ICollection<StoreMembership> StoreMemberships { get; set; } = new List<StoreMembership>();
    public ICollection<Device> Devices { get; set; } = new List<Device>();
    public ICollection<UserSession> Sessions { get; set; } = new List<UserSession>();
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}

public class Store
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string Currency { get; set; } = "EGP";
    public Guid OwnerUserId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    public ICollection<StoreMembership> Memberships { get; set; } = new List<StoreMembership>();
    public ICollection<DeviceStoreAccess> DeviceAccess { get; set; } = new List<DeviceStoreAccess>();
    public ICollection<StoreSyncState> SyncStates { get; set; } = new List<StoreSyncState>();
    public ICollection<SyncEventLedger> SyncEvents { get; set; } = new List<SyncEventLedger>();
    public ICollection<SyncOperationResult> OperationResults { get; set; } = new List<SyncOperationResult>();
}

public class StoreSyncState
{
    public Guid StoreId { get; set; }
    public long LastEventSequence { get; set; }
    public DateTime UpdatedUtc { get; set; } = DateTime.UtcNow;

    public Store? Store { get; set; }
}

public class SyncEventLedger
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid StoreId { get; set; }
    public Guid? UserId { get; set; }
    public Guid? DeviceId { get; set; }
    public Guid? SessionId { get; set; }
    public string OperationId { get; set; } = string.Empty;
    public string OperationHash { get; set; } = string.Empty;
    public string EventId { get; set; } = string.Empty;
    public string SourceId { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public string Action { get; set; } = "create";
    public string PayloadJson { get; set; } = "{}";
    public string PayloadHash { get; set; } = string.Empty;
    public long EventSequence { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? CommittedUtc { get; set; }

    public Store? Store { get; set; }
    public User? User { get; set; }
    public Device? Device { get; set; }
    public UserSession? Session { get; set; }
}

public class SyncOperationResult
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid StoreId { get; set; }
    public Guid? UserId { get; set; }
    public Guid? DeviceId { get; set; }
    public string OperationId { get; set; } = string.Empty;
    public string OperationHash { get; set; } = string.Empty;
    public SyncOperationResultStatus ResultStatus { get; set; } = SyncOperationResultStatus.Accepted;
    public string ResultHash { get; set; } = string.Empty;
    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
    public string? AcceptedEventIdsJson { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedUtc { get; set; } = DateTime.UtcNow;

    public Store? Store { get; set; }
    public User? User { get; set; }
    public Device? Device { get; set; }
}

public class StoreMembership
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid StoreId { get; set; }
    public Guid UserId { get; set; }
    public StoreRole Role { get; set; } = StoreRole.Owner;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;

    public Store? Store { get; set; }
    public User? User { get; set; }
}

public class Device
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string DeviceKey { get; set; } = string.Empty;
    public string DeviceName { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
    public DeviceStatus Status { get; set; } = DeviceStatus.Active;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAtUtc { get; set; }
    public DateTime? RebindApprovedUtc { get; set; }

    public User? User { get; set; }
    public ICollection<DeviceSession> Sessions { get; set; } = new List<DeviceSession>();
    public ICollection<DeviceStoreAccess> StoreAccess { get; set; } = new List<DeviceStoreAccess>();
}

public class UserSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid DeviceId { get; set; }
    public Guid? StoreId { get; set; }
    public string AccessTokenHash { get; set; } = string.Empty;
    public string RefreshTokenHash { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
    public string? RevokedReason { get; set; }
    public SessionStatus Status { get; set; } = SessionStatus.Active;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
    public Device? Device { get; set; }
}

public class RefreshToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid DeviceId { get; set; }
    public Guid? StoreId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAtUtc { get; set; }
    public string? RevocationReason { get; set; }
    public int ReuseCount { get; set; }
    public bool IsActive => RevokedAtUtc is null && ExpiresAtUtc > DateTime.UtcNow;

    public User? User { get; set; }
    public Device? Device { get; set; }
}

public class DeviceSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DeviceId { get; set; }
    public Guid StoreId { get; set; }
    public Guid UserId { get; set; }
    public string SessionKey { get; set; } = string.Empty;
    public SessionStatus Status { get; set; } = SessionStatus.Active;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }

    public Device? Device { get; set; }
    public Store? Store { get; set; }
}

public class DeviceStoreAccess
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DeviceId { get; set; }
    public Guid StoreId { get; set; }
    public Guid UserId { get; set; }
    public DeviceAccessStatus Status { get; set; } = DeviceAccessStatus.Active;
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAtUtc { get; set; }

    public Device? Device { get; set; }
    public Store? Store { get; set; }
}

public class AuditLogEntry
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public AuditAction Action { get; set; }
    public Guid? UserId { get; set; }
    public Guid? DeviceId { get; set; }
    public Guid? StoreId { get; set; }
    public Guid? SessionId { get; set; }
    public string ActorType { get; set; } = string.Empty;
    public string TargetType { get; set; } = string.Empty;
    public string TargetId { get; set; } = string.Empty;
    public string? Reason { get; set; }
    public string? Details { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
}
