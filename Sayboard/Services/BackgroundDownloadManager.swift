// BackgroundDownloadManager -- Background URLSession for model downloads (STT + LLM)

import Combine
import CryptoKit
import Foundation

import ZIPFoundation

// MARK: - DownloadType

enum DownloadType: String, Codable, Sendable {
  case stt
  case llm
}

// MARK: - DownloadMetadata

struct DownloadMetadata: Codable, Sendable {
  let downloadType: DownloadType
  let variantRawValue: String
  let expectedSHA256: String
  let sourceURL: URL
  let destinationDirectory: URL
  let sizeBytes: Int64
  var taskIdentifier: Int?
}

// MARK: - DownloadEvent

enum DownloadEvent: Sendable {
  case progress(downloadType: DownloadType, variantRawValue: String, fraction: Double)
  case completed(downloadType: DownloadType, variantRawValue: String, destinationDirectory: URL)
  case failed(downloadType: DownloadType, variantRawValue: String, error: Error)
}

// MARK: - BackgroundDownloadManager

// swiftlint:disable:next no_unchecked_sendable
final class BackgroundDownloadManager: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

  // MARK: Lifecycle

  override private init() {
    super.init()
    self.loadPersistedMetadata()
  }

  // MARK: Internal

  static let shared = BackgroundDownloadManager()
  static let sessionIdentifier = "app.sayboard.background-downloads"

  let eventSubject = PassthroughSubject<DownloadEvent, Never>()

  /// Stored by AppDelegate when the system relaunches the app for background session events.
  var systemCompletionHandler: (() -> Void)?

  let lock = NSLock()
  var activeMetadata = [String: DownloadMetadata]()

  static func computeSHA256(of fileURL: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }

    var hasher = SHA256()
    while
      autoreleasepool(invoking: {
        let chunk = handle.readData(ofLength: hashBufferSize)
        guard !chunk.isEmpty else { return false }
        hasher.update(data: chunk)
        return true
      }) { }

    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  func enqueueDownload(metadata: DownloadMetadata) {
    self.lock.lock()
    defer { self.lock.unlock() }

    // Cancel any existing download for the same variant+type
    let existingKey = self.metadataKey(for: metadata)
    if let existingTaskId = self.activeMetadata[existingKey]?.taskIdentifier {
      self.session.getAllTasks { tasks in
        tasks.first { $0.taskIdentifier == existingTaskId }?.cancel()
      }
    }

    var request = URLRequest(url: metadata.sourceURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    let task = self.session.downloadTask(with: request)

    var updatedMetadata = metadata
    updatedMetadata.taskIdentifier = task.taskIdentifier
    self.activeMetadata[existingKey] = updatedMetadata

    self.persistMetadata()

    task.resume()
  }

  func cancelDownload(variantRawValue: String, downloadType: DownloadType) {
    self.lock.lock()
    let key = "\(downloadType.rawValue)/\(variantRawValue)"
    let taskId = self.activeMetadata[key]?.taskIdentifier
    self.activeMetadata.removeValue(forKey: key)
    self.persistMetadata()
    self.lock.unlock()

    guard let taskId else { return }
    self.session.getAllTasks { tasks in
      tasks.first { $0.taskIdentifier == taskId }?.cancel()
    }
  }

  /// Called at app launch to reconcile persisted metadata with live session tasks.
  func restoreSession() {
    self.lock.lock()
    self.loadPersistedMetadata()
    let metadataCopy = self.activeMetadata
    self.lock.unlock()

    guard !metadataCopy.isEmpty else {
      return
    }

    // Access the session to trigger reconnection with the background daemon.
    // The delegate callbacks will fire for any completed/in-progress tasks.
    _ = self.session

    self.session.getAllTasks { [weak self] tasks in
      self?.reconcileMetadataWithTasks(tasks)
    }
  }

  /// Check if there is an active download for the given variant and type.
  func hasActiveDownload(variantRawValue: String, downloadType: DownloadType) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    let key = "\(downloadType.rawValue)/\(variantRawValue)"
    return self.activeMetadata[key] != nil
  }

  func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let taskId = downloadTask.taskIdentifier

    self.lock.lock()
    guard let (key, metadata) = self.findMetadata(for: taskId) else {
      self.lock.unlock()
      return
    }
    self.lock.unlock()

    self.processCompletedDownload(location: location, key: key, metadata: metadata)
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error else { return }

    let taskId = task.taskIdentifier
    let nsError = error as NSError

    // Ignore cancellations from the user calling cancelDownload
    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
      self.lock.lock()
      if let (key, _) = self.findMetadata(for: taskId) {
        self.activeMetadata.removeValue(forKey: key)
        self.persistMetadata()
      }
      self.lock.unlock()
      return
    }

    self.lock.lock()
    guard let (key, metadata) = self.findMetadata(for: taskId) else {
      self.lock.unlock()
      return
    }
    self.lock.unlock()

    self.completeWithFailure(key: key, metadata: metadata, error: R2DownloadError.downloadFailed(error))
  }

  func urlSession(
    _: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData _: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64,
  ) {
    guard totalBytesExpectedToWrite > 0 else { return }
    let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

    self.lock.lock()
    guard let (_, metadata) = self.findMetadata(for: downloadTask.taskIdentifier) else {
      self.lock.unlock()
      return
    }
    self.lock.unlock()

    let event = DownloadEvent.progress(
      downloadType: metadata.downloadType,
      variantRawValue: metadata.variantRawValue,
      fraction: fraction,
    )
    DispatchQueue.main.async { self.eventSubject.send(event) }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
    DispatchQueue.main.async { [weak self] in
      self?.systemCompletionHandler?()
      self?.systemCompletionHandler = nil
    }
  }

  /// Finds metadata for a given task identifier. Must be called with lock held.
  func findMetadata(for taskIdentifier: Int) -> (key: String, metadata: DownloadMetadata)? {
    for (key, meta) in self.activeMetadata where meta.taskIdentifier == taskIdentifier {
      return (key, meta)
    }
    return nil
  }

  func completeWithFailure(key: String, metadata: DownloadMetadata, error: Error) {
    self.lock.lock()
    self.activeMetadata.removeValue(forKey: key)
    self.persistMetadata()
    self.lock.unlock()

    let event = DownloadEvent.failed(
      downloadType: metadata.downloadType,
      variantRawValue: metadata.variantRawValue,
      error: error,
    )
    DispatchQueue.main.async { self.eventSubject.send(event) }
  }

  func persistMetadata() {
    guard let fileURL = self.metadataFileURL else { return }
    do {
      let data = try JSONEncoder().encode(self.activeMetadata)
      try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    } catch {
      // no-op
    }
  }

  // MARK: Private

  private static let hashBufferSize = 1_048_576 // 1 MB
  private static let resourceTimeout: TimeInterval = 3600 // 1 hour

  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.timeoutIntervalForResource = Self.resourceTimeout
    if let containerID = AppGroup.containerURL?.path {
      config.sharedContainerIdentifier = AppGroup.identifier
    }

    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.name = "BackgroundDownloadDelegateQueue"

    return URLSession(configuration: config, delegate: self, delegateQueue: queue)
  }()

  private var metadataFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent("active-downloads.json")
  }

  private func metadataKey(for metadata: DownloadMetadata) -> String {
    "\(metadata.downloadType.rawValue)/\(metadata.variantRawValue)"
  }

  private func loadPersistedMetadata() {
    guard let fileURL = self.metadataFileURL else { return }
    let fm = FileManager.default
    guard fm.fileExists(atPath: fileURL.path) else { return }
    do {
      let data = try Data(contentsOf: fileURL)
      self.activeMetadata = try JSONDecoder().decode([String: DownloadMetadata].self, from: data)
    } catch {
      self.activeMetadata = [:]
      try? fm.removeItem(at: fileURL)
    }
  }

}
