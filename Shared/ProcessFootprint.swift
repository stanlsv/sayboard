
import Darwin
import Foundation

enum ProcessFootprint {

  static func residentMB() -> Int {
    guard let info = self.vmInfo() else { return 0 }
    return Int(info.phys_footprint / 1_000_000)
  }

  static func fileBackedBytes() -> UInt64 {
    self.vmInfo()?.external ?? 0
  }

  private static func vmInfo() -> task_vm_info_data_t? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    return status == KERN_SUCCESS ? info : nil
  }
}
