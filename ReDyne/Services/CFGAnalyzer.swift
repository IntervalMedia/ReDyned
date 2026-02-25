import Foundation

/// Analyzer for Control Flow Graphs (CFG) of functions
/// Performs static analysis to construct control flow graphs from disassembled code
@objc class CFGAnalyzer: NSObject {
    
    /// Analyzes functions to generate control flow graphs
    /// - Parameter functions: Array of functions to analyze
    /// - Returns: Analysis result containing CFGs for all analyzed functions
    @objc static func analyze(functions: [FunctionModel]) -> CFGAnalysisResult {
        print("   Analyzing control flow graphs...")
        print("   Total functions to analyze: \(functions.count)")
        
        var functionCFGs: [FunctionCFG] = []
        
        for (index, function) in functions.prefix(50).enumerated() {
            if let instructions = function.instructions as? [InstructionModel] {
                print("   Function #\(index): \(function.name) has \(instructions.count) instructions")
            } else {
                print("   Function #\(index): \(function.name) has NO instructions!")
            }
            
            if let cfg = analyzeFunctionCFG(function) {
                functionCFGs.append(cfg)
                print("   Created CFG for \(function.name): \(cfg.nodes.count) nodes, \(cfg.edges.count) edges")
            } else {
                print("   Failed to create CFG for \(function.name)")
            }
        }
        
        let result = CFGAnalysisResult(functionCFGs: functionCFGs)
        
        print("CFG analysis complete")
        print("   • \(result.totalFunctions) functions")
        print("   • \(result.totalNodes) nodes")
        print("   • \(result.totalEdges) edges")
        
        return result
    }
    
    /// Analyzes a single function to construct its control flow graph
    /// - Parameter function: The function to analyze
    /// - Returns: Control flow graph for the function, or nil if analysis fails
    private static func analyzeFunctionCFG(_ function: FunctionModel) -> FunctionCFG? {
        guard let instructions = function.instructions as? [InstructionModel], !instructions.isEmpty else { return nil }
        
        var nodes: [CFGNode] = []
        var edges: [CFGEdge] = []
        var nodeID = 0
        var currentBlock: [InstructionModel] = []
        var blockStarts: Set<UInt64> = [function.startAddress]
        var branchCount = 0
        for inst in instructions {
            if inst.hasBranch {
                branchCount += 1
                if inst.hasBranchTarget {
                    blockStarts.insert(inst.branchTarget)
                }
            }
        }
        
        if instructions.count > 0 {
            print("      Block analysis: \(branchCount) branches, \(blockStarts.count) block starts")
            if let first = instructions.first {
                print("      First instruction: mnemonic='\(first.mnemonic)', category='\(first.category)', hasBranch=\(first.hasBranch)")
            }
            if let last = instructions.last {
                print("      Last instruction: mnemonic='\(last.mnemonic)', category='\(last.category)', hasBranch=\(last.hasBranch), hexBytes=\(last.hexBytes)")
            }
        }
        
        for inst in instructions {
            currentBlock.append(inst)
            
            let isBlockEnd = inst.category.contains("Branch") ||
                           inst.mnemonic.uppercased().contains("RET") ||
                           blockStarts.contains(inst.address + 4)
            
            if isBlockEnd && !currentBlock.isEmpty {
                let startAddr = currentBlock.first!.address
                let endAddr = currentBlock.last!.address
                let instStrings = currentBlock.map { $0.mnemonic }
                
                let node = CFGNode(
                    id: nodeID,
                    startAddress: startAddr,
                    endAddress: endAddr,
                    instructions: instStrings
                )
                
                if nodeID == 0 {
                    node.nodeType = .entry
                }
                if currentBlock.last?.mnemonic.uppercased().contains("RET") == true {
                    node.nodeType = .exit
                }
                if currentBlock.last?.mnemonic.uppercased().hasPrefix("B.") == true {
                    node.nodeType = .conditional
                }
                
                nodes.append(node)
                nodeID += 1
                currentBlock = []
            }
        }
        
        if nodes.count > 1 {
            var addressToNodeID: [UInt64: Int] = [:]
            for (idx, node) in nodes.enumerated() {
                addressToNodeID[node.startAddress] = idx
            }
            
            for i in 0..<nodes.count {
                let node = nodes[i]
                let lastInst = instructions.first(where: { $0.address == node.endAddress })
                
                guard let lastInst = lastInst else { continue }
                
                let mnemonic = lastInst.mnemonic.uppercased()
                
                if mnemonic == "RET" {
                    continue
                }
                else if mnemonic == "B" {
                    if lastInst.hasBranchTarget, let targetID = addressToNodeID[lastInst.branchTarget] {
                        let edge = CFGEdge(from: i, to: targetID, edgeType: .normal)
                        edges.append(edge)
                    }
                }
                else if mnemonic.hasPrefix("B.") {
                    if lastInst.hasBranchTarget, let targetID = addressToNodeID[lastInst.branchTarget] {
                        let branchEdge = CFGEdge(from: i, to: targetID, edgeType: .trueBranch)
                        edges.append(branchEdge)
                    }
                    if i + 1 < nodes.count {
                        let fallThroughEdge = CFGEdge(from: i, to: i + 1, edgeType: .falseBranch)
                        edges.append(fallThroughEdge)
                    }
                }
                else if mnemonic == "BL" || mnemonic == "BLR" {
                    if i + 1 < nodes.count {
                        let callEdge = CFGEdge(from: i, to: i + 1, edgeType: .normal)
                        edges.append(callEdge)
                    }
                }
                else if mnemonic.contains("BR") && !mnemonic.contains("BRK") {
                    continue
                }
                else {
                    if i + 1 < nodes.count {
                        let edge = CFGEdge(from: i, to: i + 1, edgeType: .normal)
                        edges.append(edge)
                    }
                }
            }
        }
        
        return FunctionCFG(
            functionName: function.name,
            functionAddress: function.startAddress,
            nodes: nodes,
            edges: edges
        )
    }
    
