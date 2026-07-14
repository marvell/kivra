import Darwin
import Foundation

final class ApplicationInstanceLock {
    enum LockError: Error {
        case alreadyHeld
        case cannotCreateDirectory(Error)
        case cannotOpenFile(Int32)
    }

    private static let defaultURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.zemliakov.kivra", isDirectory: true)
        .appendingPathComponent("instance.lock")

    private let fileHandle: FileHandle

    init(fileURL: URL = defaultURL) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw LockError.cannotCreateDirectory(error)
        }

        let descriptor = open(fileURL.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            throw LockError.cannotOpenFile(errno)
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

        guard flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            try? handle.close()
            throw LockError.alreadyHeld
        }
        fileHandle = handle
    }

    deinit {
        flock(fileHandle.fileDescriptor, LOCK_UN)
        try? fileHandle.close()
    }
}
