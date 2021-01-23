import winlean, os

template doWhile(a: bool, b:untyped): untyped =
    b
    while a:
        b

type
    # See https://docs.microsoft.com/en-us/windows/win32/api/tlhelp32/ns-tlhelp32-processentry32
    PROCESSENTRY32 = object
        dwSize: DWORD
        cntUsage: DWORD
        th32ProcessID: DWORD
        th32DefaultHeapID: ULONG_PTR
        th32ModuleID: DWORD
        cntThreads: DWORD
        th32ParentProcessID: DWORD
        pcPriClassBase: LONG
        dwFlags: DWORD
        # winlean does not include the CHAR type, but Windows.h just typedefs CHAR to char anyway.
        # Win32 API type names are otherwise used for consistency with the documentation.
        szExeFile: array[MAX_PATH, cchar]

# See https://docs.microsoft.com/en-us/windows/win32/api/tlhelp32/nf-tlhelp32-createtoolhelp32snapshot
proc createToolhelp32Snapshot(dwFlags: DWORD, th32ProcessID: DWORD): Handle
    {.stdcall, dynlib: "kernel32", importc: "CreateToolhelp32Snapshot".}

# See https://docs.microsoft.com/en-us/windows/win32/api/tlhelp32/nf-tlhelp32-process32first
proc process32First(hSnapshot: Handle, lppe: ptr[PROCESSENTRY32]): bool
    {.stdcall, dynlib: "kernel32", importc: "Process32First".}

# See https://docs.microsoft.com/en-us/windows/win32/api/tlhelp32/nf-tlhelp32-process32next
proc process32Next(hSnapshot: Handle, lppe: ptr[PROCESSENTRY32]): bool
    {.stdcall, dynlib: "kernel32", importc: "Process32Next".}

proc getppid(): DWORD =
    let pid = getCurrentProcessId().DWORD
    # dwFlags=2 causes the snapshot to include all currently running processes
    # th32ProcessID=0 refers to the calling process
    let handle = createToolhelp32Snapshot(2, 0)
    var processEntry: PROCESSENTRY32
    processEntry.dwSize = sizeof(PROCESSENTRY32).DWORD

    if process32First(handle, addr processEntry):
        doWhile process32Next(handle, addr processEntry):
            if processEntry.th32ProcessID == pid:
                discard closeHandle handle
                return processEntry.th32ParentProcessID

proc cloneMessenger() =
    var startupInfo: STARTUPINFO
    var processInformation: PROCESS_INFORMATION
    discard createProcessW(
        nil.newWideCString,
        quoteShellCommand([getAppFilename()]).newWideCString,
        nil,
        nil,
        false.WINBOOL,
        # dwFlags = CREATE_BREAKAWAY_FROM_JOB | CREATE_NO_WINDOW
        # See https://docs.microsoft.com/en-gb/windows/win32/procthread/process-creation-flags#CREATE_BREAKAWAY_FROM_JOB
        0x01000000 or 0x08000000,
        nil,
        nil,
        startupInfo,
        processInformation
    )
