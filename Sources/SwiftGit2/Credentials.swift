//
//  Credentials.swift
//  SwiftGit2
//
//  Created by Tom Booth on 29/02/2016.
//  Copyright © 2016 GitHub, Inc. All rights reserved.
//

import libgit2

private class Wrapper<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

public enum Credentials {
    case `default`
    case sshAgent
    case plaintext(username: String, password: String)
    case sshMemory(username: String, publicKey: String, privateKey: String, passphrase: String)

    static func fromPointer(_ pointer: UnsafeMutableRawPointer) -> Credentials {
        return Unmanaged<Wrapper<Credentials>>.fromOpaque(UnsafeRawPointer(pointer)).takeRetainedValue().value
    }

    func toPointer() -> UnsafeMutableRawPointer {
        return Unmanaged.passRetained(Wrapper(self)).toOpaque()
    }
}

/// Handle the request of credentials, passing through to a wrapped block after converting the arguments.
/// Converts the result to the correct error code required by libgit2 (0 = success, 1 = rejected setting creds,
/// -1 = error)
func credentialsCallback(
    cred: UnsafeMutablePointer<UnsafeMutablePointer<git_cred>?>?,
    url: UnsafePointer<CChar>?,
    username_from_url: UnsafePointer<CChar>?,
    allowed_types: UInt32,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    let result: Int32

    // Find username_from_url
    let name = username_from_url.map(String.init(cString:))

    switch Credentials.fromPointer(payload!) {
    case .default:
        result = git_cred_default_new(cred)
    case .sshAgent:
        result = git_cred_ssh_key_from_agent(cred, name!)
    case let .plaintext(username, password):
        result = git_cred_userpass_plaintext_new(cred, username, password)
    case let .sshMemory(username, publicKey, privateKey, passphrase):
        result = git_cred_ssh_key_memory_new(cred, username, publicKey, privateKey, passphrase)
    }

    return (result != GIT_OK.rawValue) ? -1 : 0
}
