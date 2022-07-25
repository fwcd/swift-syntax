//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftSyntax

/// A wrapper around a `TokenSyntax` with kind `.identifier`.
/// This wrapper permits stronger typing in parameters that take
/// identifier tokens and makes them more conveniently initializable
/// by conforming to `ExpressibleByStringLiteral`.
public struct IdentifierToken: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
  /// The wrapped token.
  public let token: TokenSyntax

  /// Creates a new `IdentifierToken` from the given `TokenSyntax`.
  /// Note that the provided `TokenSyntax`'s kind must be `.identifier`.
  /// This assertion is checked by this initializer.
  public init(_ token: TokenSyntax) {
    self.token = token
    assert(token.tokenKind.isIdentifier)
  }

  /// Creates a new `IdentifierToken` from the given identifier.
  public init(_ identifier: String) {
    self.init(.identifier(identifier))
  }

  public init(stringLiteral identifier: String) {
    self.init(identifier)
  }

  /// Returns a new `IdentifierToken` with its leading trivia replaced
  /// by the provided trivia.
  public func withLeadingTrivia(_ leadingTrivia: Trivia) -> Self {
    Self(token.withLeadingTrivia(leadingTrivia))
  }

  /// Returns a new `IdentifierToken` with its trailing trivia replaced
  /// by the provided trivia.
  public func withTrailingTrivia(_ trailingTrivia: Trivia) -> Self {
    Self(token.withTrailingTrivia(trailingTrivia))
  }
}
