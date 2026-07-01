using System.Collections.Immutable;
using System.Management.Automation;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.Storage.CloudFilters;

namespace Profile.CloudFilter;

public static unsafe class Cfapi
{
    public static SyncRootInfo Get(string path)
    {
        if (!OperatingSystem.IsWindowsVersionAtLeast(10, 0, 16299))
        {
            throw new PlatformNotSupportedException("CfGetSyncRootInfoByPath requires Windows 10.0.16299 or later.");
        }

        fixed (char* pPath = path)
        {
            CF_SYNC_ROOT_STANDARD_INFO info = default;
            uint length = (uint)sizeof(CF_SYNC_ROOT_STANDARD_INFO);
            HRESULT hr = Interop.CfGetSyncRootInfoByPath(
                pPath,
                CF_SYNC_ROOT_INFO_CLASS.CF_SYNC_ROOT_INFO_STANDARD,
                &info,
                length,
                &length);

            if (length is 0)
            {
                hr.AssertSuccess();
                throw new InvalidOperationException("Got success but length 0");
            }

            CF_SYNC_ROOT_STANDARD_INFO* pInfo = &info;
            byte* ptrToReturn = null;
            try
            {
                if (pInfo->SyncRootIdentityLength is > 0)
                {
                    uint totalLength = (uint)CF_SYNC_ROOT_STANDARD_INFO.SizeOf((int)pInfo->SyncRootIdentityLength);
                    ptrToReturn = (byte*)NativeMemory.Alloc(totalLength);
                    hr = Interop.CfGetSyncRootInfoByPath(
                        pPath,
                        CF_SYNC_ROOT_INFO_CLASS.CF_SYNC_ROOT_INFO_STANDARD,
                        ptrToReturn,
                        totalLength,
                        &length);

                    pInfo = (CF_SYNC_ROOT_STANDARD_INFO*)ptrToReturn;
                }

                hr.AssertSuccess();

                return new SyncRootInfo(
                    pInfo->SyncRootFileId,
                    (HydrationPolicy)pInfo->HydrationPolicy.Primary,
                    (HydrationPolicyModifier)pInfo->HydrationPolicy.Modifier,
                    (PopulationPolicy)pInfo->PopulationPolicy.Primary,
                    (PopulationPolicyModifier)pInfo->PopulationPolicy.Modifier,
                    (InSyncPolicy)pInfo->InSyncPolicy,
                    (HardLinkPolicy)pInfo->HardLinkPolicy,
                    (ProviderStatus)pInfo->ProviderStatus,
                    pInfo->ProviderName.AsReadOnlySpan().TrimEnd('\0').ToString(),
                    pInfo->ProviderVersion.AsReadOnlySpan().TrimEnd('\0').ToString(),
                    ImmutableArray.Create(pInfo->SyncRootIdentity.AsSpan((int)pInfo->SyncRootIdentityLength).ToArray()));
            }
            finally
            {
                if (ptrToReturn is not null)
                {
                    NativeMemory.Free(ptrToReturn);
                }
            }
        }
    }
}

public enum HydrationPolicy
{
    /// <summary>
    /// The same behavior as <see cref="Progressive" />, except that
    /// <see cref="Partial" /> does not have continuous hydration in the
    /// background.
    /// </summary>
    Partial = 0,
    /// <summary>
    /// <para>
    /// When <see cref="Progressive"/> is selected, the platform will allow a
    /// placeholder to be dehydrated. When the platform detects access to a
    /// dehydrated placeholder, it will complete the user IO request as soon as
    /// it determines that sufficient data is received from the sync provider.
    /// However, the platform will continue requesting the remaining content in
    /// the placeholder from the sync provider in the background until either
    /// the full content of the placeholder is available locally, or the last
    /// user handle on the placeholder is closed.
    /// >[!NOTE]> Sync providers who opt in for <see cref="Progressive"/> may
    /// not assume that hydration callbacks arrive sequentially from offset 0.
    /// In other words, sync providers with <see cref="Progressive"/> policy are
    /// expected to handle random seeks on the placeholder.
    /// </para>
    /// <para>
    /// <see href="https://learn.microsoft.com/windows/win32/api/cfapi/ne-cfapi-cf_hydration_policy_primary#members">Read more on docs.microsoft.com</see>.
    // </para>
    /// </summary>
    Progressive = 1,

    /// <summary>
    /// When <see cref="Full"/> is selected, the platform will allow a
    /// placeholder to be dehydrated. When the platform detects access to a
    /// dehydrated placeholder, it will ensure that the full content of the
    /// placeholder is available locally before completing the user IO request,
    /// even if the request is only asking for 1 byte.
    /// </summary>
    Full = 2,
    /// <summary>
    /// When <see cref="AlwaysFull"/> is selected, the platform will block any
    /// placeholder operation that could result in a not fully hydrated
    /// placeholder, which includes [CfCreatePlaceholders](nf-cfapi-cfcreateplaceholders.md),
    /// [CfUpdatePlaceholder](nf-cfapi-cfupdateplaceholder.md) with the dehydrate option,
    /// and [CfConvertToPlaceholder](nf-cfapi-cfconverttoplaceholder.md) with the dehydrate option.
    /// </summary>
    AlwaysFull = 3,
}

