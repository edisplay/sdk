// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.fangorn;

import 'dart:core' hide MapEntry;

import 'package:kernel/ast.dart'
    show
        Arguments,
        AssertInitializer,
        BreakStatement,
        Block,
        Catch,
        ContinueSwitchStatement,
        DartType,
        EmptyStatement,
        Expression,
        ExpressionStatement,
        InvalidExpression,
        LabeledStatement,
        Let,
        LibraryDependency,
        MapEntry,
        NamedExpression,
        Statement,
        SwitchCase,
        ThisExpression,
        TreeNode,
        VariableDeclaration,
        setParents;

import '../parser.dart' show offsetForToken, optional;

import '../problems.dart' show unsupported;

import '../scanner.dart' show Token;

import 'kernel_shadow_ast.dart'
    show
        ShadowArguments,
        ShadowAsExpression,
        ShadowAssertInitializer,
        ShadowAssertStatement,
        ShadowAwaitExpression,
        ShadowBlock,
        ShadowBoolLiteral,
        ShadowBreakStatement,
        ShadowCheckLibraryIsLoaded,
        ShadowConditionalExpression,
        ShadowDoStatement,
        ShadowDoubleLiteral,
        ShadowExpressionStatement,
        ShadowIfStatement,
        ShadowIntLiteral,
        ShadowIsExpression,
        ShadowIsNotExpression,
        ShadowLabeledStatement,
        ShadowListLiteral,
        ShadowLoadLibrary,
        ShadowMapLiteral,
        ShadowNot,
        ShadowNullLiteral,
        ShadowRethrow,
        ShadowReturnStatement,
        ShadowStringConcatenation,
        ShadowStringLiteral,
        ShadowSymbolLiteral,
        ShadowSyntheticExpression,
        ShadowThisExpression,
        ShadowThrow,
        ShadowTryCatch,
        ShadowTryFinally,
        ShadowTypeLiteral,
        ShadowWhileStatement,
        ShadowYieldStatement;

import 'forest.dart' show Forest;

/// A shadow tree factory.
class Fangorn extends Forest<Expression, Statement, Token, Arguments> {
  const Fangorn();

  @override
  ShadowArguments arguments(List<Expression> positional, Token token,
      {List<DartType> types, List<NamedExpression> named}) {
    return new ShadowArguments(positional, types: types, named: named)
      ..fileOffset = offsetForToken(token);
  }

  @override
  ShadowArguments argumentsEmpty(Token token) {
    return arguments(<Expression>[], token);
  }

  @override
  List<NamedExpression> argumentsNamed(Arguments arguments) {
    return arguments.named;
  }

  @override
  List<Expression> argumentsPositional(Arguments arguments) {
    return arguments.positional;
  }

  @override
  List<DartType> argumentsTypeArguments(Arguments arguments) {
    return arguments.types;
  }

  @override
  void argumentsSetTypeArguments(Arguments arguments, List<DartType> types) {
    ShadowArguments.setNonInferrableArgumentTypes(arguments, types);
  }

  @override
  ShadowStringLiteral asLiteralString(Expression value) => value;

  @override
  ShadowBoolLiteral literalBool(bool value, Token token) {
    return new ShadowBoolLiteral(value)..fileOffset = offsetForToken(token);
  }

  @override
  ShadowDoubleLiteral literalDouble(double value, Token token) {
    return new ShadowDoubleLiteral(value)..fileOffset = offsetForToken(token);
  }

  @override
  ShadowIntLiteral literalInt(int value, Token token) {
    return new ShadowIntLiteral(value)..fileOffset = offsetForToken(token);
  }

  @override
  ShadowListLiteral literalList(
      Token constKeyword,
      bool isConst,
      Object typeArgument,
      Object typeArguments,
      Token leftBracket,
      List<Expression> expressions,
      Token rightBracket) {
    // TODO(brianwilkerson): The file offset computed below will not be correct
    // if there are type arguments but no `const` keyword.
    return new ShadowListLiteral(expressions,
        typeArgument: typeArgument, isConst: isConst)
      ..fileOffset = offsetForToken(constKeyword ?? leftBracket);
  }

