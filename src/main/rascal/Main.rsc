module Main

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::java::m3::Core;
import lang::java::m3::AST;

data CloneMember = cloneMember(loc location, int startLine, int endLine, str text, list[str] literals);

data CloneClass = cloneClass(
    int id,
    list[CloneMember] members,
    int sizeLines,
    int sizeMembers
);

public int main(loc project) {
    printCloneReport("Type I", detectTypeIClone(project));
    printCloneReport("Type II", detectTypeIIClone(project));
    return 0;
}

void printCloneReport(str name, list[CloneClass] clones) {
    println("=====================================");
    println("<name> Clone Detection Report");
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
    
    for (clone <- clones) {
        println("-------------------------------------");
        println("Clone Class #<clone.id>");
        println("  Size: <clone.sizeLines> lines");
        println("  Instances: <clone.sizeMembers>");
        println("  Locations:");
        
        for (member <- clone.members) {
            println("    - <member.location.path>");
            println("      Lines <member.startLine>-<member.endLine>");
            println("      Text  <member.text>");
        }
        println();
    }
    
    println("=====================================");
}

list[CloneClass] detectTypeIClone(loc project) {
    return detectTypeClone(project, 6, true);
}

list[CloneClass] detectTypeIIClone(loc project) {
    return detectTypeClone(project, 6, false);
}