[Flags]
public enum HydrationPolicyModifier
{

    /// <summary>
    /// <para>`0x0000` No policy modifier.</para>
    /// <para><see href="https://learn.microsoft.com/windows/win32/api/cfapi/ne-cfapi-cf_hydration_policy_modifier#members">Read more on docs.microsoft.com</see>.</para>
    /// </summary>
    None = 0x0000,

    /// <summary>
    /// <para>`0x0001` This policy modifier offers two guarantees to a sync provider. First, it guarantees that the data returned by the sync provider is always persisted to the disk prior to it being returned to the user application. Second, it allows the sync provider to retrieve the same data it has returned previously to the platform and validate its integrity. Only upon a successful confirmation of the integrity by the sync provider will the platform complete the user I/O request. This modifier helps support end-to-end data integrity at the cost of extra disk I/Os.</para>
    /// <para><see href="https://learn.microsoft.com/windows/win32/api/cfapi/ne-cfapi-cf_hydration_policy_modifier#members">Read more on docs.microsoft.com</see>.</para>
    /// </summary>
    ValidationRequired = 0x0001,

    /// <summary>
    /// <para>`0x0002` This policy modifier grants the platform the permission to not store any data returned by a sync provider on local disks. This policy modifier is ineffective when being combined with **CF_HYDRATION_POLICY_MODIFIER_VALIDATION_REQUIRED**.</para>
    /// <para><see href="https://learn.microsoft.com/windows/win32/api/cfapi/ne-cfapi-cf_hydration_policy_modifier#members">Read more on docs.microsoft.com</see>.</para>
    /// </summary>
    StreamingAllowed = 0x0002,

    /// <summary>
    /// <para>`0x0004` This policy modifier grants the platform the permission to dehydrate in-sync cloud file placeholders without the help of sync providers. Without this flag, the platform is not allowed to call [CfDehydratePlaceholder](/previous-versions/mt827480(v=vs.85)) directly. Instead, the only supported way to dehydrate a cloud file placeholder is to clear the file’s pinned attribute and set the file’s unpinned attribute. At that point, the actual dehydration will be performed asynchronously by the sync engine after it receives the directory change notification on the two attributes. When this flag is specified, the platform will be allowed to invoke **CfDehydratePlaceholder** directly on any in-sync cloud file placeholder. It is recommended for sync providers to support auto-dehydration. > [!NOTE] > This value is available in Windows 10, version 1803 and later.</para>
    /// <para><see href="https://learn.microsoft.com/windows/win32/api/cfapi/ne-cfapi-cf_hydration_policy_modifier#members">Read more on docs.microsoft.com</see>.</para>
    /// </summary>
    AutoDehydrationAllowed = 0x0004,

    /// <summary>
    /// <para>`0x0008` This policy modifier grants the platform permission to fully hydrate a file synchronously when it intercepts an attempt by an AV Filter to scan the file. Sync providers that wish to use **RestartHydration** to change the `fileSize` from a **FetchData** callback must opt-in for the `ALLOW_FULL_RESTART_HYDRATION` policy to avoid possible deadlocks with anti-virus and anti-malware software trying to scan the file and the provider trying to change `fileSize` using **RestartHydration**. > [!NOTE] > This enum update is supported only if the `PlatformVersion.IntegrationNumber` obtained from [CfGetPlatformInfo](nf-cfapi-cfgetplatforminfo.md) is `0x500` or higher.</para>
    /// <para><see href="https://learn.microsoft.com/windows/win32/api/cfapi/ne-cfapi-cf_hydration_policy_modifier#members">Read more on docs.microsoft.com</see>.</para>
    /// </summary>
    AllowFullRestartHydration = 0x0008,
}

public enum PopulationPolicy
{
    /// <summary>
    /// With <see cref="Partial"/> population policy, when the platform detects
    /// access on a not fully populated directory, it will request only the
    /// entries required by the user application from the sync provider. This
    /// policy is not currently supported by the platform.
    /// </summary>
    Partial = 0,

    /// <summary>
    /// With <see cref="Full"/> population policy, when the platform detects
    /// access on a not fully populated directory, it will request the sync
    /// provider return all entries under the directory before completing the
    /// user request.
    /// </summary>
    Full = 2,

    /// <summary>
    /// When <see cref="AlwaysFull"/> is selected, the platform assumes that
    /// the full name space is always available locally. It will never forward
    /// any directory enumeration request to the sync provider.
    /// </summary>
    AlwaysFull = 3,
}

[Flags]
public enum PopulationPolicyModifier
{
    /// <summary>No policy modifier.</summary>
    None = 0x0000,
}

[Flags]
public enum InSyncPolicy
{
    /// <summary>The default in-sync policy.</summary>
    None = 0x00000000,

