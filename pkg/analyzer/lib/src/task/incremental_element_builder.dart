// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analyzer.src.task.incremental_element_builder;

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/utilities.dart';
import 'package:analyzer/src/dart/element/builder.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * The change of a single [ClassElement].
 */
class ClassElementDelta {
  final ClassElement element;

  final List<PropertyAccessorElement> addedAccessors =
      <PropertyAccessorElement>[];
  final List<PropertyAccessorElement> removedAccessors =
      <PropertyAccessorElement>[];

  final List<ConstructorElement> addedConstructors = <ConstructorElement>[];
  final List<ConstructorElement> removedConstructors = <ConstructorElement>[];

  final List<MethodElement> addedMethods = <MethodElement>[];
  final List<MethodElement> removedMethods = <MethodElement>[];

  ClassElementDelta(this.element);
}

/**
 * The change of a single [CompilationUnitElement].
 */
class CompilationUnitElementDelta {
  /**
   * One or more directives were added/removed.
   */
  bool hasDirectiveChange = false;

  /**
   * The list of added top-level element.
   */
  final List<Element> addedDeclarations = <Element>[];

  /**
   * The list of removed top-level elements.
   */
  final List<Element> removedDeclarations = <Element>[];

  /**
   * The list of changed class elements.
   */
  final List<ClassElementDelta> classDeltas = <ClassElementDelta>[];
}

/**
 * Incrementally updates the existing [unitElement] and builds elements for
 * the [newUnit].
 */
class IncrementalCompilationUnitElementBuilder {
  final Source unitSource;
  final Source librarySource;
  final CompilationUnit oldUnit;
  final CompilationUnitElementImpl unitElement;
  final CompilationUnit newUnit;
  final ElementHolder unitElementHolder = new ElementHolder();

  /**
   * The change between element models of [oldUnit] and [newUnit].
   */
  final CompilationUnitElementDelta unitDelta =
      new CompilationUnitElementDelta();

  factory IncrementalCompilationUnitElementBuilder(
      CompilationUnit oldUnit, CompilationUnit newUnit) {
    CompilationUnitElementImpl unitElement = oldUnit.element;
    return new IncrementalCompilationUnitElementBuilder._(unitElement.source,
        unitElement.librarySource, oldUnit, newUnit, unitElement);
  }

  IncrementalCompilationUnitElementBuilder._(this.unitSource,
      this.librarySource, this.oldUnit, this.newUnit, this.unitElement);

  /**
   * Updates [oldUnit] to have the same directives and declarations, in the
   * same order as in [newUnit]. Existing resolution is kept where possible.
   *
   * Updates [unitElement] by adding/removing elements as needed.
   *
   * Fills [unitDelta] with added/remove elements.
   */
  void build() {
    new CompilationUnitBuilder()
        .buildCompilationUnit(unitSource, newUnit, librarySource);
    _processDirectives();
    _processUnitMembers();
    _replaceUnitContents(oldUnit, newUnit);
    newUnit.element = unitElement;
    unitElement.setCodeRange(0, newUnit.endToken.end);
  }

  void _addElementToUnitHolder(Element element) {
    if (element is ClassElement) {
      if (element.isEnum) {
        unitElementHolder.addEnum(element);
      } else {
        unitElementHolder.addType(element);
      }
    } else if (element is FunctionElement) {
      unitElementHolder.addFunction(element);
    } else if (element is FunctionTypeAliasElement) {
      unitElementHolder.addTypeAlias(element);
    } else if (element is PropertyAccessorElement) {
      unitElementHolder.addAccessor(element);
    } else if (element is TopLevelVariableElement) {
      unitElementHolder.addTopLevelVariable(element);
    }
  }

