import Foundation

private struct Constant {
    static let equalityFunction = "checkEquality"
}

private func stringForMethodKind(methodKind: MethodKind) -> String {
    switch methodKind {
    case .Class: return "class func"
    case .Instance: return "func"
    case .Static: return "static func"
    case .InstanceVar: return "var"
    case .Call: return ""
    case .StaticVar: return "static var"
    }
}

class FakeClassGenerator {
    private let tab = "    "
    private let classFunctionsAndArgumentsCalledString: String = "classFunctionsAndArgumentsCalled"
    private let functionsAndArgumentsCalledString: String = "functionsAndArgumentsCalled"
        
    // MARK - Public functions
    
    func makeFakeClass(classStruct: ClassStruct) -> String {
        guard classStruct.methods.count > 0 else {
            return ""
        }
        
        let fakeHelpers = generateFakeHelpers(classStruct: classStruct)
        let fakeClass = generateFakeClass(classStruct: classStruct)
        
        return fakeHelpers + fakeClass
    }
    
    // MARK - Private functions
    
    private func generateFakeHelpers(classStruct: ClassStruct) -> String {
        var code: String = ""
        code += generateEquatableEnumerationForMethods(enumName: classStruct.enumName, methods: classStruct.methods)
        code += "\n"
        code += generateEquatableMethod(enumName: classStruct.enumName, methods: classStruct.methods)
        code += "\n"
        code += generateStub(className: classStruct.className, methods: classStruct.methods)
        code += "\n"
        code += generateReturn(className: classStruct.className)
        code += "\n"

        return code
    }
    
    private func generateFakeClass(classStruct: ClassStruct) -> String {
        var classString = "class Fake\(classStruct.className): \(classStruct.className) {\n"
        
        classString += tab + "var stubs = [(Any,Any)]()\n"
        classString += tab + "static var classStubs = [AnyHashable: Any]()\n"
        classString += tab + "private var methodCalls = [Any]()\n"
        classString += tab + "private static var classMethodCalls = [Any]()\n"
        classString += "\n"
        
        classString += generateStubHelpers(className: classStruct.className)
        
        for method in classStruct.methods {
            if let _ = enumNameForMethod(method: method) {
                let methodKindString = stringForMethodKind(methodKind: method.kind)
                
                var overrideString: String = ""
                
                if classStruct.classKind == .ClassKind {
                    overrideString = "override"
                }
                
                classString += tab + "\(overrideString) \(methodKindString) \(method.nameWithExternalNames)"
                
                var stubGeneric = "Any"
                if let returnType = method.returnType {
                    classString += " -> " + returnType + " "
                    stubGeneric = returnType
                }
                
                classString += "{\n"
                
                var parameters = "nil"
                if method.externalArgumentNames.count > 0 {
                    parameters = "["
                    for argument in method.externalArgumentNames {
                        parameters += "\"\(argument)\": \(argument),"
                    }
                    parameters += "]"
                }
                
                let methodEnum = generateEnumWithPassedInParameters(for: method)
                classString += tab + tab + "let stub = \(classStruct.className)Stub<\(stubGeneric)>(method: \(methodEnum))\n"
                
                switch method.kind {
                case .Class:
                    classString += tab + tab + "classMethodCalls.append(stub)\n"
                case .Instance:
                    classString += tab + tab + "methodCalls.append(stub)\n"
                default:
                    break
                }
                
                if let returnType = method.returnType {
                    switch method.kind {
                    case .Class:
                        classString += tab + tab + "return classStubs[stub] as! \(returnType)\n"
                    case .Instance:
                        classString += tab + tab + "return returnFor(stub: stub) as! \(returnType)\n"
                    default:
                        break
                    }
                    
                }
                classString += tab + "}\n"
                classString += "\n"
            }
        }
        
        classString += tab + "func stub<T>(_ stub: \(classStruct.className)Stub<T>) -> \(classStruct.className)Return<T> {\n"
        classString += tab + tab + "return \(classStruct.className)Return<T>(fake: self, stub: stub)\n"
        classString += tab + "}\n"
        
        classString += "\n"
        classString += tab + "class func stub<T>(_ stub: \(classStruct.className)Stub<T>) -> \(classStruct.className)ClassReturn<T> {\n"
        classString += tab + tab + "return \(classStruct.className)ClassReturn<T>(stub: stub)\n"
        classString += tab + "}\n"
        
        classString += "\n"
        
        classString += generateMatchingMethods(className: classStruct.className)
        
        classString += tab + "func didCall<T>(method: \(classStruct.className)Stub<T>) -> Bool {\n"
        classString += tab + tab + "return matchingMethods(method).count > 0\n"
        classString += tab + "}\n"
        classString += "\n"
        
        classString += tab + "class func didCall<T>(method: \(classStruct.className)Stub<T>) -> Bool {\n"
        classString += tab + tab + "return matchingMethods(method).count > 0\n"
        classString += tab + "}\n"
        classString += "\n"
        
        classString += "}\n"

        return classString
    }
    
