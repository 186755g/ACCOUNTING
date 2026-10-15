using System.Text;
using System.Text.Json;
using Hesabati.Server.Contracts;

namespace Hesabati.Server.Services;

/// <summary>
/// Validates request structure and client-provided fields before the server computes any
/// canonical representation or hashes. This class intentionally does not trust body values
/// for actor identity, session identity, device identity, or store authorization.
/// </summary>
public static class SyncPushRequestValidator
{
    private const int MaxOperationIdLength = 128;
    private const int MaxStoreIdLength = 128;
    private const int MaxClientRequestIdLength = 128;
    private const int MaxSourceIdLength = 128;
    private const int MaxMovementIdLength = 128;
    private const int MaxEventsPerOperation = 200;
    private const int MaxPayloadBytes = 64 * 1024;
    private const int MaxPayloadProperties = 64;
    private const int MaxJsonDepth = 16;

    public static SyncPushValidationResult Validate(SyncPushRequest? request)
    {
        if (request is null)
        {
            return Invalid("validation_failed", "request-is-required");
        }

        if (string.IsNullOrWhiteSpace(request.OperationId))
        {
            return Invalid("validation_failed", "operation-id-required");
        }

        if (!Guid.TryParse(request.OperationId, out _))
        {
            return Invalid("validation_failed", "operation-id-invalid");
        }

        if (request.OperationId.Length > MaxOperationIdLength)
        {
            return Invalid("validation_failed", "operation-id-too-long");
        }

        if (string.IsNullOrWhiteSpace(request.StoreId))
        {
            return Invalid("validation_failed", "store-id-required");
        }

        if (!Guid.TryParse(request.StoreId, out _))
        {
            return Invalid("validation_failed", "store-id-invalid");
        }

        if (request.StoreId.Length > MaxStoreIdLength)
        {
            return Invalid("validation_failed", "store-id-too-long");
        }

        if (request.ClientRequestId is not null && request.ClientRequestId.Length > MaxClientRequestIdLength)
        {
            return Invalid("validation_failed", "client-request-id-too-long");
        }

        if (request.OperationVersion < 1)
        {
            return Invalid("validation_failed", "operation-version-invalid");
        }

        if (request.Events is null || request.Events.Count == 0)
        {
            return Invalid("validation_failed", "events-required");
        }

        if (request.Events.Count > MaxEventsPerOperation)
        {
            return Invalid("validation_failed", "too-many-events");
        }

        var seenEventIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var eventItem in request.Events)
        {
            if (eventItem is null)
            {
                return Invalid("validation_failed", "event-item-invalid");
            }

            if (string.IsNullOrWhiteSpace(eventItem.EventId))
            {
                return Invalid("validation_failed", "event-id-required");
            }

            if (eventItem.EventId.Length > 128)
            {
                return Invalid("validation_failed", "event-id-too-long");
            }

            if (eventItem.EventId != eventItem.EventId.Trim())
            {
                return Invalid("validation_failed", "event-id-invalid-whitespace");
            }

            if (!seenEventIds.Add(eventItem.EventId))
            {
                return Invalid("validation_failed", "duplicate-event-id");
            }

            if (string.IsNullOrWhiteSpace(eventItem.SourceId))
            {
                return Invalid("validation_failed", "source-id-required");
            }

            if (eventItem.SourceId.Length > MaxSourceIdLength)
            {
                return Invalid("validation_failed", "source-id-too-long");
            }

            if (eventItem.SourceId != eventItem.SourceId.Trim())
            {
                return Invalid("validation_failed", "source-id-invalid-whitespace");
            }

            if (eventItem.MovementId is not null)
            {
                if (string.IsNullOrWhiteSpace(eventItem.MovementId))
                {
                    return Invalid("validation_failed", "movement-id-invalid-whitespace");
                }

                if (eventItem.MovementId.Length > MaxMovementIdLength)
                {
                    return Invalid("validation_failed", "movement-id-too-long");
                }

                if (eventItem.MovementId != eventItem.MovementId.Trim())
                {
                    return Invalid("validation_failed", "movement-id-invalid-whitespace");
                }
            }

            if (!Enum.IsDefined(typeof(SyncPushEntityType), eventItem.EntityType))
            {
                return Invalid("validation_failed", "entity-type-not-supported");
            }

            if (!Enum.IsDefined(typeof(SyncPushAction), eventItem.Action))
            {
                return Invalid("validation_failed", "action-not-supported");
            }

            if (eventItem.Payload.ValueKind != JsonValueKind.Object)
            {
                return Invalid("validation_failed", "event-payload-invalid");
            }

            var payloadText = eventItem.Payload.GetRawText();
            var payloadUtf8Bytes = Encoding.UTF8.GetByteCount(payloadText);
            if (payloadUtf8Bytes > MaxPayloadBytes)
            {
                return Invalid("validation_failed", "event-payload-too-large");
            }

            if (!TryValidateJsonDepth(eventItem.Payload, 0, out var exceededDepth))
            {
                return Invalid("validation_failed", exceededDepth ? "event-payload-too-deep" : "event-payload-invalid");
            }

            var propertyCount = CountJsonProperties(eventItem.Payload, 0, MaxPayloadProperties);
            if (propertyCount is null)
            {
                return Invalid("validation_failed", "event-payload-too-many-properties");
            }
        }