  ClassElementDelta _processClassMembers(
      ClassDeclaration oldClass, ClassDeclaration newClass) {
    // If the class hierarchy or type parameters are changed,
    // then the class changed too much - don't compute the delta.
    if (TokenUtils.getFullCode(newClass.typeParameters) !=
            TokenUtils.getFullCode(oldClass.typeParameters) ||
        TokenUtils.getFullCode(newClass.extendsClause) !=
            TokenUtils.getFullCode(oldClass.extendsClause) ||
        TokenUtils.getFullCode(newClass.withClause) !=
            TokenUtils.getFullCode(oldClass.withClause) ||
        TokenUtils.getFullCode(newClass.implementsClause) !=
            TokenUtils.getFullCode(oldClass.implementsClause)) {
      return null;
    }
    // Build the old class members map.
    Map<String, ClassMember> oldNodeMap = new HashMap<String, ClassMember>();
    for (ClassMember oldNode in oldClass.members) {
      String code = TokenUtils.getFullCode(oldNode);
      oldNodeMap[code] = oldNode;
    }
    // Prepare elements.
    ClassElement newElement = newClass.element;
    ClassElement oldElement = oldClass.element;
    // Use the old element for the new node.
    newClass.name.staticElement = oldElement;
    if (newElement is ClassElementImpl && oldElement is ClassElementImpl) {
      oldElement.nameOffset = newElement.nameOffset;
      oldElement.setCodeRange(newElement.codeOffset, newElement.codeLength);
      oldElement.typeParameters = newElement.typeParameters;
    }
    // Prepare delta.
    ClassElementImpl classElement = oldClass.element;
    ElementHolder classElementHolder = new ElementHolder();
    ClassElementDelta classDelta = new ClassElementDelta(classElement);
    // Prepare all old member elements.
    var removedAccessors = new Set<PropertyAccessorElement>();
    var removedConstructors = new Set<ConstructorElement>();
    var removedMethods = new Set<MethodElement>();
    removedAccessors.addAll(classElement.accessors);
    removedConstructors.addAll(classElement.constructors);
    removedMethods.addAll(classElement.methods);
    // Utilities.
    void processConstructorDeclaration(
        ConstructorDeclaration node, bool isNew) {
      ConstructorElement element = node.element;
      if (element != null) {
        classElementHolder.addConstructor(element);
        if (isNew) {
          classDelta.addedConstructors.add(element);
        } else {
          removedConstructors.remove(element);
        }
      }
    }
    void processFieldDeclaration(FieldDeclaration node, bool isNew) {
      for (VariableDeclaration field in node.fields.variables) {
        PropertyInducingElement element = field.element;
        if (element != null) {
          PropertyAccessorElement getter = element.getter;
          PropertyAccessorElement setter = element.setter;
          if (getter != null) {
            classElementHolder.addAccessor(getter);
            if (isNew) {
              classDelta.addedAccessors.add(getter);
            } else {
              removedAccessors.remove(getter);
            }
          }
          if (setter != null) {
            classElementHolder.addAccessor(setter);
            if (isNew) {
              classDelta.addedAccessors.add(setter);
            } else {
              removedAccessors.remove(setter);
            }
          }
        }
      }
    }
    void processMethodDeclaration(MethodDeclaration node, bool isNew) {
      Element element = node.element;
      if (element is MethodElement) {
        classElementHolder.addMethod(element);
        if (isNew) {
          classDelta.addedMethods.add(element);
        } else {
          removedMethods.remove(element);
        }
      } else if (element is PropertyAccessorElement) {
        classElementHolder.addAccessor(element);
        if (isNew) {
          classDelta.addedAccessors.add(element);
        } else {
          removedAccessors.remove(element);
        }
      }
    }
    // Replace new nodes with the identical old nodes.
    bool newHasConstructor = false;
    for (ClassMember newNode in newClass.members) {
      String code = TokenUtils.getFullCode(newNode);
      ClassMember oldNode = oldNodeMap[code];
      // When we type a name before a constructor with a documentation
      // comment, this makes the comment disappear from AST. So, even though
      // tokens are the same, the nodes are not the same.
      if (oldNode != null) {
        if (oldNode.documentationComment == null &&
                newNode.documentationComment != null ||
            oldNode.documentationComment != null &&
                newNode.documentationComment == null) {
          oldNode = null;
        }
      }
      // Add the new element.
      if (oldNode == null) {
        if (newNode is ConstructorDeclaration) {
          newHasConstructor = true;
          processConstructorDeclaration(newNode, true);
        }
        if (newNode is FieldDeclaration) {
          processFieldDeclaration(newNode, true);
        }
        if (newNode is MethodDeclaration) {
          processMethodDeclaration(newNode, true);
        }
        continue;
      }
      // Do replacement.
      _replaceNode(newNode, oldNode);
      if (oldNode is ConstructorDeclaration) {
        processConstructorDeclaration(oldNode, false);
      }
      if (oldNode is FieldDeclaration) {
        processFieldDeclaration(oldNode, false);
      }
      if (oldNode is MethodDeclaration) {
        processMethodDeclaration(oldNode, false);
      }
    }
    // If the class had only a default synthetic constructor, and there are
    // no explicit constructors in the new AST, keep the constructor.
    if (!newHasConstructor) {
      List<ConstructorElement> constructors = classElement.constructors;
      if (constructors.length == 1) {
        ConstructorElement constructor = constructors[0];
        if (constructor.isSynthetic && constructor.isDefaultConstructor) {
          classElementHolder.addConstructor(constructor);
          removedConstructors.remove(constructor);
        }
      }
    }
    // Update the delta.
    classDelta.removedAccessors.addAll(removedAccessors);
    classDelta.removedConstructors.addAll(removedConstructors);
    classDelta.removedMethods.addAll(removedMethods);
    // Update ClassElement.
    classElement.accessors = classElementHolder.accessors;
    classElement.constructors = classElementHolder.constructors;
    classElement.fields =
        classElement.accessors.map((a) => a.variable).toSet().toList();
    classElement.methods = classElementHolder.methods;
    classElementHolder.validate();
    // Ensure at least a default synthetic constructor.
    if (classElement.constructors.isEmpty) {
      ConstructorElementImpl constructor =
          new ConstructorElementImpl.forNode(null);
      constructor.synthetic = true;
      classElement.constructors = <ConstructorElement>[constructor];
    }
    // OK
    return classDelta;
  }

