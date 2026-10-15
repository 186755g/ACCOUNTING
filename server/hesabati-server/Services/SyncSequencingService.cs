using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Hesabati.Server.Data;
using Hesabati.Server.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Hesabati.Server.Services;

public sealed record SyncSequenceReservation(
    Guid StoreId,
    long PreviousSequence,
    long AssignedSequence,
    DateTime ReservedUtc);

public sealed class SyncSequencingService
{
    private readonly AppDbContext _db;

    public SyncSequencingService(AppDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Reserves the next EventSequence for a store inside the caller-owned PostgreSQL transaction.
    /// The caller owns transaction lifetime and must commit or rollback it after the business operation is complete.
    /// This method is intentionally not responsible for opening or closing a transaction.
    /// </summary>
    public async Task<SyncSequenceReservation> ReserveNextSequenceAsync(
        Guid storeId,
        IDbContextTransaction transaction,
        CancellationToken cancellationToken = default)
    {
        if (transaction is null)
        {
            throw new ArgumentNullException(nameof(transaction));
        }

        var state = await _db.StoreSyncStates.SingleOrDefaultAsync(x => x.StoreId == storeId, cancellationToken);
        if (state is null)
        {
            state = new StoreSyncState
            {
                StoreId = storeId,
                LastEventSequence = 0,
                UpdatedUtc = DateTime.UtcNow
            };

            _db.StoreSyncStates.Add(state);
            try
            {
                await _db.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
            {
                _db.ChangeTracker.Clear();
                state = await _db.StoreSyncStates.SingleOrDefaultAsync(x => x.StoreId == storeId, cancellationToken)
                    ?? throw new InvalidOperationException("sync_store_state_missing_after_create", ex);
            }
        }

        await _db.Database.ExecuteSqlInterpolatedAsync(
            $@"SELECT 1 FROM \"StoreSyncStates\" WHERE \"StoreId\" = {storeId} FOR UPDATE",
            cancellationToken);

        state = await _db.StoreSyncStates.SingleOrDefaultAsync(x => x.StoreId == storeId, cancellationToken)
            ?? throw new InvalidOperationException("sync_store_state_missing");

        var previous = state.LastEventSequence;
        var assigned = previous + 1;
        state.LastEventSequence = assigned;
        state.UpdatedUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync(cancellationToken);

        return new SyncSequenceReservation(storeId, previous, assigned, state.UpdatedUtc);
    }

    /// <summary>
    /// Calculates the canonical request fingerprint for an operation.
    /// The hash must be built from a stable canonical form of the operation payload and the ordered event IDs,
    /// not from an arbitrary caller-provided JSON value alone.
    /// </summary>
    public static string ComputeOperationHash(
        string operationId,
        IEnumerable<string>? eventIds,
        string canonicalJson,
        string? canonicalOperationSeed = null)
    {
        if (string.IsNullOrWhiteSpace(operationId))
        {
            throw new ArgumentException("Operation identifier is required.", nameof(operationId));
        }

        if (string.IsNullOrWhiteSpace(canonicalJson))
        {
            throw new ArgumentException("Canonical JSON is required for operation hashing.", nameof(canonicalJson));
        }

        var orderedEventIds = (eventIds ?? Array.Empty<string>())
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.Ordinal)
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToArray();

        var payload = new
        {
            operationId = operationId.Trim(),
            eventIds = orderedEventIds,
            canonicalJson = canonicalJson.Trim(),
            canonicalOperationSeed = canonicalOperationSeed?.Trim() ?? string.Empty
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions
        {
            WriteIndented = false,
            Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        });

        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(json));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    /// <summary>
    /// Records or replays a completed operation result within the caller-owned transaction.
    /// The caller is responsible for transaction scope and commit/rollback.
    /// </summary>
    public async Task<SyncOperationResult> RecordOperationResultAsync(
        Guid storeId,
        Guid? userId,
        Guid? deviceId,
        string operationId,
        string operationHash,
        string resultHash,
        SyncOperationResultStatus resultStatus,
        string? errorCode = null,
        string? errorMessage = null,
        IEnumerable<string>? acceptedEventIds = null,
        IDbContextTransaction? transaction = null,
        CancellationToken cancellationToken = default)
    {
        if (transaction is null)
        {
            throw new ArgumentNullException(nameof(transaction));
        }

        if (string.IsNullOrWhiteSpace(operationId))
        {
            throw new ArgumentException("Operation identifier is required.", nameof(operationId));
        }

        if (string.IsNullOrWhiteSpace(operationHash))
        {
            throw new ArgumentException("Operation hash is required.", nameof(operationHash));
        }

        if (string.IsNullOrWhiteSpace(resultHash))
        {
            throw new ArgumentException("Result hash is required.", nameof(resultHash));
        }

        var existing = await _db.SyncOperationResults
            .SingleOrDefaultAsync(x => x.StoreId == storeId && x.OperationId == operationId, cancellationToken);

        if (existing is not null)
        {
            if (!string.Equals(existing.OperationHash, operationHash, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("sync_operation_hash_conflict");
            }

            if (!string.Equals(existing.ResultHash, resultHash, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("sync_operation_result_conflict");
            }

            return existing;
        }

        var accepted = (acceptedEventIds ?? Array.Empty<string>())
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.Ordinal)
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToArray();

        try
        {
            var result = new SyncOperationResult
            {
                StoreId = storeId,
                UserId = userId,
                DeviceId = deviceId,
                OperationId = operationId,
                OperationHash = operationHash,
                ResultStatus = resultStatus,
                ResultHash = resultHash,
                ErrorCode = errorCode,
                ErrorMessage = errorMessage,
                AcceptedEventIdsJson = JsonSerializer.Serialize(accepted),
                CreatedUtc = DateTime.UtcNow,
                UpdatedUtc = DateTime.UtcNow
            };

            _db.SyncOperationResults.Add(result);
            await _db.SaveChangesAsync(cancellationToken);
            return result;
        }
        catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
        {
            _db.ChangeTracker.Clear();
            var retry = await _db.SyncOperationResults
                .SingleOrDefaultAsync(x => x.StoreId == storeId && x.OperationId == operationId, cancellationToken);

            if (retry is null)
            {
                throw new InvalidOperationException("sync_operation_result_insert_failed", ex);
            }

            if (!string.Equals(retry.OperationHash, operationHash, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("sync_operation_hash_conflict");
            }

            if (!string.Equals(retry.ResultHash, resultHash, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("sync_operation_result_conflict");
            }

            return retry;
        }
    }

    /// <summary>
    /// Explicitly records a rejection outcome after a business transaction has already rolled back.
    /// This method intentionally uses a fresh transaction, because a rejected result must not pretend to be part of the failed transaction.
    /// </summary>
    public async Task<SyncOperationResult> RecordRejectedOperationAsync(
        Guid storeId,
        Guid? userId,
        Guid? deviceId,
        string operationId,
        string operationHash,
        string resultHash,
        string errorCode,
        string errorMessage,
        CancellationToken cancellationToken = default)
    {
        using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

        try
        {
            var existing = await _db.SyncOperationResults
                .SingleOrDefaultAsync(x => x.StoreId == storeId && x.OperationId == operationId, cancellationToken);

            if (existing is not null)
            {
                if (!string.Equals(existing.OperationHash, operationHash, StringComparison.Ordinal))
                {
                    throw new InvalidOperationException("sync_operation_hash_conflict");
                }

                if (!string.Equals(existing.ResultHash, resultHash, StringComparison.Ordinal))
                {
                    throw new InvalidOperationException("sync_operation_result_conflict");
                }

                await transaction.CommitAsync(cancellationToken);
                return existing;
            }

            var result = new SyncOperationResult
            {
                StoreId = storeId,
                UserId = userId,
                DeviceId = deviceId,
                OperationId = operationId,
                OperationHash = operationHash,
                ResultStatus = SyncOperationResultStatus.Rejected,
                ResultHash = resultHash,
                ErrorCode = errorCode,
                ErrorMessage = errorMessage,
                AcceptedEventIdsJson = "[]",
                CreatedUtc = DateTime.UtcNow,
                UpdatedUtc = DateTime.UtcNow
            };

            _db.SyncOperationResults.Add(result);
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static bool IsUniqueConstraintViolation(DbUpdateException ex)
    {
        return ex.InnerException is not null
            && (ex.InnerException.Message.Contains("duplicate key", StringComparison.OrdinalIgnoreCase)
                || ex.InnerException.Message.Contains("unique constraint", StringComparison.OrdinalIgnoreCase)
                || ex.InnerException.Message.Contains("already exists", StringComparison.OrdinalIgnoreCase));
    }
}