  @override
  ShadowMapLiteral literalMap(
      Token constKeyword,
      bool isConst,
      DartType keyType,
      DartType valueType,
      Object typeArguments,
      Token leftBracket,
      List<MapEntry> entries,
      Token rightBracket) {
    // TODO(brianwilkerson): The file offset computed below will not be correct
    // if there are type arguments but no `const` keyword.
    return new ShadowMapLiteral(entries,
        keyType: keyType, valueType: valueType, isConst: isConst)
      ..fileOffset = offsetForToken(constKeyword ?? leftBracket);
  }

  @override
  ShadowNullLiteral literalNull(Token token) {
    return new ShadowNullLiteral()..fileOffset = offsetForToken(token);
  }

  @override
  ShadowStringLiteral literalString(String value, Token token) {
    return new ShadowStringLiteral(value)..fileOffset = offsetForToken(token);
  }

  @override
  ShadowSymbolLiteral literalSymbolMultiple(String value, Token hash, _) {
    return new ShadowSymbolLiteral(value)..fileOffset = offsetForToken(hash);
  }

  @override
  ShadowSymbolLiteral literalSymbolSingluar(String value, Token hash, _) {
    return new ShadowSymbolLiteral(value)..fileOffset = offsetForToken(hash);
  }

  @override
  ShadowTypeLiteral literalType(DartType type, Token token) {
    return new ShadowTypeLiteral(type)..fileOffset = offsetForToken(token);
  }

  @override
  MapEntry mapEntry(Expression key, Token colon, Expression value) {
    return new MapEntry(key, value)..fileOffset = offsetForToken(colon);
  }

  @override
  List<MapEntry> mapEntryList(int length) {
    return new List<MapEntry>.filled(length, null, growable: true);
  }

  @override
  int readOffset(TreeNode node) => node.fileOffset;

  @override
  int getTypeCount(List typeArguments) => typeArguments.length;

  @override
  DartType getTypeAt(List typeArguments, int index) => typeArguments[index];

  @override
  Expression loadLibrary(LibraryDependency dependency) {
    return new ShadowLoadLibrary(dependency);
  }

  @override
  Expression checkLibraryIsLoaded(LibraryDependency dependency) {
    return new ShadowCheckLibraryIsLoaded(dependency);
  }

  @override
  Expression asExpression(Expression expression, covariant type, Token token) {
    return new ShadowAsExpression(expression, type)
      ..fileOffset = offsetForToken(token);
  }

  @override
  AssertInitializer assertInitializer(
      Token assertKeyword,
      Token leftParenthesis,
      Expression condition,
      Token comma,
      Expression message) {
    return new ShadowAssertInitializer(assertStatement(
        assertKeyword, leftParenthesis, condition, comma, message, null));
  }

  @override
  Statement assertStatement(Token assertKeyword, Token leftParenthesis,
      Expression condition, Token comma, Expression message, Token semicolon) {
    // Compute start and end offsets for the condition expression.
    // This code is a temporary workaround because expressions don't carry
    // their start and end offsets currently.
    //
    // The token that follows leftParenthesis is considered to be the
    // first token of the condition.
    // TODO(ahe): this really should be condition.fileOffset.
    int startOffset = leftParenthesis.next.offset;
    int endOffset;
    {
      // Search forward from leftParenthesis to find the last token of
      // the condition - which is a token immediately followed by a commaToken,
      // right parenthesis or a trailing comma.
      Token conditionBoundary = comma ?? leftParenthesis.endGroup;
      Token conditionLastToken = leftParenthesis;
      while (!conditionLastToken.isEof) {
        Token nextToken = conditionLastToken.next;
        if (nextToken == conditionBoundary) {
          break;
        } else if (optional(',', nextToken) &&
            nextToken.next == conditionBoundary) {
          // The next token is trailing comma, which means current token is
          // the last token of the condition.
          break;
        }
        conditionLastToken = nextToken;
      }
      if (conditionLastToken.isEof) {
        endOffset = startOffset = -1;
      } else {
        endOffset = conditionLastToken.offset + conditionLastToken.length;
      }
    }
    return new ShadowAssertStatement(condition,
        conditionStartOffset: startOffset,
        conditionEndOffset: endOffset,
        message: message);
  }