  void _processDirectives() {
    Map<String, Directive> oldDirectiveMap = new HashMap<String, Directive>();
    for (Directive oldDirective in oldUnit.directives) {
      String code = TokenUtils.getFullCode(oldDirective);
      oldDirectiveMap[code] = oldDirective;
    }
    // Replace new nodes with the identical old nodes.
    Set<Directive> removedDirectives = oldUnit.directives.toSet();
    for (Directive newDirective in newUnit.directives) {
      String code = TokenUtils.getFullCode(newDirective);
      // Prepare an old directive.
      Directive oldDirective = oldDirectiveMap[code];
      if (oldDirective == null) {
        unitDelta.hasDirectiveChange = true;
        continue;
      }
      // URI's must be resolved to the same sources.
      if (newDirective is UriBasedDirective &&
          oldDirective is UriBasedDirective) {
        if (oldDirective.source != newDirective.source) {
          continue;
        }
      }
      // Do replacement.
      _replaceNode(newDirective, oldDirective);
      removedDirectives.remove(oldDirective);
    }
    // If there are any directives left, then these directives were removed.
    if (removedDirectives.isNotEmpty) {
      unitDelta.hasDirectiveChange = true;
    }
  }

  void _processUnitMembers() {
    Map<String, CompilationUnitMember> oldNodeMap =
        new HashMap<String, CompilationUnitMember>();
    Map<String, ClassDeclaration> nameToOldClassMap =
        new HashMap<String, ClassDeclaration>();
    for (CompilationUnitMember oldNode in oldUnit.declarations) {
      String code = TokenUtils.getFullCode(oldNode);
      oldNodeMap[code] = oldNode;
      if (oldNode is ClassDeclaration) {
        nameToOldClassMap[oldNode.name.name] = oldNode;
      }
    }
    // Prepare all old top-level elements.
    Set<Element> removedElements = new Set<Element>();
    removedElements.addAll(unitElement.accessors);
    removedElements.addAll(unitElement.enums);
    removedElements.addAll(unitElement.functions);
    removedElements.addAll(unitElement.functionTypeAliases);
    removedElements.addAll(unitElement.types);
    removedElements.addAll(unitElement.topLevelVariables);
    // Replace new nodes with the identical old nodes.
    for (CompilationUnitMember newNode in newUnit.declarations) {
      String code = TokenUtils.getFullCode(newNode);
      CompilationUnitMember oldNode = oldNodeMap[code];
      // Add the new element.
      if (oldNode == null) {
        // Compute a delta for the class.
        if (newNode is ClassDeclaration) {
          ClassDeclaration oldClass = nameToOldClassMap[newNode.name.name];
          if (oldClass != null) {
            ClassElementDelta delta = _processClassMembers(oldClass, newNode);
            if (delta != null) {
              unitDelta.classDeltas.add(delta);
              _addElementToUnitHolder(delta.element);
              removedElements.remove(delta.element);
              continue;
            }
          }
        }
        // Add the new node elements.
        List<Element> elements = _getElements(newNode);
        elements.forEach(_addElementToUnitHolder);
        elements.forEach(unitDelta.addedDeclarations.add);
        continue;
      }
      // Do replacement.
      _replaceNode(newNode, oldNode);
      List<Element> elements = _getElements(oldNode);
      elements.forEach(_addElementToUnitHolder);
      elements.forEach(removedElements.remove);
    }
    unitDelta.removedDeclarations.addAll(removedElements);
    // Update CompilationUnitElement.
    unitElement.accessors = unitElementHolder.accessors;
    unitElement.enums = unitElementHolder.enums;
    unitElement.functions = unitElementHolder.functions;
    unitElement.typeAliases = unitElementHolder.typeAliases;
    unitElement.types = unitElementHolder.types;
    unitElement.topLevelVariables = unitElementHolder.topLevelVariables;
    unitElementHolder.validate();
  }

