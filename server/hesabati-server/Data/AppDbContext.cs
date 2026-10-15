using Hesabati.Server.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Hesabati.Server.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserSession> UserSessions => Set<UserSession>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Store> Stores => Set<Store>();
    public DbSet<StoreMembership> StoreMemberships => Set<StoreMembership>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<DeviceSession> DeviceSessions => Set<DeviceSession>();
    public DbSet<DeviceStoreAccess> DeviceStoreAccess => Set<DeviceStoreAccess>();
    public DbSet<StoreSyncState> StoreSyncStates => Set<StoreSyncState>();
    public DbSet<SyncEventLedger> SyncEventLedger => Set<SyncEventLedger>();
    public DbSet<SyncOperationResult> SyncOperationResults => Set<SyncOperationResult>();
    public DbSet<AuditLogEntry> AuditLogs => Set<AuditLogEntry>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasIndex(x => x.PhoneNumber).IsUnique();
            entity.Property(x => x.Email).HasMaxLength(255);
            entity.Property(x => x.PhoneNumber).HasMaxLength(32);
            entity.Property(x => x.DisplayName).HasMaxLength(200);
        });

        modelBuilder.Entity<UserSession>(entity =>
        {
            entity.HasIndex(x => x.AccessTokenHash).IsUnique();
            entity.HasIndex(x => x.UserId);
            entity.HasIndex(x => x.DeviceId);
            entity.Property(x => x.Status).HasConversion<string>();
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => x.UserId);
            entity.HasIndex(x => x.DeviceId);
            entity.Property(x => x.RevocationReason).HasMaxLength(200);
        });

        modelBuilder.Entity<Store>(entity =>
        {
            entity.HasIndex(x => x.OwnerUserId);
            entity.Property(x => x.Name).HasMaxLength(200);
            entity.Property(x => x.Currency).HasMaxLength(10);
        });

        modelBuilder.Entity<StoreMembership>(entity =>
        {
            entity.HasIndex(x => new { x.StoreId, x.UserId }).IsUnique();
            entity.Property(x => x.Role).HasConversion<string>();
        });

        modelBuilder.Entity<Device>(entity =>
        {
            entity.HasIndex(x => new { x.UserId, x.DeviceKey }).IsUnique();
            entity.Property(x => x.Status).HasConversion<string>();
            entity.Property(x => x.Platform).HasMaxLength(50);
            entity.Property(x => x.DeviceName).HasMaxLength(200);
        });

        modelBuilder.Entity<DeviceSession>(entity =>
        {
            entity.HasIndex(x => x.DeviceId);
            entity.HasIndex(x => x.StoreId);
            entity.HasIndex(x => x.UserId);
            entity.Property(x => x.Status).HasConversion<string>();
        });

        modelBuilder.Entity<DeviceStoreAccess>(entity =>
        {
            entity.HasIndex(x => new { x.DeviceId, x.StoreId }).IsUnique();
            entity.Property(x => x.Status).HasConversion<string>();
        });

        modelBuilder.Entity<StoreSyncState>(entity =>
        {
            entity.HasKey(x => x.StoreId);
            entity.HasOne(x => x.Store)
                .WithMany(x => x.SyncStates)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.Property(x => x.LastEventSequence).HasColumnType("bigint");
            entity.HasIndex(x => x.UpdatedUtc);
        });

        modelBuilder.Entity<SyncEventLedger>(entity =>
        {
            entity.HasIndex(x => new { x.StoreId, x.EventId }).IsUnique();
            entity.HasIndex(x => new { x.StoreId, x.EventSequence }).IsUnique();
            entity.HasIndex(x => x.StoreId);
            entity.HasIndex(x => new { x.StoreId, x.OperationId });
            entity.HasIndex(x => new { x.StoreId, x.OperationHash });
            entity.HasIndex(x => new { x.StoreId, x.SourceId, x.EntityType });
            entity.HasIndex(x => new { x.StoreId, x.CreatedUtc });
            entity.HasIndex(x => x.PayloadHash);
            entity.Property(x => x.Action).HasMaxLength(32);
            entity.Property(x => x.EntityType).HasMaxLength(64);
            entity.Property(x => x.SourceId).HasMaxLength(128);
            entity.Property(x => x.OperationId).HasMaxLength(128);
            entity.Property(x => x.OperationHash).HasMaxLength(128);
            entity.Property(x => x.EventId).HasMaxLength(128);
            entity.Property(x => x.PayloadJson).HasColumnType("jsonb");
            entity.HasOne(x => x.Store)
                .WithMany(x => x.SyncEvents)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.Device)
                .WithMany()
                .HasForeignKey(x => x.DeviceId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.Session)
                .WithMany()
                .HasForeignKey(x => x.SessionId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<SyncOperationResult>(entity =>
        {
            entity.HasIndex(x => new { x.StoreId, x.OperationId }).IsUnique();
            entity.HasIndex(x => new { x.StoreId, x.OperationHash });
            entity.HasIndex(x => x.ResultStatus);
            entity.HasIndex(x => x.CreatedUtc);
            entity.Property(x => x.OperationId).HasMaxLength(128);
            entity.Property(x => x.OperationHash).HasMaxLength(128);
            entity.Property(x => x.ResultStatus).HasConversion<string>();
            entity.Property(x => x.ErrorCode).HasMaxLength(128);
            entity.Property(x => x.AcceptedEventIdsJson).HasColumnType("jsonb");
            entity.HasOne(x => x.Store)
                .WithMany(x => x.OperationResults)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.Device)
                .WithMany()
                .HasForeignKey(x => x.DeviceId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<AuditLogEntry>(entity =>
        {
            entity.HasIndex(x => x.CreatedUtc);
            entity.Property(x => x.Action).HasMaxLength(100);
            entity.Property(x => x.TargetType).HasMaxLength(100);
            entity.Property(x => x.TargetId).HasMaxLength(100);
            entity.Property(x => x.ActorType).HasMaxLength(50);
            entity.Property(x => x.Reason).HasMaxLength(500);
        });
    }
}
