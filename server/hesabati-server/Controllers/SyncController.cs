using System.Text.Json;
using Hesabati.Server.Contracts;
using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Hesabati.Server.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Controllers;

[ApiController]
[Route("api/v1/sync")]
[Authorize]
public sealed class SyncController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly StoreAccessService _storeAccessService;
    private readonly SyncSequencingService _syncSequencingService;

    public SyncController(
        AppDbContext db,
        StoreAccessService storeAccessService,
        SyncSequencingService syncSequencingService)
    {
        _db = db;
        _storeAccessService = storeAccessService;
        _syncSequencingService = syncSequencingService;
    }

    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] SyncPushRequest request, CancellationToken cancellationToken)
    {
        var userId = ParseGuidClaim(User.FindFirst("sub"));
        var deviceId = ParseGuidClaim(User.FindFirst("device_id"));
        var sessionId = ParseGuidClaim(User.FindFirst("session_id"));
        var authenticatedStoreId = ParseGuidClaim(User.FindFirst("store_id"));

        var serverContext = SyncPushRequestValidator.ValidateServerContext(userId, deviceId, sessionId, authenticatedStoreId);
        if (!serverContext.IsValid)
        {
            return Unauthorized(new { error = serverContext.ErrorCode, message = serverContext.ErrorMessage });
        }

        var validation = SyncPushRequestValidator.Validate(request);
        if (!validation.IsValid)
        {
            return BadRequest(new SyncPushResponse
            {
                OperationId = request?.OperationId ?? string.Empty,
                ResultStatus = SyncPushResultStatus.Rejected,
                Accepted = false,
                ErrorCode = validation.ErrorCode,
                ErrorMessage = validation.ErrorMessage
            });
        }

        if (userId is null || deviceId is null || sessionId is null || authenticatedStoreId is null)
        {
            return Unauthorized(new { error = "auth_invalid_context", message = "authenticated-context-required" });
        }

        if (!Guid.TryParse(request.StoreId, out var requestStoreId) || requestStoreId != authenticatedStoreId.Value)
        {
            return BadRequest(new SyncPushResponse
            {
                OperationId = request.OperationId,
                ResultStatus = SyncPushResultStatus.Rejected,
                Accepted = false,
                ErrorCode = "auth_store_context_mismatch",
                ErrorMessage = "request-store-does-not-match-authenticated-store"
            });
        }

        try
        {
            await _storeAccessService.ValidateStoreAccessAsync(userId.Value, deviceId.Value, authenticatedStoreId.Value);
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new SyncPushResponse
            {
                OperationId = request.OperationId,
                ResultStatus = SyncPushResultStatus.Rejected,
                Accepted = false,
                ErrorCode = ex.Message,
                ErrorMessage = ex.Message
            });
        }

        var operationHash = SyncSequencingService.ComputeOperationHash(
            request.OperationId,
            request.Events.Select(x => x.EventId),
            CanonicalizeOperation(request),
            "sync-v1");

        var existing = await _db.SyncOperationResults
            .SingleOrDefaultAsync(x => x.StoreId == authenticatedStoreId.Value && x.OperationId == request.OperationId, cancellationToken);

        if (existing is not null)
        {
            if (string.Equals(existing.OperationHash, operationHash, StringComparison.Ordinal))
            {
                return Ok(new SyncPushResponse
                {
                    OperationId = request.OperationId,
                    ResultStatus = SyncPushResultStatus.Duplicate,
                    Accepted = false,
                    ResultHash = existing.ResultHash,
                    AcceptedEventIds = ParseAcceptedEventIds(existing.AcceptedEventIdsJson),
                    ErrorCode = "sync_duplicate_operation",
                    ErrorMessage = "operation-already-processed"
                });
            }

            return Conflict(new SyncPushResponse
            {
                OperationId = request.OperationId,
                ResultStatus = SyncPushResultStatus.Conflict,
                Accepted = false,
                ResultHash = existing.ResultHash,
                ErrorCode = "sync_operation_hash_conflict",
                ErrorMessage = "operation-id-reused-with-different-payload"
            });
        }

        var acceptedEventIds = new List<string>();

        using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

        try
        {
            foreach (var evt in request.Events.OrderBy(x => x.EventId, StringComparer.Ordinal))
            {
                var sequenceReservation = await _syncSequencingService.ReserveNextSequenceAsync(
                    authenticatedStoreId.Value,
                    transaction,
                    cancellationToken);

                var eventLedger = new SyncEventLedger
                {
                    StoreId = authenticatedStoreId.Value,
                    UserId = userId.Value,
                    DeviceId = deviceId.Value,
                    SessionId = sessionId.Value,
                    OperationId = request.OperationId,
                    OperationHash = operationHash,
                    EventId = evt.EventId,
                    SourceId = evt.SourceId,
                    EntityType = evt.EntityType.ToString(),
                    Action = evt.Action.ToString(),
                    PayloadJson = evt.Payload.GetRawText(),
                    PayloadHash = ComputeHash(evt.Payload.GetRawText()),
                    EventSequence = sequenceReservation.AssignedSequence,
                    CreatedUtc = DateTime.UtcNow,
                    CommittedUtc = DateTime.UtcNow
                };

                _db.SyncEventLedger.Add(eventLedger);
                acceptedEventIds.Add(evt.EventId);
            }

            var result = await _syncSequencingService.RecordOperationResultAsync(
                authenticatedStoreId.Value,
                userId.Value,
                deviceId.Value,
                request.OperationId,
                operationHash,
                operationHash,
                SyncOperationResultStatus.Accepted,
                acceptedEventIds: acceptedEventIds,
                transaction: transaction,
                cancellationToken: cancellationToken);

            await transaction.CommitAsync(cancellationToken);

            return Ok(new SyncPushResponse
            {
                OperationId = request.OperationId,
                ResultStatus = SyncPushResultStatus.Accepted,
                Accepted = true,
                ResultHash = result.ResultHash,
                AcceptedEventIds = acceptedEventIds,
                CreatedUtc = result.CreatedUtc
            });
        }
        catch (InvalidOperationException ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Conflict(new SyncPushResponse
            {
                OperationId = request.OperationId,
                ResultStatus = SyncPushResultStatus.Conflict,
                Accepted = false,
                ErrorCode = ex.Message,
                ErrorMessage = ex.Message
            });
        }
    }

    private static Guid? ParseGuidClaim(System.Security.Claims.Claim? claim)
    {
        if (claim is null)
        {
            return null;
        }

        return Guid.TryParse(claim.Value, out var value) ? value : null;
    }

    private static string CanonicalizeOperation(SyncPushRequest request)
    {
        var orderedEvents = request.Events
            .OrderBy(x => x.EventId, StringComparer.Ordinal)
            .Select(x => new
            {
                eventId = x.EventId,
                sourceId = x.SourceId,
                movementId = x.MovementId ?? string.Empty,
                entityType = x.EntityType.ToString(),
                action = x.Action.ToString(),
                payload = x.Payload.GetRawText()
            });

        return JsonSerializer.Serialize(orderedEvents);
    }

    private static string ComputeHash(string value)
    {
        using var sha = System.Security.Cryptography.SHA256.Create();
        var bytes = sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static List<string> ParseAcceptedEventIds(string? acceptedEventIdsJson)
    {
        if (string.IsNullOrWhiteSpace(acceptedEventIdsJson))
        {
            return new List<string>();
        }

        try
        {
            var parsed = JsonSerializer.Deserialize<List<string>>(acceptedEventIdsJson);
            return parsed ?? new List<string>();
        }
        catch (JsonException)
        {
            return new List<string>();
        }
    }
}