  /**
   * Replaces [newNode] with [oldNode], updates tokens and elements.
   * The nodes must have the same tokens, but offsets may be different.
   */
  void _replaceNode(AstNode newNode, AstNode oldNode) {
    // Replace node.
    NodeReplacer.replace(newNode, oldNode);
    // Replace tokens.
    Token oldBeginToken = TokenUtils.getBeginTokenNotComment(oldNode);
    Token newBeginToken = TokenUtils.getBeginTokenNotComment(newNode);
    newBeginToken.previous.setNext(oldBeginToken);
    oldNode.endToken.setNext(newNode.endToken.next);
    // Change tokens offsets.
    Map<int, int> offsetMap = new HashMap<int, int>();
    TokenUtils.copyTokenOffsets(offsetMap, oldBeginToken, newBeginToken,
        oldNode.endToken, newNode.endToken);
    // Change elements offsets.
    {
      var visitor = new _UpdateElementOffsetsVisitor(offsetMap);
      List<Element> elements = _getElements(oldNode);
      for (Element element in elements) {
        element.accept(visitor);
      }
    }
  }

  /**
   * Returns [Element]s that are declared directly by the given [node].
   * This does not include any child elements - parameters, local variables.
   *
   * Usually just one [Element] is returned, but [VariableDeclarationList]
   * nodes may declare more than one.
   */
  static List<Element> _getElements(AstNode node) {
    List<Element> elements = <Element>[];
    void addPropertyAccessors(VariableDeclarationList variableList) {
      if (variableList != null) {
        for (VariableDeclaration variable in variableList.variables) {
          PropertyInducingElement element = variable.element;
          if (element != null) {
            elements.add(element);
            if (element.getter != null) {
              elements.add(element.getter);
            }
            if (element.setter != null) {
              elements.add(element.setter);
            }
          }
        }
      }
    }
    if (node is FieldDeclaration) {
      addPropertyAccessors(node.fields);
    } else if (node is TopLevelVariableDeclaration) {
      addPropertyAccessors(node.variables);
    } else if (node is PartDirective || node is PartOfDirective) {
      // Ignore.
    } else if (node is Directive && node.element != null) {
      elements.add(node.element);
    } else if (node is Declaration && node.element != null) {
      Element element = node.element;
      elements.add(element);
      if (element is PropertyAccessorElement) {
        elements.add(element.variable);
      }
    }
    return elements;
  }

  /**
   * Replaces contents of the [to] unit with the contexts of the [from] unit.
   */
  static void _replaceUnitContents(CompilationUnit to, CompilationUnit from) {
    to.directives.clear();
    to.declarations.clear();
    to.beginToken = from.beginToken;
    to.scriptTag = from.scriptTag;
    to.directives.addAll(from.directives);
    to.declarations.addAll(from.declarations);
    to.element = to.element;
    to.lineInfo = from.lineInfo;
    to.endToken = from.endToken;
  }
}

/**
 * Utilities for [Token] manipulations.
 */
class TokenUtils {
  static const String _SEPARATOR = "\uFFFF";