list[CloneClass] detectTypeClone(loc project, int minLines, bool type1) {
    // Extract all code blocks from the project
    map[str, list[CloneMember]] codeBlocks = extractCodeBlocks(project, minLines, type1);
    
    // Filter blocks that appear more than once (clones)
    list[CloneClass] cloneClasses = [];
    int cloneId = 0;
    
    for (hash <- codeBlocks) {
        list[CloneMember] members = codeBlocks[hash];
        if (size(members) > 1) {
            // Only keep if still has multiple members after filtering
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
    }
    
    return cloneClasses;
}

map[str, list[CloneMember]] extractCodeBlocks(loc project, int minLines, bool type1) {
    map[str, list[CloneMember]] blocks = ();
    M3 model = createM3FromMavenProject(project);

    for (file <- files(model)) {
        // Parse the file to get method/constructor bodies
        try {
            Declaration ast = createAstFromFile(file, true);
            
            for (/Declaration d := ast) {
                // Extract method and constructor bodies
                if (d is method || d is constructor) {
                    blocks = extractFromDeclaration(d, file, minLines, blocks, type1);
                }
            }
        } catch: {
            // If AST parsing fails, skip
            println("Warning: Could not parse <file.path>, skipping...");
        }
    }
    
    return blocks;
}

map[str, list[CloneMember]] extractFromDeclaration(Declaration d, loc file, int minLines, map[str, list[CloneMember]] blocks, bool type1) {
    // Get the source location of the declaration
    loc declLoc = d.src;
    
    // Read only the lines of this declaration
    list[str] lines = normalizeLines(declLoc);
    
    // Skip if declaration is too small
    if (size(lines) < minLines) {
        return blocks;
    }
    
    // Tokenize each line
    list[list[str]] tokenizedLines = [tokenizeLine(line, type1) | line <- lines];

    // Remove leading/trailing empty token lines
    while (!isEmpty(tokenizedLines) && isEmpty(tokenizedLines[0])) {
        tokenizedLines = tail(tokenizedLines);
    }
    while (!isEmpty(tokenizedLines) && isEmpty(tokenizedLines[-1])) {
        tokenizedLines = prefix(tokenizedLines);
    }
    
    // Skip if too small after normalization
    if (size(tokenizedLines) < minLines) {
        return blocks;
    }
    
    // Create sliding window of code blocks within this declaration
    for (int i <- [0..size(tokenizedLines) - minLines + 1]) {
        list[list[str]] block = slice(tokenizedLines, i, minLines);
        
        // Skip if block is all empty
        if (all(tokenLine <- block, isEmpty(tokenLine))) {
            continue;
        }
        
        // Create hash of the token block
        str blockHash = intercalate(" ", [token | tokenLine <- block, token <- tokenLine]);
        
        // Calculate actual line numbers in the original file
        int startLine = declLoc.begin.line + i;
        int endLine = startLine + minLines - 1;
        
        // Get the actual text of the clone (original lines, not tokens)
        list[str] originalLines = slice(lines, i, minLines);
        str cloneText = intercalate("\n", originalLines);
        list[str] literals = [ v | b <- block, v <- extractLiteralValues(b) ];

        CloneMember member = cloneMember(file, startLine, endLine, cloneText, literals);
        
        if (blockHash in blocks) {
            blocks[blockHash] += member;
        } else {
            blocks[blockHash] = [member];
        }
    }
    
    return blocks;
}

public list[str] extractLiteralValues(list[str] tokens) {
    list[str] out = [];

    for (t <- tokens) {
        // Match NAME(value)
        if (/^([A-Z_]+)\((.*)\)$/ := t) {
            // extract the part inside parentheses
            int open = findFirst(t, "(");
            int close = findLast(t, ")");
            if (open >= 0 && close > open) {
                out += substring(t, open + 1, close);
            }
        }
    }

    return out;
}

public list[str] normalizeLines(loc file) {
    list[str] result = [];
    bool inBlock = false;

    for (str raw <- readFileLines(file)) {
        str line = trim(raw);

        if (inBlock) {
            if (contains(line, "*/")) {
                inBlock = false;
            }
            continue;
        }
        if (startsWith(line, "/*")) {
            line = replaceAll(line, "/\\*|\\*/", ""); 
            if (line == "") continue;

            if (!contains(raw, "*/")) { 
                inBlock = true;
                continue;
            }
        }

        if (/^(.*)\/\/.*$/ := line) {
            line = line[0..findFirst(line, "//")];
        }
        line = trim(line); // Re-trim after removing inline comment

        if (line == "" || startsWith(line, "//")) {
            continue; // Skip lines that are now empty or were only single-line comments
        }
        
        line = replaceAll(line, "\\s+", " ");
        line = trim(line);
        result += [line];
    }
    return result;
}

list[str] tokenizeLine(str line, bool type1) {
    line = trim(line);
    
    if (line == "") {
        return [];
    }
    
    list[str] tokens = [];
    str current = "";
    
    // Java keywords
    set[str] keywords = {
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
        "class", "const", "continue", "default", "do", "double", "else", "enum",
        "extends", "final", "finally", "float", "for", "goto", "if", "implements",
        "import", "instanceof", "int", "interface", "long", "native", "new", "package",
        "private", "protected", "public", "return", "short", "static", "strictfp",
        "super", "switch", "synchronized", "this", "throw", "throws", "transient",
        "try", "void", "volatile", "while", "true", "false", "null"
    };
    
    // Java operators and separators
    set[str] operators = {
        "+", "-", "*", "/", "%", "++", "--",
        "==", "!=", "\>", "\<", "\>=", "\<=",
        "&&", "||", "!",
        "&", "|", "^", "~", "\<\<", "\>\>", "\>\>\>",
        "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "\<\<=", "\>\>=", "\>\>\>=",
        "(", ")", "{", "}", "[", "]",
        ";", ",", ".", ":", "?", "@"
    };
    
    int i = 0;
    while (i < size(line)) {
        str ch = substring(line, i, i+1);
        
        // Check for two-character operators
        if (i + 1 < size(line)) {
            str twoChar = substring(line, i, i+2);
            if (twoChar in operators) {
                if (current != "") {
                    tokens += classifyToken(current, keywords, type1);
                    current = "";
                }
                tokens += twoChar;
                i += 2;
                continue;
            }
        }
        
        // Check for single-character operators/separators
        if (ch in operators) {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            tokens += ch;
            i += 1;
        }
        // Whitespace
        else if (ch == " " || ch == "\t") {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            i += 1;
        }
        // String literals
        else if (ch == "\"") {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            tokens += "STRING_LITERAL<(ch)>";
            i += 1;
            // Skip to end of string
            while (i < size(line) && substring(line, i, i+1) != "\"") {
                if (substring(line, i, i+1) == "\\") {
                    i += 2; // Skip escaped character
                } else {
                    i += 1;
                }
            }
            i += 1; // Skip closing quote
        }
        // Character literals
        else if (ch == "\'") {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            tokens += "CHAR_LITERAL<(ch)>";
            i += 1;
            // Skip to end of char
            while (i < size(line) && substring(line, i, i+1) != "\'") {
                if (substring(line, i, i+1) == "\\") {
                    i += 2;
                } else {
                    i += 1;
                }
            }
            i += 1;
        }
        // Regular characters (identifiers, numbers, etc.)
        else {
            current += ch;
            i += 1;
        }
    }
    
    if (current != "") {
        tokens += classifyToken(current, keywords, type1);
    }
    
    return tokens;
}

str classifyToken(str token, set[str] keywords, bool type1) {
    // Check if it's a keyword
    if (token in keywords) {
        return token;
    }
    
    // Check if it's a number
    if (/^[0-9]+$/ := token || /^[0-9]+\.[0-9]+$/ := token || /^[0-9]+[lLfFdD]$/ := token || /^[0-9]+\.[0-9]+[fFdD]$/ := token) {
        return "NUMBER_LITERAL<type1 ? "(<token>)" : "">";
    }
    
    // Otherwise it's an identifier
    return "IDENTIFIER<type1 ? "(<token>)" : "">";
}