  @override
  Expression awaitExpression(Expression operand, Token token) {
    return new ShadowAwaitExpression(operand)
      ..fileOffset = offsetForToken(token);
  }

  @override
  Statement block(
      Token openBrace, List<Statement> statements, Token closeBrace) {
    List<Statement> copy;
    for (int i = 0; i < statements.length; i++) {
      Statement statement = statements[i];
      if (statement is _VariablesDeclaration) {
        copy ??= new List<Statement>.from(statements.getRange(0, i));
        copy.addAll(statement.declarations);
      } else if (copy != null) {
        copy.add(statement);
      }
    }
    return new ShadowBlock(copy ?? statements)
      ..fileOffset = offsetForToken(openBrace);
  }

  @override
  Statement breakStatement(Token breakKeyword, Object label, Token semicolon) {
    return new ShadowBreakStatement(null)..fileOffset = breakKeyword.charOffset;
  }

  @override
  Expression conditionalExpression(Expression condition, Token question,
      Expression thenExpression, Token colon, Expression elseExpression) {
    return new ShadowConditionalExpression(
        condition, thenExpression, elseExpression)
      ..fileOffset = offsetForToken(question);
  }

  @override
  Statement continueStatement(
      Token continueKeyword, Object label, Token semicolon) {
    return new ShadowBreakStatement(null)
      ..fileOffset = continueKeyword.charOffset;
  }

  @override
  Statement doStatement(Token doKeyword, Statement body, Token whileKeyword,
      Expression condition, Token semicolon) {
    return new ShadowDoStatement(body, condition)
      ..fileOffset = doKeyword.charOffset;
  }

  Statement expressionStatement(Expression expression, Token semicolon) {
    return new ShadowExpressionStatement(expression);
  }

  @override
  Statement emptyStatement(Token semicolon) {
    return new EmptyStatement();
  }

  @override
  Statement ifStatement(Token ifKeyword, Expression condition,
      Statement thenStatement, Token elseKeyword, Statement elseStatement) {
    return new ShadowIfStatement(condition, thenStatement, elseStatement)
      ..fileOffset = ifKeyword.charOffset;
  }

  @override
  Expression isExpression(
      Expression operand, isOperator, Token notOperator, covariant type) {
    int offset = offsetForToken(isOperator);
    if (notOperator != null) {
      return new ShadowIsNotExpression(operand, type, offset);
    }
    return new ShadowIsExpression(operand, type)..fileOffset = offset;
  }

  @override
  Expression notExpression(Expression operand, Token token) {
    return new ShadowNot(operand)..fileOffset = offsetForToken(token);
  }

  @override
  Expression parenthesizedCondition(
      Token leftParenthesis, Expression expression, Token rightParenthesis) {
    return expression;
  }

  @override
  Statement rethrowStatement(Token rethrowKeyword, Token semicolon) {
    return new ShadowExpressionStatement(
        new ShadowRethrow()..fileOffset = offsetForToken(rethrowKeyword));
  }

  @override
  Statement returnStatement(
      Token returnKeyword, Expression expression, Token semicolon) {
    return new ShadowReturnStatement(expression)
      ..fileOffset = returnKeyword.charOffset;
  }

  @override
  Expression stringConcatenationExpression(
      List<Expression> expressions, Token token) {
    return new ShadowStringConcatenation(expressions)
      ..fileOffset = offsetForToken(token);
  }