  /**
   * Copy offsets from [newToken]s to [oldToken]s.
   */
  static void copyTokenOffsets(Map<int, int> offsetMap, Token oldToken,
      Token newToken, Token oldEndToken, Token newEndToken) {
    if (oldToken is CommentToken && newToken is CommentToken) {
      // Update (otherwise unlinked) reference tokens in documentation.
      if (oldToken is DocumentationCommentToken &&
          newToken is DocumentationCommentToken) {
        List<Token> oldReferences = oldToken.references;
        List<Token> newReferences = newToken.references;
        assert(oldReferences.length == newReferences.length);
        for (int i = 0; i < oldReferences.length; i++) {
          copyTokenOffsets(offsetMap, oldReferences[i], newReferences[i],
              oldEndToken, newEndToken);
        }
      }
      // Update documentation tokens.
      while (oldToken != null) {
        offsetMap[oldToken.offset] = newToken.offset;
        offsetMap[oldToken.end] = newToken.end;
        oldToken.offset = newToken.offset;
        oldToken = oldToken.next;
        newToken = newToken.next;
      }
      assert(oldToken == null);
      assert(newToken == null);
      return;
    }
    while (true) {
      if (oldToken.precedingComments != null) {
        assert(newToken.precedingComments != null);
        copyTokenOffsets(offsetMap, oldToken.precedingComments,
            newToken.precedingComments, oldEndToken, newEndToken);
      }
      offsetMap[oldToken.offset] = newToken.offset;
      offsetMap[oldToken.end] = newToken.end;
      oldToken.offset = newToken.offset;
      if (oldToken.type == TokenType.EOF) {
        assert(newToken.type == TokenType.EOF);
        break;
      }
      if (oldToken == oldEndToken) {
        assert(newToken == newEndToken);
        break;
      }
      oldToken = oldToken.next;
      newToken = newToken.next;
    }
  }

  static Token getBeginTokenNotComment(AstNode node) {
    Token oldBeginToken = node.beginToken;
    if (oldBeginToken is CommentToken) {
      return oldBeginToken.parent;
    }
    return oldBeginToken;
  }

  /**
   * Return the token string of all the [node] tokens.
   */
  static String getFullCode(AstNode node) {
    if (node == null) {
      return '';
    }
    List<Token> tokens = getTokens(node);
    return joinTokens(tokens);
  }

  /**
   * Returns all tokens (including comments) of the given [node].
   */
  static List<Token> getTokens(AstNode node) {
    List<Token> tokens = <Token>[];
    Token token = getBeginTokenNotComment(node);
    Token endToken = node.endToken;
    while (true) {
      // append comment tokens
      for (Token commentToken = token.precedingComments;
          commentToken != null;
          commentToken = commentToken.next) {
        tokens.add(commentToken);
      }
      // append token
      tokens.add(token);
      // next token
      if (token == endToken) {
        break;
      }
      token = token.next;
    }
    return tokens;
  }

  static String joinTokens(List<Token> tokens) {
    return tokens.map((token) => token.lexeme).join(_SEPARATOR);
  }
}

/**
 * Updates name offsets of [Element]s according to the [map].
 */
class _UpdateElementOffsetsVisitor extends GeneralizingElementVisitor {
  final Map<int, int> map;

  _UpdateElementOffsetsVisitor(this.map);

  void visitElement(Element element) {
    if (element is LibraryElement) {
      return;
    }
    if (element.isSynthetic && !_isVariableInitializer(element)) {
      return;
    }
    if (element is ElementImpl) {
      // name offset
      {
        int oldOffset = element.nameOffset;
        int newOffset = map[oldOffset];
        assert(newOffset != null);
        element.nameOffset = newOffset;
      }
      // code range
      {
        int oldOffset = element.codeOffset;
        if (oldOffset != null) {
          int oldEnd = oldOffset + element.codeLength;
          int newOffset = map[oldOffset];
          int newEnd = map[oldEnd];
          assert(newOffset != null);
          assert(newEnd != null);
          int newLength = newEnd - newOffset;
          element.setCodeRange(newOffset, newLength);
        }
      }
      // visible range
      if (element is LocalElement) {
        SourceRange oldVisibleRange = (element as LocalElement).visibleRange;
        if (oldVisibleRange != null) {
          int oldOffset = oldVisibleRange.offset;
          int oldLength = oldVisibleRange.length;
          int oldEnd = oldOffset + oldLength;
          int newOffset = map[oldOffset];
          int newEnd = map[oldEnd];
          assert(newOffset != null);
          assert(newEnd != null);
          int newLength = newEnd - newOffset;
          if (newOffset != oldOffset || newLength != oldLength) {
            if (element is FunctionElementImpl) {
              element.setVisibleRange(newOffset, newLength);
            } else if (element is LocalVariableElementImpl) {
              element.setVisibleRange(newOffset, newLength);
            } else if (element is ParameterElementImpl) {
              element.setVisibleRange(newOffset, newLength);
            }
          }
        }
      }
    }
    super.visitElement(element);
  }

  static bool _isVariableInitializer(Element element) {
    return element is FunctionElement &&
        element.enclosingElement is VariableElement;
  }
}
