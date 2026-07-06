using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

namespace WinMemoryOpt
{
    public class MemoryHelper
    {
        // SystemMemoryListInformation = 80
        private const int SystemMemoryListInformation = 80;

        // Commands for SystemMemoryListInformation
        public enum SystemMemoryListCommand
        {
            MemoryPurgeActiveAndStandbyList = 0,
            MemoryPurgeTransactionProperties = 1,
            MemoryEmptyWorkingSets = 2,
            MemoryFlushModifiedList = 3,
            MemoryPurgeStandbyList = 4,
            MemoryPurgeLowPriorityStandbyList = 5,
            MemoryCollapsePhysicalMemory = 6
        }

        [DllImport("ntdll.dll")]
        public static extern uint NtSetSystemInformation(
            int SystemInformationClass,
            IntPtr SystemInformation,
            int SystemInformationLength
        );

        [DllImport("psapi.dll", SetLastError = true)]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetProcessWorkingSetSize(
            IntPtr hProcess,
            IntPtr dwMinimumWorkingSetSize,
            IntPtr dwMaximumWorkingSetSize
        );

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyIcon(IntPtr hIcon);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        public static uint GetForegroundWindowPID()
        {
            IntPtr hWnd = GetForegroundWindow();
            if (hWnd != IntPtr.Zero)
            {
                uint pid;
                GetWindowThreadProcessId(hWnd, out pid);
                return pid;
            }
            return 0;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_POWER_THROTTLING_STATE {
            public uint Version;
            public uint ControlMask;
            public uint StateMask;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetProcessInformation(
            IntPtr hProcess,
            int ProcessInformationClass,
            ref PROCESS_POWER_THROTTLING_STATE ProcessInformation,
            uint ProcessInformationSize
        );

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool OpenProcessToken(
            IntPtr ProcessHandle,
            uint DesiredAccess,
            out IntPtr TokenHandle
        );

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool LookupPrivilegeValue(
            string lpSystemName,
            string lpName,
            out LUID lpLuid
        );

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool AdjustTokenPrivileges(
            IntPtr TokenHandle,
            bool DisableAllPrivileges,
            ref TOKEN_PRIVILEGES NewState,
            int BufferLength,
            IntPtr PreviousState,
            IntPtr ReturnLength
        );

        [StructLayout(LayoutKind.Sequential)]
        public struct LUID
        {
            public uint LowPart;
            public int HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct LUID_AND_ATTRIBUTES
        {
            public LUID Luid;
            public uint Attributes;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct TOKEN_PRIVILEGES
        {
            public uint PrivilegeCount;
            public LUID_AND_ATTRIBUTES Privilege;
        }

        private const uint TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        private const uint TOKEN_QUERY = 0x00000008;
        private const uint SE_PRIVILEGE_ENABLED = 0x00000002;

        private const string SE_INCREASE_QUOTA_NAME = "SeIncreaseQuotaPrivilege";
        private const string SE_PROFILE_SINGLE_PROCESS_NAME = "SeProfileSingleProcessPrivilege";

        public static bool EnablePrivilege(string privilegeName)
        {
            IntPtr hToken;
            if (!OpenProcessToken(Process.GetCurrentProcess().Handle, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out hToken))
            {
                return false;
            }

            LUID luid;
            if (!LookupPrivilegeValue(null, privilegeName, out luid))
            {
                return false;
            }

            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Privilege.Luid = luid;
            tp.Privilege.Attributes = SE_PRIVILEGE_ENABLED;

            bool result = AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            return result;
        }

        public static bool EnableMemoryPrivileges()
        {
            bool q = EnablePrivilege(SE_INCREASE_QUOTA_NAME);
            bool p = EnablePrivilege(SE_PROFILE_SINGLE_PROCESS_NAME);
            return q && p;
        }

        // Method 1: Empty working sets of all processes (Public API)
        public static int PurgeWorkingSets()
        {
            int count = 0;
            Process[] processes = Process.GetProcesses();
            foreach (Process proc in processes)
            {
                try
                {
                    if (proc.Id == 0) continue;
                    
                    bool success = SetProcessWorkingSetSize(proc.Handle, new IntPtr(-1), new IntPtr(-1));
                    if (success)
                    {
                        count++;
                    }
                    else
                    {
                        if (EmptyWorkingSet(proc.Handle))
                        {
                            count++;
                        }
                    }
                }
                catch
                {
                    // Ignore processes we don't have access to
                }
            }
            return count;
        }

        // Method 1.5: Empty working set of a specific process by ID
        public static bool PurgeProcessWorkingSetById(int processId)
        {
            try
            {
                Process proc = Process.GetProcessById(processId);
                bool success = SetProcessWorkingSetSize(proc.Handle, new IntPtr(-1), new IntPtr(-1));
                if (!success)
                {
                    success = EmptyWorkingSet(proc.Handle);
                }
                return success;
            }
            catch
            {
                return false;
            }
        }

        // Method 2: Purge standby lists (Undocumented API)
        public static uint PurgeStandbyList(bool lowPriorityOnly = false)
        {
            EnableMemoryPrivileges();
            
            SystemMemoryListCommand cmd = lowPriorityOnly 
                ? SystemMemoryListCommand.MemoryPurgeLowPriorityStandbyList 
                : SystemMemoryListCommand.MemoryPurgeStandbyList;

            int commandVal = (int)cmd;
            IntPtr pCommand = Marshal.AllocHGlobal(sizeof(int));
            Marshal.WriteInt32(pCommand, commandVal);

            try
            {
                uint result = NtSetSystemInformation(
                    SystemMemoryListInformation,
                    pCommand,
                    sizeof(int)
                );
                return result; // 0 is STATUS_SUCCESS
            }
            finally
            {
                Marshal.FreeHGlobal(pCommand);
            }
        }

        // Method 3: Flush modified page list (Undocumented API)
        public static uint FlushModifiedPageList()
        {
            EnableMemoryPrivileges();

            int commandVal = (int)SystemMemoryListCommand.MemoryFlushModifiedList;
            IntPtr pCommand = Marshal.AllocHGlobal(sizeof(int));
            Marshal.WriteInt32(pCommand, commandVal);

            try
            {
                uint result = NtSetSystemInformation(
                    SystemMemoryListInformation,
                    pCommand,
                    sizeof(int)
                );
                return result;
            }
            finally
            {
                Marshal.FreeHGlobal(pCommand);
            }
        }

        // Method 4: System memory empty working sets (Undocumented API system-wide)
        public static uint PurgeSystemWorkingSets()
        {
            EnableMemoryPrivileges();

            int commandVal = (int)SystemMemoryListCommand.MemoryEmptyWorkingSets;
            IntPtr pCommand = Marshal.AllocHGlobal(sizeof(int));
            Marshal.WriteInt32(pCommand, commandVal);

            try
            {
                uint result = NtSetSystemInformation(
                    SystemMemoryListInformation,
                    pCommand,
                    sizeof(int)
                );
                return result;
            }
            finally
            {
                Marshal.FreeHGlobal(pCommand);
            }
        }

        // Helper to destroy icon handles to prevent leaks
        public static bool DestroyIconHandle(IntPtr hIcon)
        {
            return DestroyIcon(hIcon);
        }

        // Feature: Set Process Efficiency Mode (EcoQoS + Idle Priority)
        public static bool SetEfficiencyMode(int processId, bool enable)
        {
            try
            {
                Process proc = Process.GetProcessById(processId);
                PROCESS_POWER_THROTTLING_STATE state = new PROCESS_POWER_THROTTLING_STATE();
                state.Version = 1; // PROCESS_POWER_THROTTLING_CURRENT_VERSION
                state.ControlMask = 1; // PROCESS_POWER_THROTTLING_EXECUTION_SPEED
                state.StateMask = enable ? 1u : 0u;

                bool result = SetProcessInformation(proc.Handle, 4, ref state, (uint)Marshal.SizeOf(state));
                
                // Always adjust priority as well
                if (enable) {
                    if (proc.PriorityClass != ProcessPriorityClass.Idle) {
                        proc.PriorityClass = ProcessPriorityClass.Idle;
                    }
                } else {
                    if (proc.PriorityClass == ProcessPriorityClass.Idle) {
                        proc.PriorityClass = ProcessPriorityClass.Normal;
                    }
                }
                return result;
            }
            catch
            {
                return false;
            }
        }
        
        // Feature: Get current foreground process ID
        public static int GetForegroundProcessId()
        {
            IntPtr hWnd = GetForegroundWindow();
            if (hWnd == IntPtr.Zero) return 0;
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            return (int)processId;
        }
    }
}


