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

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

let buildableCollectionNodesFile = SourceFile {
  ImportDecl(
    leadingTrivia: .docLineComment(copyrightHeader),
    path: "SwiftSyntax"
  )

  for node in SYNTAX_NODES where node.isSyntaxCollection {
    let type = node.type
    let elementType = node.collectionElementType
    let conformances = ["ExpressibleByArrayLiteral", "SyntaxBuildable", type.expressibleAs]
    
    StructDecl(
      leadingTrivia: node.documentation.isEmpty
        ? []
        : .docLineComment("/// \(node.documentation)") + .newline,
      modifiers: [TokenSyntax.public],
      identifier: type.buildable,
      inheritanceClause: createTypeInheritanceClause(conformances: conformances)
    ) {
      VariableDecl(.let, name: "elements", type: ArrayType(elementType: elementType.buildable))

      InitializerDecl(
        leadingTrivia: [
          "/// Creates a `\(type.buildable)` with the provided list of elements.",
          "/// - Parameters:",
          "/// - elements: A list of `\(elementType.expressibleAs)`",
        ].map { .docLineComment($0) + .newline }.reduce([], +),
        modifiers: [TokenSyntax.public],
        signature: FunctionSignature(
          input: ParameterClause(
            parameterList: FunctionParameter(
              firstName: .wildcard,
              secondName: .identifier("elements"),
              colon: .colon,
              type: ArrayType(elementType: elementType.expressibleAs)
            )
          )
        )
      ) {
        SequenceExpr {
          MemberAccessExpr(base: "self", name: "elements")
          AssignmentExpr()
          if elementType.isToken {
            "elements"
          } else {
            FunctionCallExpr(MemberAccessExpr(base: "elements", name: "map"), trailingClosure: ClosureExpr {
              FunctionCallExpr(MemberAccessExpr(base: "$0", name: "create\(elementType.buildableBaseName)"))
            })
          }
        }
      }

      InitializerDecl(
        leadingTrivia: .docLineComment("/// Creates a new `\(type.buildable)` by flattening the elements in `lists`") + .newline,
        modifiers: [TokenSyntax.public],
        signature: FunctionSignature(
          input: ParameterClause(
            parameterList: FunctionParameter(
              firstName: .identifier("combining").withTrailingTrivia(.space),
              secondName: .identifier("lists"),
              colon: .colon,
              type: ArrayType(elementType: type.expressibleAs)
            )
          )
        )
      ) {
        SequenceExpr {
          "elements"
          AssignmentExpr()
          FunctionCallExpr(MemberAccessExpr(base: "lists", name: "flatMap"), trailingClosure: ClosureExpr {
            MemberAccessExpr(
              base: FunctionCallExpr(MemberAccessExpr(base: "$0", name: "create\(type.buildable)")),
              name: "elements"
            )
          })
        }
      }

      InitializerDecl(
        modifiers: [TokenSyntax.public],
        signature: FunctionSignature(
          input: ParameterClause(
            parameterList: FunctionParameter(
              firstName: .identifier("arrayLiteral").withTrailingTrivia(.space),
              secondName: .identifier("elements"),
              colon: .colon,
              type: elementType.expressibleAs,
              ellipsis: .ellipsis
            )
          )
        )
      ) {
        FunctionCallExpr(MemberAccessExpr(base: "self", name: "init")) {
          TupleExprElement(expression: "elements")
        }
      }

      FunctionDecl(
        modifiers: [TokenSyntax.public],
        identifier: .identifier("build\(type.baseName)"),
        signature: FunctionSignature(
          input: createFormatLeadingTriviaParameters(withDefaultTrivia: true),
          output: type.syntax
        )
      ) {
        VariableDecl(
          .let,
          name: "result",
          initializer: FunctionCallExpr(MemberAccessExpr(base: "SyntaxFactory", name: "make\(type.baseName)")) {
            if elementType.isToken {
              TupleExprElement(expression: "elements")
            } else {
              TupleExprElement(
                expression: FunctionCallExpr(MemberAccessExpr(base: "elements", name: "map"), trailingClosure: ClosureExpr {
                  FunctionCallExpr(MemberAccessExpr(base: "$0", name: "build\(elementType.baseName)")) {
                    TupleExprElement(label: "format", expression: "format")
                    TupleExprElement(
                      label: "leadingTrivia",
                      expression: node.elementsSeparatedByNewline
                        ? SequenceExpr {
                            MemberAccessExpr(base: "Trivia", name: "newline")
                            BinaryOperatorExpr("+")
                            FunctionCallExpr(MemberAccessExpr(base: "format", name: "_makeIndent"))
                          }
                        : "nil"
                    )
                  }
                })
              )
            }
          }
        )
        IfStmt(
          conditions: OptionalBindingCondition(
            letOrVarKeyword: .let,
            pattern: "leadingTrivia",
            initializer: "leadingTrivia"
          )
        ) {
          ReturnStmt(expression: FunctionCallExpr(MemberAccessExpr(base: "result", name: "withLeadingTrivia")) {
            TupleExprElement(expression: FunctionCallExpr(MemberAccessExpr(
              base: SequenceExpr {
                "leadingTrivia"
                BinaryOperatorExpr("+")
                TupleExpr {
                  SequenceExpr {
                    MemberAccessExpr(base: "result", name: "leadingTrivia")
                    BinaryOperatorExpr("??")
                    ArrayExpr(elements: [])
                  }
                }
              },
              name: "addingSpacingAfterNewlinesIfNeeded"
            )))
          })
        } elseBody: {
          ReturnStmt(expression: "result")
        }
      }

      FunctionDecl(
        modifiers: [TokenSyntax.public],
        identifier: .identifier("buildSyntax"),
        signature: FunctionSignature(
          input: createFormatLeadingTriviaParameters(withDefaultTrivia: true),
          output: "Syntax"
        )
      ) {
        ReturnStmt(expression: FunctionCallExpr("Syntax") {
          TupleExprElement(expression: FunctionCallExpr("build\(type.baseName)") {
            TupleExprElement(label: "format", expression: "format")
            TupleExprElement(label: "leadingTrivia", expression: "leadingTrivia")
          })
        })
      }

      FunctionDecl(
        leadingTrivia: .docLineComment("/// Conformance to `\(type.expressibleAs)`") + .newline,
        modifiers: [TokenSyntax.public],
        identifier: .identifier("create\(type.buildableBaseName)"),
        signature: FunctionSignature(
          input: ParameterClause(),
          output: type.buildable
        )
      ) {
        ReturnStmt(expression: "self")
      }

      FunctionDecl(
        leadingTrivia: [
          "/// `\(type.buildable)` might conform to `SyntaxBuildable` via different `ExpressibleAs*` paths.",
          "/// Thus, there are multiple default implementations for `createSyntaxBuildable`, some of which perform conversions through `ExpressibleAs*` protocols.",
          "/// To resolve the ambiguity, provide a fixed implementation that doesn't perform any conversions.",
        ].map { .docLineComment($0) + .newline }.reduce([], +),
        modifiers: [TokenSyntax.public],
        identifier: .identifier("createSyntaxBuildable"),
        signature: FunctionSignature(
          input: ParameterClause(),
          output: "SyntaxBuildable"
        )
      ) {
        ReturnStmt(expression: "self")
      }
    }

    if type.generatedExpressibleAsConformances.isEmpty {
      ExtensionDecl(
        extendedType: "Array",
        inheritanceClause: TypeInheritanceClause {
          InheritedType(typeName: type.expressibleAs)
        },
        genericWhereClause: GenericWhereClause(leadingTrivia: .space) {
          GenericRequirement(body: SameTypeRequirement(
            leftTypeIdentifier: "Element",
            equalityToken: .spacedBinaryOperator("=="),
            rightTypeIdentifier: elementType.expressibleAs
          ))
        }
      ) {
        FunctionDecl(
          modifiers: [TokenSyntax.public],
          identifier: .identifier("create\(type.buildableBaseName)"),
          signature: FunctionSignature(
            input: ParameterClause(),
            output: type.buildable
          )
        ) {
          ReturnStmt(expression: FunctionCallExpr(type.buildable) {
            TupleExprElement(expression: "self")
          })
        }
      }
    }
  }
}
