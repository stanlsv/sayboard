
import Combine
import CryptoKit
import Foundation

import ZIPFoundation

enum DownloadType: String, Codable, Sendable {
  case stt
  case llm
  case llmUpgrade
}

struct DownloadMetadata: Codable, Sendable {
  let downloadType: DownloadType
  let variantRawValue: String
  let expectedSHA256: String
  let sourceURL: URL
  let destinationDirectory: URL
  let sizeBytes: Int64
  var taskIdentifier: Int?
  var sessionIdentifier: String?
}

enum DownloadEvent: Sendable {
  case progress(downloadType: DownloadType, variantRawValue: String, fraction: Double)
  case completed(downloadType: DownloadType, variantRawValue: String, destinationDirectory: URL)
  case failed(downloadType: DownloadType, variantRawValue: String, error: Error)
}

final class BackgroundDownloadManager: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

  override private init() {
    super.init()
    self.loadPersistedMetadata()
  }

  static let shared = BackgroundDownloadManager()
  static let sessionIdentifier = "app.sayboard.background-downloads"
  static let upgradeSessionIdentifier = "app.sayboard.background-upgrades"

  let eventSubject = PassthroughSubject<DownloadEvent, Never>()

  let lock = NSLock()
  var activeMetadata = [String: DownloadMetadata]()
  var activeTasks = [String: URLSessionDownloadTask]()

  static func ownsSession(identifier: String) -> Bool {
    identifier == Self.sessionIdentifier || identifier == Self.upgradeSessionIdentifier
  }

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

  func storeSystemCompletionHandler(_ handler: @escaping () -> Void, forSession identifier: String) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.systemCompletionHandlers[identifier] = handler
  }

  func enqueueDownload(metadata: DownloadMetadata) {
    self.lock.lock()
    defer { self.lock.unlock() }

    let existingKey = self.metadataKey(for: metadata)
    self.activeTasks[existingKey]?.cancel()

    var request = URLRequest(url: metadata.sourceURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    let session = self.session(for: metadata.downloadType)
    let task = session.downloadTask(with: request)

    var updatedMetadata = metadata
    updatedMetadata.taskIdentifier = task.taskIdentifier
    updatedMetadata.sessionIdentifier = session.configuration.identifier
    self.activeMetadata[existingKey] = updatedMetadata
    self.activeTasks[existingKey] = task

    self.persistMetadata()

    task.resume()
  }

  func cancelDownload(variantRawValue: String, downloadType: DownloadType) {
    self.lock.lock()
    let key = "\(downloadType.rawValue)/\(variantRawValue)"
    self.activeMetadata.removeValue(forKey: key)
    let task = self.activeTasks.removeValue(forKey: key)
    self.persistMetadata()
    self.lock.unlock()

    task?.cancel()
  }

  func restoreSession() {
    self.lock.lock()
    self.loadPersistedMetadata()
    let metadataCopy = self.activeMetadata
    self.lock.unlock()

    guard !metadataCopy.isEmpty else {
      return
    }

    for session in [self.session, self.upgradeSession] {
      session.getAllTasks { [weak self] tasks in
        self?.reconcileMetadataWithTasks(tasks, sessionIdentifier: session.configuration.identifier)
      }
    }
  }

  func hasActiveDownload(variantRawValue: String, downloadType: DownloadType) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    let key = "\(downloadType.rawValue)/\(variantRawValue)"
    return self.activeMetadata[key] != nil
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let taskId = downloadTask.taskIdentifier

    self.lock.lock()
    guard
      let (key, metadata) = self.findMetadata(
        sessionIdentifier: session.configuration.identifier,
        taskIdentifier: taskId,
      )
    else {
      self.lock.unlock()
      return
    }
    self.lock.unlock()

    let fm = FileManager.default
    let tempURL = fm.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("zip")

    do {
      try fm.moveItem(at: location, to: tempURL)
    } catch {
      self.completeWithFailure(key: key, metadata: metadata, error: R2DownloadError.downloadFailed(error))
      return
    }

    self.processingQueue.async {
      self.processDownloadedFile(tempURL: tempURL, key: key, metadata: metadata)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error else { return }

    let taskId = task.taskIdentifier
    let sessionID = session.configuration.identifier
    let nsError = error as NSError

    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
      self.lock.lock()
      if let (key, _) = self.findMetadata(sessionIdentifier: sessionID, taskIdentifier: taskId) {
        self.activeMetadata.removeValue(forKey: key)
        self.activeTasks.removeValue(forKey: key)
        self.persistMetadata()
      }
      self.lock.unlock()
      return
    }

    self.lock.lock()
    guard let (key, metadata) = self.findMetadata(sessionIdentifier: sessionID, taskIdentifier: taskId) else {
      self.lock.unlock()
      return
    }
    self.lock.unlock()

    self.completeWithFailure(key: key, metadata: metadata, error: R2DownloadError.downloadFailed(error))
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData _: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64,
  ) {
    guard totalBytesExpectedToWrite > 0 else { return }
    let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

    self.lock.lock()
    guard
      let (_, metadata) = self.findMetadata(
        sessionIdentifier: session.configuration.identifier,
        taskIdentifier: downloadTask.taskIdentifier,
      )
    else {
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

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    let identifier = session.configuration.identifier ?? Self.sessionIdentifier

    self.lock.lock()
    let handler = self.systemCompletionHandlers.removeValue(forKey: identifier)
    self.lock.unlock()

    guard let handler else { return }
    DispatchQueue.main.async { handler() }
  }

  func findMetadata(sessionIdentifier: String?, taskIdentifier: Int) -> (key: String, metadata: DownloadMetadata)? {
    for (key, meta) in self.activeMetadata where meta.taskIdentifier == taskIdentifier {
      let owner = meta.sessionIdentifier ?? Self.sessionIdentifier
      if owner == (sessionIdentifier ?? Self.sessionIdentifier) {
        return (key, meta)
      }
    }
    return nil
  }

  func completeWithFailure(key: String, metadata: DownloadMetadata, error: Error) {
    self.lock.lock()
    self.activeMetadata.removeValue(forKey: key)
    self.activeTasks.removeValue(forKey: key)
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
    } catch { }
  }

  private static let hashBufferSize = 1_048_576
  private static let resourceTimeout: TimeInterval = 3600

  private let processingQueue = DispatchQueue(label: "app.sayboard.download-processing")

  private var systemCompletionHandlers = [String: () -> Void]()

  private lazy var session: URLSession = self.makeSession(
    identifier: Self.sessionIdentifier,
    allowsExpensiveNetwork: true,
  )

  private lazy var upgradeSession: URLSession = self.makeSession(
    identifier: Self.upgradeSessionIdentifier,
    allowsExpensiveNetwork: false,
  )

  private var metadataFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent("active-downloads.json")
  }

  private func makeSession(identifier: String, allowsExpensiveNetwork: Bool) -> URLSession {
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.timeoutIntervalForResource = Self.resourceTimeout
    config.allowsExpensiveNetworkAccess = allowsExpensiveNetwork
    config.allowsConstrainedNetworkAccess = allowsExpensiveNetwork
    if AppGroup.containerURL != nil {
      config.sharedContainerIdentifier = AppGroup.identifier
    }

    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.name = "BackgroundDownloadDelegateQueue"

    return URLSession(configuration: config, delegate: self, delegateQueue: queue)
  }

  private func session(for downloadType: DownloadType) -> URLSession {
    switch downloadType {
    case .stt, .llm: self.session
    case .llmUpgrade: self.upgradeSession
    }
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
