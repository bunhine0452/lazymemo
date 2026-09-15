import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// 프로세스 물리 메모리 — 명세 §8 「앱 전체 peak physical memory」.
/// 엔진 allocator 수치와 섞지 않는다. 그건 엔진이 따로 준다.
public enum Footprint {
    /// 지금 이 순간의 phys_footprint (바이트). 실패하면 nil.
    public static func current() -> UInt64? {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.phys_footprint)
        #else
        return nil
        #endif
    }

    /// 프로세스 수명 전체의 최대 footprint. macOS 만 rusage 로 정확히 안다.
    /// iOS 는 `Peak` 표본기로 대신한다.
    public static func lifetimePeak() -> UInt64? {
        #if os(macOS)
        var usage = rusage_info_current()
        let ok = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_CURRENT, $0)
            }
        }
        guard ok == 0 else { return nil }
        return usage.ri_lifetime_max_phys_footprint
        #else
        return nil
        #endif
    }

    public static func megabytes(_ bytes: UInt64?) -> String {
        guard let bytes else { return "-" }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }
}

/// 표본을 모아 최대값을 남긴다 — rusage 가 없는 곳의 대체.
public final class PeakSampler: @unchecked Sendable {
    private var peak: UInt64 = 0
    private let lock = NSLock()
    public init() {}
    public func sample() {
        guard let now = Footprint.current() else { return }
        lock.lock(); defer { lock.unlock() }
        peak = max(peak, now)
    }
    public var value: UInt64 { lock.lock(); defer { lock.unlock() }; return peak }
}