    private func enumNameForMethod(method: Method) -> String? {
        let startOfStringToRemove = method.name.range(of: "(")
        
        if let startIndex = startOfStringToRemove {
            var methodSignature: String = method.name.substring(to: startIndex.lowerBound)
            for arg in method.externalArgumentNames {
                methodSignature += "_" + arg
            }
            
            return methodSignature
        }
        
        return nil
    }
    
    private func generateEquatableEnumerationForMethods(enumName: String, methods: [Method]) -> String {
        var code: String = "public enum \(enumName): Equatable, Hashable {\n"
        for method: Method in methods {
            
            if let methodName = enumNameForMethod(method: method) {
                code += "\(tab)case " + methodName
                code += "("
                
                var needsComma: Bool = false
                for type: String in method.argumentTypes {
                    if needsComma {
                        code += ", "
                    }
                    needsComma = true
                    
                    code += "\(type)"
                }
                code += ")\n"
            }
        }
        
        code += "\(tab)public var hashValue: Int {\n"
        code += "\(tab)\(tab)get {\n"
        code += tab + tab + tab + "switch self {\n"
        
        var hashValue: Int = 0
        for method: Method in methods {
            if let methodName = enumNameForMethod(method: method) {
                code += tab + tab + tab + "case .\(methodName):\n"
                code += tab + tab + tab + tab + "return \(hashValue)\n"
                hashValue += 1
            }
        }
        
        code += tab + tab + tab + "}\n"
        code += tab + tab + "}\n"
        code += tab + "}\n"
        code += "}\n"
        
        return code
    }
    
    private func generateEquatableMethod(enumName: String, methods: [Method]) -> String {
        var code: String = ""
        code += "public func == (lhs: \(enumName), rhs: \(enumName)) -> Bool {\n"
        code += "\(tab)switch (lhs, rhs) {\n"
        
        for method: Method in methods {
            if let methodName = enumNameForMethod(method: method) {
                code += "\(tab)"
                code += "case (.\(methodName)("
                let numberOfArguments: Int = method.argumentTypes.count
                if numberOfArguments > 0 {
                    for i in 1...numberOfArguments {
                        if i > 1 {
                            code += ", "
                        }
                        code += "let a\(i)"
                    }
                }
                
                code += "), "
                
                code += ".\(methodName)("
                if numberOfArguments > 0 {
                    for i in 1...numberOfArguments {
                        if i > 1 {
                            code += ", "
                        }
                        code += "let b\(i)"
                    }
                }
                
                code += ")): return "
                
                if numberOfArguments > 0 {
                    var isFirstArgument: Bool = true
                    for i in 1...numberOfArguments {
                        if !isFirstArgument {
                            code += " && "
                        }
                        
                        if method.argumentTypes[i - 1].contains("AnyObject") {
                            code += Constant.equalityFunction + "(a\(i), b: b\(i))"
                        }
                        else {
                            code += "a\(i) == b\(i)"
                        }
                        
                        isFirstArgument = false
                    }
                }
                else {
                    code += "true"
                }
                
                code += "\n"
                
            }
        }
        
        if methods.count > 1 {
            code += "\n"
            for method: Method in methods {
                if let methodName = enumNameForMethod(method: method) {
                    code += "\(tab)case (.\(methodName), _): return false"
                    code += "\n"
                }
            }
        }
        
        code += "\(tab)}\n"
        code += "}"
        
        return code
    }
    
    private func generateMatchingMethods(className: String) -> String {
        var code: String = ""
        code += tab + "func matchingMethods<T>(_ stub: \(className)Stub<T>) -> [Any] {\n"
        code += tab + tab + "let callsToMethod = methodCalls.filter { object in\n"
        code += tab + tab + tab + "if let theMethod = object as? \(className)Stub<T> {\n"
        code += tab + tab + tab + tab + "return theMethod == stub\n"
        code += tab + tab + tab + "}"
        code += "\n"
        code += tab + tab + tab + "return false\n"
        code += tab + tab + "}\n"
        code += tab + tab + "return callsToMethod\n"
        code += tab + "}\n"
        code += tab + "\n"
        
        code += tab + "class func matchingMethods<T>(_ stub: \(className)Stub<T>) -> [Any] {\n"
        code += tab + tab + "let callsToMethod = classMethodCalls.filter { object in\n"
        code += tab + tab + tab + "if let theMethod = object as? \(className)Stub<T> {\n"
        code += tab + tab + tab + tab + "return theMethod == stub\n"
        code += tab + tab + tab + "}"
        code += "\n"
        code += tab + tab + tab + "return false\n"
        code += tab + tab + "}\n"
        code += tab + tab + "return callsToMethod\n"
        code += tab + "}\n"
        code += "\n"
        
        return code
    }
    
