import Foundation
import Testing
@testable import Sayboard

private let osBuild = "24A437"
private let entryKey = "3f9c0d2e"
private let programFileName = "bnns_program.bnnsir"
private let pollAttempts = 100
private let pollInterval = Duration.milliseconds(20)

@Suite("ModelStorageManager.ensurePersistentCoreMLCache")
struct CoreMLCacheSymlinkTests {

  @Test
  func `entries left behind by a moved container are deleted and the link is repointed`() async throws {
    let root = try Self.makeRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let caches = Self.cachesURL(in: root, container: "New")
    let persistent = Self.persistentURL(in: root, container: "New")
    let trash = root.appendingPathComponent("Trash", isDirectory: true)
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    let program = try Self.writeCompiledEntry(in: persistent)
    try Self.link(caches, to: Self.persistentURL(in: root, container: "Old"))

    ModelStorageManager.ensurePersistentCoreMLCache(cachesURL: caches, persistentURL: persistent, trashDirectory: trash)

    #expect(!FileManager.default.fileExists(atPath: program.path))
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: caches.path) == persistent.path)
    #expect(try await Self.becomesEmpty(trash))
  }

  @Test
  func `entries behind a current link are kept`() throws {
    let root = try Self.makeRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let caches = Self.cachesURL(in: root, container: "Current")
    let persistent = Self.persistentURL(in: root, container: "Current")
    let program = try Self.writeCompiledEntry(in: persistent)
    try Self.link(caches, to: persistent)

    ModelStorageManager.ensurePersistentCoreMLCache(cachesURL: caches, persistentURL: persistent)

    #expect(FileManager.default.fileExists(atPath: program.path))
  }

  @Test
  func `a cache an earlier launch failed to delete is swept, and the rest of tmp is left alone`() async throws {
    let root = try Self.makeRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let caches = Self.cachesURL(in: root, container: "Current")
    let persistent = Self.persistentURL(in: root, container: "Current")
    let trash = root.appendingPathComponent("Trash", isDirectory: true)
    let leftover = trash.appendingPathComponent("CoreMLCache-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: leftover, withIntermediateDirectories: true)
    let unrelated = trash.appendingPathComponent("recording.caf")
    try Data([0]).write(to: unrelated)
    try Self.link(caches, to: persistent)

    ModelStorageManager.ensurePersistentCoreMLCache(cachesURL: caches, persistentURL: persistent, trashDirectory: trash)

    #expect(try await Self.disappears(leftover))
    #expect(FileManager.default.fileExists(atPath: unrelated.path))
  }

  private static func makeRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private static func cachesURL(in root: URL, container: String) -> URL {
    root.appendingPathComponent("\(container)/Library/Caches/app.sayboard/com.apple.e5rt.e5bundlecache")
  }

  private static func persistentURL(in root: URL, container: String) -> URL {
    root.appendingPathComponent("\(container)/Library/Application Support/app.sayboard/CoreMLCache")
  }

  private static func writeCompiledEntry(in persistent: URL) throws -> URL {
    let entry = persistent.appendingPathComponent("\(osBuild)/\(entryKey)", isDirectory: true)
    try FileManager.default.createDirectory(at: entry, withIntermediateDirectories: true)
    let program = entry.appendingPathComponent(programFileName)
    try Data([0]).write(to: program)
    return program
  }

  private static func disappears(_ url: URL) async throws -> Bool {
    for _ in 0..<pollAttempts {
      if !FileManager.default.fileExists(atPath: url.path) { return true }
      try await Task.sleep(for: pollInterval)
    }
    return false
  }

  private static func becomesEmpty(_ directory: URL) async throws -> Bool {
    for _ in 0..<pollAttempts {
      if try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty {
        return true
      }
      try await Task.sleep(for: pollInterval)
    }
    return false
  }

  private static func link(_ caches: URL, to destination: URL) throws {
    try FileManager.default.createDirectory(at: caches.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: caches, withDestinationURL: destination)
  }
}
