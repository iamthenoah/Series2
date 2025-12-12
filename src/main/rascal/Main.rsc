module Main

import IO;
import lang::json::IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::java::m3::Core;
import lang::java::m3::AST;

data CloneMember = cloneMember(loc location, int startLine, int endLine, str text);

data CloneClass = cloneClass( list[CloneMember] members, int sizeLines, int sizeMembers);

public int main(loc project) {
    list[CloneClass] typeI = detectTypeIClone(project);
    list[CloneClass] typeII = detectTypeIIClone(project);

    printCloneReport("Type I", typeI);
    printCloneReport("Type II", typeII);
    exportCloneDataAsJson(project, "type_1", typeI);
    exportCloneDataAsJson(project, "type_2", typeII);

    return 0;
}

void exportCloneDataAsJson(loc project, str name, list[CloneClass] raw) {
    loc outFile = project + "/<name>_clones.json";
    writeJSON(outFile, raw, indent=2);
    println("Exported clone data to <outFile>");
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
        println("  Size: <clone.sizeLines> lines");
        println("  Instances: <clone.sizeMembers>");
        println("  Locations:");
        
        for (member <- clone.members) {
            println("    - <member.location.path>");
            println("      Lines <member.startLine>-<member.endLine>");
            println("      Text");
            println("<member.text>");
        }
        println();
    }
    println("=====================================");
}

list[CloneClass] detectTypeIClone(loc project) {
    return detectTypeClone(project, 6, true);
}

list[CloneClass] detectTypeIIClone(loc project) {
    list[CloneClass] classes = detectTypeClone(project, 6, false);
    list[CloneClass] result = [];

    for (cloneClass(members, sizeLines, sizeMembers) <- classes) {
        set[str] seenTexts = {};
        list[CloneMember] unique = [];

        for (m <- members) {
            if (m.text notin seenTexts) {
                seenTexts += { m.text };
                unique += [m];
            }
        }
        if (size(unique) <= 1) {
            continue;
        }
        result += [cloneClass(unique,sizeLines,size(unique))];
    }
    return result;
}

list[CloneClass] detectTypeClone(loc project, int minLines, bool type1) {
    map[str, list[CloneMember]] codeBlocks = extractCodeBlocks(project, minLines, type1);
    list[CloneClass] cloneClasses = [];
    
    for (hash <- codeBlocks) {
        list[CloneMember] members = codeBlocks[hash];

        if (size(members) > 1) {
            int sizeLines = members[0].endLine - members[0].startLine + 1;
            cloneClasses += cloneClass( members,sizeLines, size(members));
        }
    }
    return filterOverlappingClones(cloneClasses);
}

list[CloneClass] filterOverlappingClones(list[CloneClass] clones) {
    clones = sort(clones, bool (CloneClass a, CloneClass b) {
        return a.sizeLines > b.sizeLines;
    });

    list[CloneClass] filtered = [];
    set[tuple[loc, int, int]] usedRanges = {};

    for (clone <- clones) {
        bool hasOverlap = false;
        
        for (member <- clone.members) {
            for (usedRange <- usedRanges) {
                if (usedRange[0] == member.location) {
                    if (!(member.endLine < usedRange[1] || member.startLine > usedRange[2])) {
                        hasOverlap = true;
                        break;
                    }
                }
            }
            if (hasOverlap) break;
        }
        if (!hasOverlap) {
            filtered += clone;
            
            for (member <- clone.members) {
                usedRanges += { <member.location, member.startLine, member.endLine> };
            }
        }
    }
    return filtered;
}

map[str, list[CloneMember]] extractCodeBlocks(loc project, int minLines, bool type1) {
    map[str, list[CloneMember]] blocks = ();
    M3 model = createM3FromMavenProject(project);

    for (file <- files(model)) {
        Declaration ast = createAstFromFile(file, true);
        
        for (/Declaration d := ast) {
            if (d is method || d is constructor) {
                blocks = extractFromDeclaration(d, file, minLines, blocks, type1);
            }
        }
    }
    return blocks;
}

map[str, list[CloneMember]] extractFromDeclaration(Declaration d, loc file, int minLines, map[str, list[CloneMember]] blocks, bool type1) {
    list[str] lines = normalizeLines(d.src);
    
    if (size(lines) < minLines) {
        return blocks;
    }
    list[list[str]] tokenizedLines = [tokenizeLine(line, type1) | line <- lines];

    while (!isEmpty(tokenizedLines) && isEmpty(tokenizedLines[0])) {
        tokenizedLines = tail(tokenizedLines);
    }
    while (!isEmpty(tokenizedLines) && isEmpty(tokenizedLines[-1])) {
        tokenizedLines = prefix(tokenizedLines);
    }
    if (size(tokenizedLines) < minLines) {
        return blocks;
    }
    for (int i <- [0..size(tokenizedLines) - minLines + 1]) {
        list[list[str]] block = slice(tokenizedLines, i, minLines);
        
        if (all(tokenLine <- block, isEmpty(tokenLine))) {
            continue;
        }
        str blockHash = intercalate(" ", [token | tokenLine <- block, token <- tokenLine]);
        int startLine = d.src.begin.line + i;
        int endLine = startLine + minLines - 1;
        list[str] originalLines = slice(lines, i, minLines);
        str cloneText = intercalate("\n", originalLines);
        CloneMember member = cloneMember(file, startLine, endLine, cloneText);
        
        if (blockHash in blocks) {
            blocks[blockHash] += member;
        } else {
            blocks[blockHash] = [member];
        }
    }
    return blocks;
}

public list[str] normalizeLines(loc dec) {
    list[str] result = [];
    bool inBlock = false;

    for (str raw <- readFileLines(dec)) {
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
        line = trim(line); 

        if (line == "" || startsWith(line, "//")) {
            continue; 
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
    
    set[str] keywords = {
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
        "class", "const", "continue", "default", "do", "double", "else", "enum",
        "extends", "final", "finally", "float", "for", "goto", "if", "implements",
        "import", "instanceof", "int", "interface", "long", "native", "new", "package",
        "private", "protected", "public", "return", "short", "static", "strictfp",
        "super", "switch", "synchronized", "this", "throw", "throws", "transient",
        "try", "void", "volatile", "while", "true", "false", "null"
    };
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
        if (ch in operators) {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            tokens += ch;
            i += 1;
        } else if (ch == " " || ch == "\t") {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            i += 1;
        } else if (ch == "\"") {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            tokens += "STRING_LITERAL<(ch)>";
            i += 1;
            
            while (i < size(line) && substring(line, i, i+1) != "\"") {
                if (substring(line, i, i+1) == "\\") {
                    i += 2; 
                } else {
                    i += 1;
                }
            }
            i += 1; 
        } else if (ch == "\'") {
            if (current != "") {
                tokens += classifyToken(current, keywords, type1);
                current = "";
            }
            tokens += "CHAR_LITERAL<(ch)>";
            i += 1;
            
            while (i < size(line) && substring(line, i, i+1) != "\'") {
                if (substring(line, i, i+1) == "\\") {
                    i += 2;
                } else {
                    i += 1;
                }
            }
            i += 1;
        } else {
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
    if (token in keywords) {
        return token;
    }
    if (/^[0-9]+$/ := token || /^[0-9]+\.[0-9]+$/ := token || /^[0-9]+[lLfFdD]$/ := token || /^[0-9]+\.[0-9]+[fFdD]$/ := token) {
        return "NUMBER_LITERAL<type1 ? "(<token>)" : "">";
    }
    return "IDENTIFIER<type1 ? "(<token>)" : "">";
}