    /// <summary>Clears in-sync state when a file is created.</summary>
    FileCreationTime = 0x00000001,

    /// <summary>Clears in-sync state when a file is read-only.</summary>
    FileReadOnly = 0x00000002,

    /// <summary>Clears in-sync state when a file is hidden.</summary>
    FileHidden = 0x00000004,

    /// <summary>Clears in-sync state when a file is a system file.</summary>
    FileSystem = 0x00000008,

    /// <summary>Clears in-sync state when a directory is created.</summary>
    DirectoryCreationTime = 0x00000010,

    /// <summary>Clears in-sync state when a directory is read-only.</summary>
    DirectoryReadOnly = 0x00000020,

    /// <summary>Clears in-sync state when a directory is hidden.</summary>
    DirectoryHidden = 0x00000040,

    /// <summary>Clears in-sync state when a directory is  a system directory.</summary>
    DirectorySystem = 0x00000080,

    /// <summary>Clears in-sync state based on the last write time to a file.</summary>
    FileLastWriteTime = 0x00000100,

    /// <summary>Clears in-sync state based on the last write time to a directory.</summary>
    DirectoryLastWriteTime = 0x00000200,

    /// <summary>Clears in-sync state for any changes to a file.</summary>
    FileAll = 0x0055550F,

    /// <summary>Clears in-sync state for any changes to a directory.</summary>
    DirectoryAll = 0x00AAAAF0,

    /// <summary>Clears in-sync state for any changes to a file or directory.</summary>
    All = 0x00FFFFFF,

    /// <summary>In-sync policies are exempt from clearing.</summary>
    PreserveInSyncForSyncEngine = unchecked((int)0x80000000),
}

public enum HardLinkPolicy
{
    /// <summary>Default; No hard links can be created on any placeholder.</summary>
    None = 0x00000000,
    /// <summary>Hard links can be created on a placeholder under the same sync root or no sync root.</summary>
    Allowed = 0x00000001,
}

[Flags]
public enum ProviderStatus
{
    /// <summary>The sync provider is disconnected.</summary>
    Disconnected = 0x00000000,

    /// <summary>The sync provider is idle.</summary>
    Idle = 0x00000001,

    /// <summary>The sync provider is populating a namespace.</summary>
    PopulateNamespace = 0x00000002,

    /// <summary>The sync provider is populating placeholder metadata.</summary>
    PopulateMetadata = 0x00000004,

    /// <summary>The sync provider is populating placeholder content.</summary>
    PopulateContent = 0x00000008,

    /// <summary>The sync provider is incrementally syncing placeholder content.</summary>
    SyncIncremental = 0x00000010,

    /// <summary>The sync provider has fully synced placeholder file data.</summary>
    SyncFull = 0x00000020,

    /// <summary>The sync provider has lost connectivity.</summary>
    ConnectivityLost = 0x00000040,

    /// <summary>Clears the flags of the sync provider.</summary>
    ClearFlags = unchecked((int)0x80000000),

    /// <summary>The sync provider has been terminated.</summary>
    Terminated = unchecked((int)0xC0000001),

    /// <summary>There was an error with the sync provider.</summary>
    Error = unchecked((int)0xC0000002),
}

public record SyncRootInfo(
    /// <summary>File ID of the sync root.</summary>
    long SyncRootFileId,

    /// <summary>
    /// Hydration policy of the sync root. See [CF_HYDRATION_POLICY_PRIMARY](ne-cfapi-cf_hydration_policy_primary.md)
    /// for more information.
    /// </summary>
    HydrationPolicy HydrationPolicy,

    HydrationPolicyModifier HydrationPolicyModifier,

    /// <summary>
    /// Population policy of the sync root. See [CF_POPULATION_POLICY_PRIMARY](ne-cfapi-cf_population_policy_primary.md)
    /// for more information.
    /// </summary>
    PopulationPolicy PopulationPolicy,

    PopulationPolicyModifier PopulationPolicyModifier,

    /// <summary>
    /// In-sync policy of the sync root. See [CF_INSYNC_POLICY](ne-cfapi-cf_insync_policy.md)
    /// for possible values.
    /// </summary>
    InSyncPolicy InSyncPolicy,

    /// <summary>
    /// Sync root hard linking policy. See [CF_HARDLINK_POLICY](ne-cfapi-cf_hardlink_policy.md)
    /// for possible values.
    /// </summary>
    HardLinkPolicy HardLinkPolicy,

    /// <summary>
    /// Status of the sync root provider. See [CF_SYNC_PROVIDER_STATUS](ne-cfapi-cf_sync_provider_status.md)
    /// for possible values.
    /// </summary>
    ProviderStatus ProviderStatus,

    /// <summary>Name of the sync root.</summary>
    string ProviderName,

    /// <summary>Version of the sync root.</summary>
    string ProviderVersion,

    /// <summary>The identity of the sync root directory.</summary>
    ImmutableArray<byte> SyncRootIdentity);