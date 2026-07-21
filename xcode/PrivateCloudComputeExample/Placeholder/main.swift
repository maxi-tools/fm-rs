import Foundation

// Xcode needs a native app target to manage the restricted entitlement's
// provisioning profile. The post-build phase replaces this placeholder with
// the Rust example before Xcode signs the app bundle.
FileHandle.standardError.write(Data("Rust executable was not installed\n".utf8))
exit(1)
