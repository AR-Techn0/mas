//
//  MasAppLibrary.swift
//  MasKit
//
//  Created by Ben Chatelain on 12/27/18.
//  Copyright © 2018 mas-cli. All rights reserved.
//

import CommerceKit

/// Utility for managing installed apps.
public class MasAppLibrary: AppLibrary {
    /// CommerceKit's singleton manager of installed software.
    private let softwareMap = CKSoftwareMap.shared()

    /// Array of installed software products.
    public lazy var installedApps: [SoftwareProduct] = {
        var appList = [SoftwareProduct]()
        guard let products = softwareMap.allProducts()
            else { return appList }
        appList.append(contentsOf: products)
        return products
    }()

    private let trashCommand: ExternalCommand

    public init(trashCommand: ExternalCommand = TrashCommand()) {
        self.trashCommand = trashCommand
    }

    /// Finds an app using a bundle identifier.
    ///
    /// - Parameter bundleId: Bundle identifier of app.
    /// - Returns: Software Product of app if found; nil otherwise.
    public func installedApp(forBundleId bundleId: String) -> SoftwareProduct? {
        return softwareMap.product(forBundleIdentifier: bundleId)
    }

    /// Uninstalls an app.
    ///
    /// - Parameter app: App to be removed.
    /// - Throws: Error if there is a problem.
    public func uninstallApp(app: SoftwareProduct) throws {
        let status = trash(path: app.bundlePath)
        if !status {
            throw MASError.uninstallFailed
        }
    }

    /// Runs the trash command in another process. Relies on the "trash" command
    /// from Homebrew. Trash requires el_capitan or higher for core bottles:
    /// https://github.com/Homebrew/homebrew-core/blob/master/Formula/trash.rb
    ///
    /// - Parameter path: Absolute path to the application bundle to uninstall.
    /// - Returns: true on success; fail on error
    func trash(path: String) -> Bool {
        let binaryPath = "/usr/local/bin/trash"
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.standardOutput = stdout
        process.standardError = stderr
        process.arguments = [path]

        if #available(OSX 10.13, *) {
            process.executableURL = URL(fileURLWithPath: binaryPath)
            do {
                try process.run()
            } catch {
                printError("Unable to launch trash command")
                return false
            }
        } else {
            process.launchPath = binaryPath
            process.launch()
        }

        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return true
        } else {
            let reason = process.terminationReason
            let output = stderr.fileHandleForReading.readDataToEndOfFile()
            printError("Uninstall failed: \(reason)\n\(String(data: output, encoding: .utf8)!)")
            return false
        }
    }
}
