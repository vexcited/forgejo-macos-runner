import Foundation

// the few runner.v1 messages the broker inspects or sends, from forgejo actions-proto
// v0.8.0. only the fields used here are modeled.
nonisolated enum RunnerProtobuf {
  enum Field: Equatable {
    case varint(UInt64)
    case bytes(Data)
    case fixed
  }

  // RESULT_FAILURE in the runner.v1 Result enum.
  static let resultFailure: UInt64 = 2

  // the top level fields of a message, nil when the bytes are not valid protobuf.
  static func fields(of data: Data) -> [(number: UInt64, field: Field)]? {
    let bytes = [UInt8](data)
    var index = 0
    var fields: [(number: UInt64, field: Field)] = []
    while index < bytes.count {
      guard let key = readVarint(bytes, &index) else { return nil }
      let number = key >> 3
      guard number > 0 else { return nil }
      switch key & 0x7 {
      case 0:
        guard let value = readVarint(bytes, &index) else { return nil }
        fields.append((number, .varint(value)))
      case 1:
        guard index + 8 <= bytes.count else { return nil }
        index += 8
        fields.append((number, .fixed))
      case 2:
        guard let length = readVarint(bytes, &index), length <= UInt64(bytes.count - index)
        else { return nil }
        let end = index + Int(length)
        fields.append((number, .bytes(Data(bytes[index..<end]))))
        index = end
      case 5:
        guard index + 4 <= bytes.count else { return nil }
        index += 4
        fields.append((number, .fixed))
      default:
        return nil
      }
    }
    return fields
  }

  static func varint(_ number: UInt64, in data: Data) -> UInt64? {
    fields(of: data)?.last { $0.number == number }.flatMap {
      if case .varint(let value) = $0.field { value } else { nil }
    }
  }

  static func message(_ number: UInt64, in data: Data) -> Data? {
    fields(of: data)?.last { $0.number == number }.flatMap {
      if case .bytes(let value) = $0.field { value } else { nil }
    }
  }

  // FetchTaskResponse.task.id, nil when the response carries no task.
  static func taskID(inFetchTaskResponse data: Data) -> Int64? {
    guard let task = message(1, in: data) else { return nil }
    return Int64(bitPattern: varint(1, in: task) ?? 0)
  }

  // FetchTaskResponse.additional_tasks, which a capacity-one session must never get.
  static func hasAdditionalTasks(inFetchTaskResponse data: Data) -> Bool {
    fields(of: data)?.contains { $0.number == 3 } ?? true
  }

  // state.id and state.result of an UpdateTaskRequest or UpdateTaskResponse, which
  // both carry the TaskState as field 1. the result is compared to zero only, forgejo
  // reads it as an int32 enum.
  static func taskState(inUpdateTask data: Data) -> (id: Int64, result: UInt64)? {
    guard let state = message(1, in: data) else { return nil }
    return (Int64(bitPattern: varint(1, in: state) ?? 0), varint(2, in: state) ?? 0)
  }

  // UpdateLogRequest.task_id and UpdateStepSummaryRequest.task_id.
  static func taskID(inTaskScopedRequest data: Data) -> Int64? {
    varint(1, in: data).map { Int64(bitPattern: $0) }
  }

  static func declareRequest(version: String, labels: [String]) -> Data {
    var data = Data()
    appendBytes(1, Data(version.utf8), to: &data)
    for label in labels {
      appendBytes(2, Data(label.utf8), to: &data)
    }
    return data
  }

  // an UpdateTaskRequest that closes the task as failed.
  static func failedTaskRequest(taskID: Int64, stoppedAt: Date) -> Data {
    var timestamp = Data()
    appendVarint(1, UInt64(max(stoppedAt.timeIntervalSince1970, 0)), to: &timestamp)
    var state = Data()
    appendVarint(1, UInt64(bitPattern: taskID), to: &state)
    appendVarint(2, resultFailure, to: &state)
    appendBytes(4, timestamp, to: &state)
    var request = Data()
    appendBytes(1, state, to: &request)
    return request
  }

  private static func readVarint(_ bytes: [UInt8], _ index: inout Int) -> UInt64? {
    var value: UInt64 = 0
    var shift: UInt64 = 0
    while index < bytes.count, shift < 64 {
      let byte = bytes[index]
      index += 1
      value |= UInt64(byte & 0x7f) << shift
      if byte & 0x80 == 0 { return value }
      shift += 7
    }
    return nil
  }

  private static func writeVarint(_ value: UInt64, to data: inout Data) {
    var value = value
    while value >= 0x80 {
      data.append(UInt8(value & 0x7f) | 0x80)
      value >>= 7
    }
    data.append(UInt8(value))
  }

  private static func appendVarint(_ number: UInt64, _ value: UInt64, to data: inout Data) {
    writeVarint(number << 3, to: &data)
    writeVarint(value, to: &data)
  }

  private static func appendBytes(_ number: UInt64, _ value: Data, to data: inout Data) {
    writeVarint(number << 3 | 2, to: &data)
    writeVarint(UInt64(value.count), to: &data)
    data.append(value)
  }
}