    private func generateStub(className: String, methods: [Method]) -> String {
        var code: String = ""
        code = "struct \(className)Stub<T>: Hashable, Equatable {\n"
        code += tab + "var method: \(className)Method\n"
        code += tab + "var hashValue: Int {\n"
        code += tab + tab + "return method.hashValue\n"
        code += tab + "}\n"
        
        code += "\n"
        
        code += tab + "init(method: \(className)Method) {\n"
        code += tab + tab + "self.method = method\n"
        code += tab + "}\n"
        
        code += "\n"
        
        code += tab + "public static func == (lhs: \(className)Stub, rhs: \(className)Stub) -> Bool {\n"
        code += tab + tab + "return lhs.method == rhs.method\n"
        code += tab + "}\n"
        
        for method in methods {
            if let _ = enumNameForMethod(method: method) {
                code += tab + "public static func " + method.nameWithExternalNames
                
                var stubGeneric = "Any"
                if let returnType = method.returnType {
                    stubGeneric = returnType
                }
                code += " -> \(className)Stub<\(stubGeneric)>"
                code += " {\n"
                
                var parameters = "nil"
                if method.externalArgumentNames.count > 0 {
                    parameters = "["
                    for argument in method.externalArgumentNames {
                        parameters += "\"\(argument)\": \(argument),"
                    }
                    parameters += "]"
                }
                
                let methodEnum = generateEnumWithPassedInParameters(for: method)
                code += tab + tab + "return \(className)Stub<\(stubGeneric)>(method: \(methodEnum))\n"
                code += tab + "}\n"
                code += "\n"
            }
        }
        
        code += "}\n"
        
        return code
    }
    
    private func generateEnumWithPassedInParameters(for method: Method) -> String {
        guard let methodName = enumNameForMethod(method: method) else {
            return ""
        }
        
        var text = ""
        text += ".\(methodName)("
        
        var needsComma: Bool = false
        for argumentName: String in method.externalArgumentNames {
            if needsComma {
                text += ", "
            }
            text += "\(argumentName)"
            needsComma = true
        }
        
        text += ")"
        
        return text
    }
    
    private func generateReturn(className: String) -> String {
        var code: String = ""
        code += "struct \(className)Return<T> {\n"
        code += tab + "var fake: Fake" + className + "\n"
        code += tab + "var stub: \(className)Stub<T>\n"
        code += "\n"
        code += tab + "func andReturn(_ value: T) {\n"
        code += tab + tab + "fake.setReturnFor(stub: stub, value: value)\n"
        code += tab + "}\n"
        code += "}\n"
        
        code += "\n"
        
        code += "struct \(className)ClassReturn<T> {\n"
        code += tab + "var stub: \(className)Stub<T>\n"
        code += "\n"
        code += tab + "func andReturn(_ value: T) {\n"
        code += tab + tab + "Fake\(className).classStubs[stub] = value\n"
        code += tab + "}\n"
        code += "}\n"
        
        return code
    }
    
    private func generateStubHelpers(className: String) -> String {
        var code: String = ""
        code += tab + "func returnFor<T>(stub: \(className)Stub<T>) -> Any? {\n"
        code += tab + tab + "for tuple in stubs {\n"
        code += tab + tab + tab + "if let myStub = tuple.0 as? \(className)Stub<T> {\n"
        code += tab + tab + tab + tab + "if myStub == stub {\n"
        code += tab + tab + tab + tab + tab + "return tuple.1\n"
        code += tab + tab + tab + tab + "}\n"
        code += tab + tab + tab + "}\n"
        code += tab + tab + "}\n"
        code += tab + tab + "return nil\n"
        code += tab + "}\n"
        
        code += "\n"
        
        code += tab + "func setReturnFor<T>(stub: \(className)Stub<T>, value: Any) {\n"
        code += tab + tab + "stubs.append((stub, value))\n"
        code += tab + "}\n"
        
        return code
    }
}
