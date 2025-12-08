module Main

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::java::m3::Core;
import lang::java::m3::AST;

data CloneMember = cloneMember(loc location, int startLine, int endLine, str text);

data CloneClass = cloneClass(
    int id,
    list[CloneMember] members,
    int sizeLines,
    int sizeMembers
);

public int main(loc project) {
    list[CloneClass] clones = detectTypeIClone(project);
    printCloneReport(clones);
    return 0;
}

void printCloneReport(list[CloneClass] clones) {
    println("=====================================");
    println("Type I Clone Detection Report");
    println("=====================================");
    println("Total clone classes found: <size(clones)>");
    println();
    
    if (isEmpty(clones)) {
        println("No clones detected.");
        return;
    }
    
    int totalCloneInstances = (0 | it + cc.sizeMembers | cc <- clones);
    int totalClonedLines = (0 | it + (cc.sizeLines * cc.sizeMembers) | cc <- clones);
    
    println("Total clone instances: <totalCloneInstances>");
    println("Total cloned lines: <totalClonedLines>");
    println();
    
    // for (clone <- clones) {
    //     println("-------------------------------------");
    //     println("Clone Class #<clone.id>");
    //     println("  Size: <clone.sizeLines> lines");
    //     println("  Instances: <clone.sizeMembers>");
    //     println("  Locations:");
        
    //     for (member <- clone.members) {
    //         println("    - <member.location.path>");
    //         println("      Lines <member.startLine>-<member.endLine>");
    //         println(member.text);
    //     }
    //     println();
    // }
    
    println("=====================================");
}

list[CloneClass] detectTypeIClone(loc project) {
    return detectTypeIClone(project, 6);
}

list[CloneClass] detectTypeIClone(loc project, int minLines) {
    // Extract all code blocks from the project
    map[str, list[CloneMember]] codeBlocks = extractCodeBlocks(project, minLines);
    
    // Filter blocks that appear more than once (clones)
    list[CloneClass] cloneClasses = [];
    int cloneId = 0;
    
    for (hash <- codeBlocks) {
        list[CloneMember] members = codeBlocks[hash];
        if (size(members) > 1) {
            // Calculate the size in lines (all members have same size for Type I)
            int sizeLines = members[0].endLine - members[0].startLine + 1;
            
            cloneClasses += cloneClass(
                cloneId,
                members,
                sizeLines,
                size(members)
            );
            cloneId += 1;
        }
    }
    
    return cloneClasses;
}

map[str, list[CloneMember]] extractCodeBlocks(loc project, int minLines) {
    map[str, list[CloneMember]] blocks = ();
    
    // Find all Java files in the project
    set[loc] javaFiles = findJavaFiles(project);
    
    for (file <- javaFiles) {
        // Parse the file to get method/constructor bodies
        try {
            Declaration ast = createAstFromFile(file, true);
            
            for (/Declaration d := ast) {
                // Extract method and constructor bodies
                if (d is method || d is constructor) {
                    blocks = extractFromDeclaration(d, file, minLines, blocks);
                }
            }
        } catch: {
            // If AST parsing fails, fall back to line-based approach
            println("Warning: Could not parse <file.path>, skipping...");
        }
    }
    
    return blocks;
}

map[str, list[CloneMember]] extractFromDeclaration(Declaration d, loc file, int minLines, map[str, list[CloneMember]] blocks) {
    // Get the source location of the declaration
    loc declLoc = d.src;
    
    // Read only the lines of this declaration
    list[str] lines = readFileLines(declLoc);
    
    // Skip if declaration is too small
    if (size(lines) < minLines) {
        return blocks;
    }
    
    // Normalize lines
    list[str] normalizedLines = [normalizeLine(line) | line <- lines];
    
    // Remove leading/trailing empty lines
    while (!isEmpty(normalizedLines) && normalizedLines[0] == "") {
        normalizedLines = tail(normalizedLines);
    }
    while (!isEmpty(normalizedLines) && normalizedLines[-1] == "") {
        normalizedLines = prefix(normalizedLines);
    }
    
    // Skip if too small after normalization
    if (size(normalizedLines) < minLines) {
        return blocks;
    }
    
    // Create sliding window of code blocks within this declaration
    for (int i <- [0..size(normalizedLines) - minLines + 1]) {
        list[str] block = slice(normalizedLines, i, minLines);
        
        // Skip if block is all empty
        if (all(line <- block, line == "")) {
            continue;
        }
        
        // Create hash of the block
        str blockHash = createHash(block);
        
        // Calculate actual line numbers in the original file
        int startLine = declLoc.begin.line + i;
        int endLine = startLine + minLines - 1;
        
        // Get the actual text of the clone
        str cloneText = intercalate("\n", block);
        
        CloneMember member = cloneMember(file, startLine, endLine, cloneText);
        
        if (blockHash in blocks) {
            blocks[blockHash] += member;
        } else {
            blocks[blockHash] = [member];
        }
    }
    
    return blocks;
}

set[loc] findJavaFiles(loc project) {
    set[loc] files = {};
    
    if (isDirectory(project)) {
        for (entry <- project.ls) {
            files += findJavaFiles(entry);
        }
    } else if (project.extension == "java") {
        files += {project};
    }
    
    return files;
}

str normalizeLine(str line) {
    // Remove leading/trailing whitespace
    str trimmed = trim(line);
    
    // Remove single-line comments
    if (startsWith(trimmed, "//")) {
        return "";
    }
    
    // Remove multi-line comment markers (basic approach)
    trimmed = replaceAll(trimmed, "/*", "");
    trimmed = replaceAll(trimmed, "*/", "");
    
    // Normalize whitespace (replace multiple spaces with single space)
    trimmed = visit(trimmed) {
        case /\s+/ => " "
    };
    
    return trim(trimmed);
}

str createHash(list[str] lines) {
    // Simple hash: concatenate all lines
    return intercalate("\n", lines);
}

// Helper function for Rascal 2.x compatibility
public list[&T] slice(list[&T] lst, int begin, int len) {
    return lst[begin..begin+len];
}