    /// Validates a CFG for correctness
    /// - Parameter cfg: The CFG to validate
    /// - Returns: Array of validation issues found (empty if valid)
    static func validateCFG(_ cfg: FunctionCFG) -> [String] {
        var issues: [String] = []
        
        // Check for nodes without edges
        let nodesWithEdges = Set(cfg.edges.flatMap { [$0.from, $0.to] })
        for (index, node) in cfg.nodes.enumerated() {
            if !nodesWithEdges.contains(index) && index != 0 && cfg.nodes.count > 1 {
                issues.append("Node \(index) at address 0x\(String(format: "%llx", node.startAddress)) is isolated")
            }
        }
        
        // Check for edges pointing to non-existent nodes
        for edge in cfg.edges {
            if edge.from >= cfg.nodes.count {
                issues.append("Edge has invalid source node: \(edge.from)")
            }
            if edge.to >= cfg.nodes.count {
                issues.append("Edge has invalid target node: \(edge.to)")
            }
        }
        
        // Check for empty nodes
        for (index, node) in cfg.nodes.enumerated() {
            if node.instructions.isEmpty {
                issues.append("Node \(index) has no instructions")
            }
        }
        
        return issues
    }
    
    /// Calculates complexity metrics for a CFG
    /// - Parameter cfg: The CFG to analyze
    /// - Returns: Dictionary of complexity metrics
    static func calculateComplexity(_ cfg: FunctionCFG) -> [String: Int] {
        let cyclomaticComplexity = cfg.edges.count - cfg.nodes.count + 2
        let conditionalBranches = cfg.edges.filter { 
            $0.edgeType == .trueBranch || $0.edgeType == .falseBranch 
        }.count
        
        return [
            "nodes": cfg.nodes.count,
            "edges": cfg.edges.count,
            "cyclomaticComplexity": cyclomaticComplexity,
            "conditionalBranches": conditionalBranches,
            "entryNodes": cfg.nodes.filter { $0.nodeType == .entry }.count,
            "exitNodes": cfg.nodes.filter { $0.nodeType == .exit }.count
        ]
    }
}