        return Success();
    }

    private static bool TryValidateJsonDepth(JsonElement element, int depth, out bool exceededDepth)
    {
        exceededDepth = false;

        if (depth > MaxJsonDepth)
        {
            exceededDepth = true;
            return false;
        }

        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    if (!TryValidateJsonDepth(property.Value, depth + 1, out exceededDepth))
                    {
                        return false;
                    }
                }
                return true;
            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    if (!TryValidateJsonDepth(item, depth + 1, out exceededDepth))
                    {
                        return false;
                    }
                }
                return true;
            default:
                return true;
        }
    }

    private static int? CountJsonProperties(JsonElement element, int currentCount, int maxProperties)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    currentCount++;
                    if (currentCount > maxProperties)
                    {
                        return null;
                    }

                    var nestedResult = CountJsonProperties(property.Value, currentCount, maxProperties);
                    if (nestedResult is null)
                    {
                        return null;
                    }

                    currentCount = nestedResult.Value;
                }
                return currentCount;
            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    var nestedResult = CountJsonProperties(item, currentCount, maxProperties);
                    if (nestedResult is null)
                    {
                        return null;
                    }

                    currentCount = nestedResult.Value;
                }
                return currentCount;
            default:
                return currentCount;
        }
    }

    public static SyncPushValidationResult ValidateServerContext(
        Guid? authenticatedUserId,
        Guid? authenticatedDeviceId,
        Guid? authenticatedSessionId,
        Guid? authenticatedStoreId)
    {
        if (authenticatedUserId is null || authenticatedUserId == Guid.Empty)
        {
            return Invalid("auth_invalid_context", "authenticated-user-required");
        }

        if (authenticatedDeviceId is null || authenticatedDeviceId == Guid.Empty)
        {
            return Invalid("auth_invalid_context", "authenticated-device-required");
        }

        if (authenticatedSessionId is null || authenticatedSessionId == Guid.Empty)
        {
            return Invalid("auth_invalid_context", "authenticated-session-required");
        }

        if (authenticatedStoreId is null || authenticatedStoreId == Guid.Empty)
        {
            return Invalid("auth_invalid_context", "authenticated-store-required");
        }

        return Success();
    }

    private static SyncPushValidationResult Success()
    {
        return new SyncPushValidationResult
        {
            IsValid = true,
            ErrorCode = null,
            ErrorMessage = null
        };
    }

    private static SyncPushValidationResult Invalid(string errorCode, string errorMessage)
    {
        return new SyncPushValidationResult
        {
            IsValid = false,
            ErrorCode = errorCode,
            ErrorMessage = errorMessage
        };
    }
}