  @override
  Statement syntheticLabeledStatement(Statement statement) {
    return new ShadowLabeledStatement(statement);
  }

  @override
  Expression thisExpression(Token token) {
    return new ShadowThisExpression()..fileOffset = offsetForToken(token);
  }

  @override
  Expression throwExpression(Token throwKeyword, Expression expression) {
    return new ShadowThrow(expression)
      ..fileOffset = offsetForToken(throwKeyword);
  }

  @override
  Statement tryStatement(Token tryKeyword, Statement body,
      List<Catch> catchClauses, Token finallyKeyword, Statement finallyBlock) {
    Statement tryStatement = body;
    if (catchClauses != null) {
      tryStatement = new ShadowTryCatch(tryStatement, catchClauses);
    }
    if (finallyBlock != null) {
      tryStatement = new ShadowTryFinally(tryStatement, finallyBlock);
    }
    return tryStatement;
  }

  @override
  _VariablesDeclaration variablesDeclaration(
      List<VariableDeclaration> declarations, Uri uri) {
    return new _VariablesDeclaration(declarations, uri);
  }

  @override
  List<VariableDeclaration> variablesDeclarationExtractDeclarations(
      _VariablesDeclaration variablesDeclaration) {
    return variablesDeclaration.declarations;
  }

  @override
  Statement wrapVariables(Statement statement) {
    if (statement is _VariablesDeclaration) {
      return new ShadowBlock(statement.declarations)
        ..fileOffset = statement.fileOffset;
    } else if (statement is VariableDeclaration) {
      return new ShadowBlock(<Statement>[statement])
        ..fileOffset = statement.fileOffset;
    } else {
      return statement;
    }
  }

  @override
  Statement whileStatement(
      Token whileKeyword, Expression condition, Statement body) {
    return new ShadowWhileStatement(condition, body)
      ..fileOffset = whileKeyword.charOffset;
  }

  @override
  Statement yieldStatement(
      Token yieldKeyword, Token star, Expression expression, Token semicolon) {
    return new ShadowYieldStatement(expression, isYieldStar: star != null)
      ..fileOffset = yieldKeyword.charOffset;
  }

  @override
  bool isBlock(Object node) => node is Block;

  @override
  bool isErroneousNode(Object node) {
    if (node is ExpressionStatement) {
      ExpressionStatement statement = node;
      node = statement.expression;
    }
    if (node is VariableDeclaration) {
      VariableDeclaration variable = node;
      node = variable.initializer;
    }
    if (node is ShadowSyntheticExpression) {
      ShadowSyntheticExpression synth = node;
      node = synth.desugared;
    }
    if (node is Let) {
      Let let = node;
      node = let.variable.initializer;
    }
    return node is InvalidExpression;
  }

  @override
  bool isThisExpression(Object node) => node is ThisExpression;

  @override
  bool isVariablesDeclaration(Object node) => node is _VariablesDeclaration;

  @override
  void resolveBreak(LabeledStatement target, BreakStatement user) {
    user.target = target;
  }

  @override
  void resolveContinue(LabeledStatement target, BreakStatement user) {
    user.target = target;
  }

  @override
  void resolveContinueInSwitch(
      SwitchCase target, ContinueSwitchStatement user) {
    user.target = target;
  }
}

class _VariablesDeclaration extends Statement {
  final List<VariableDeclaration> declarations;
  final Uri uri;

  _VariablesDeclaration(this.declarations, this.uri) {
    setParents(declarations, this);
  }

  @override
  accept(v) {
    unsupported("accept", fileOffset, uri);
  }

  @override
  accept1(v, arg) {
    unsupported("accept1", fileOffset, uri);
  }

  @override
  visitChildren(v) {
    unsupported("visitChildren", fileOffset, uri);
  }

  @override
  transformChildren(v) {
    unsupported("transformChildren", fileOffset, uri);
  }
}
