using System.Text.Json;

namespace Hesabati.Server.Contracts;

public enum SyncPushEntityType
{
    Sale,
    SaleItem,
    Purchase,
    PurchaseItem,
    Expense,
    ExpenseItem,
    InventoryMovement,
    Product,
    Party,
    FinancialAccount,
    Payment
}

public enum SyncPushAction
{
    Create,
    Update,
    Delete,
    Void
}

public enum SyncPushResultStatus
{
    Accepted,
    Duplicate,
    Rejected,
    Conflict
}

/// <summary>
/// Represents the payload a client sends for a sync push operation.
/// The server must not trust any body values that identify the authenticated actor,
/// the device, the session, or the target store. Those values must be resolved from
/// the authenticated request context later in the server pipeline.
/// </summary>
public sealed class SyncPushRequest
{
    /// <summary>
    /// Unique operation identifier created by the client for idempotent retries.
    /// Must be a valid GUID string.
    /// </summary>
    public string OperationId { get; set; } = string.Empty;

    /// <summary>
    /// Store identifier is informational only in the request contract and must be validated
    /// against the authenticated store context in the server.
    /// This value is never trusted as a source of authorization.
    /// </summary>
    public string StoreId { get; set; } = string.Empty;

    /// <summary>
    /// Optional client-side request correlation value.
    /// This is not used as an idempotency key and is not trusted for authorization.
    /// </summary>
    public string? ClientRequestId { get; set; }

    /// <summary>
    /// Version of the business operation contract.
    /// </summary>
    public int OperationVersion { get; set; } = 1;

    /// <summary>
    /// Ordered list of domain events in the operation.
    /// </summary>
    public List<SyncPushEvent> Events { get; set; } = new();
}

/// <summary>
/// Represents a single event in the client request.
/// Event identity is separated from the operation identity.
/// </summary>
public sealed class SyncPushEvent
{
    /// <summary>
    /// Event identifier unique within the operation and within the target store.
    /// </summary>
    public string EventId { get; set; } = string.Empty;

    /// <summary>
    /// Business source identifier, such as a sale ID, invoice ID, or inventory movement ID.
    /// This must not be confused with OperationId.
    /// </summary>
    public string SourceId { get; set; } = string.Empty;

    /// <summary>
    /// Optional movement identifier for finance or inventory movement records.
    /// Only valid for movement-based domains, never as a substitute for OperationId.
    /// </summary>
    public string? MovementId { get; set; }

    /// <summary>
    /// Allowed entity type. The server validates this using a closed whitelist.
    /// </summary>
    public SyncPushEntityType EntityType { get; set; }

    /// <summary>
    /// Allowed action. The server validates this using a closed whitelist.
    /// </summary>
    public SyncPushAction Action { get; set; }

    /// <summary>
    /// Event payload after domain validation. The server must canonicalize this itself.
    /// </summary>
    public JsonElement Payload { get; set; }
}

/// <summary>
/// Response contract for a sync push request.
/// The server populates resultStatus and accepted after verifying and persisting the operation.
/// This response is for protocol contract only; it does not imply that storage logic is implemented yet.
/// </summary>
public sealed class SyncPushResponse
{
    public string OperationId { get; set; } = string.Empty;
    public SyncPushResultStatus ResultStatus { get; set; } = SyncPushResultStatus.Accepted;
    public bool Accepted { get; set; }
    public string? ResultHash { get; set; }
    public List<string> AcceptedEventIds { get; set; } = new();
    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Validation result for the request contract.
/// This is intentionally a coarse model, so the server can return generic validation messages
/// without revealing details about other stores or internal data.
/// </summary>
public sealed class SyncPushValidationResult
{
    public bool IsValid { get; set; }
    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
}
