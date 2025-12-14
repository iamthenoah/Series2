module CloneDetectionToken

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::json::IO;
import lang::java::m3::Core;
import lang::java::m3::AST;

import DataTypes;

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

/**
 * Detects Type I clones in the project using minimum line threshold.
 * 
 * @param project  The root location of the project to analyze.
 * @return         A list of detected Type I clone classes.
 */
tuple[list[CloneClass], int] detectTypeIClone(loc project) {
    return detectTypeClone(project, 6, true);
}

/**
 * Detects Type II clones and removes duplicate members with identical text.
 * 
 * @param project  The root location of the project to analyze.
 * @return         A list of detected Type II clone classes.
 */
tuple[list[CloneClass], int] detectTypeIIClone(loc project) {
    return detectTypeClone(project, 6, false);
}

/**
 * DISCLAIMER: An an ideal scenario, this method should be merged into the method above but rascal does not like it:
 * Filters out duplicate clone members with identical text within each clone class.
 * 
 * @param classes  The list of clone classes to filter.
 * @return         A list of clone classes with unique members.
 */
public list[CloneClass] filterTypeIIClones(list[CloneClass] classes) {
    list[CloneClass] result = [];

    for (cloneClass(members, sizeLines) <- classes) {
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
        result += [cloneClass(unique, sizeLines)];
    }
    return result;
}

/**
 * Generic clone detection method used by Type I and Type II. Extracts code blocks and groups them into clone classes.
 * 
 * @param project           The root location of the project to analyze.
 * @param minLines          Minimum number of lines for a code block to be considered.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  A list of clone classes found in the project along with the total lines processed.
 */
tuple[list[CloneClass], int] detectTypeClone(loc project, int minLines, bool withTypeLiterals) {
    <codeBlocks, totalLines> = extractCodeBlocks(project, minLines, withTypeLiterals);
    list[CloneClass] cloneClasses = [];
    
    for (hash <- codeBlocks) {
        list[CloneMember] members = codeBlocks[hash];

        if (size(members) > 1) {
            int sizeLines = members[0].endLine - members[0].startLine + 1;
            cloneClasses += cloneClass(members, sizeLines);
        }
    }
    return <filterOverlappingClones(cloneClasses), totalLines>;
}

/**
 * Filters out clones that overlap with previously detected clones, keeping the largest clones first.
 * 
 * @param clones  The list of clone classes to filter.
 * @return        A list of clone classes with overlapping ones removed.
 */
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

/**
 * Traverses the project AST and extracts code blocks from all methods/constructors for clone detection.
 * Also calculates the total number of lines processed.
 * 
 * @param project           The root location of the project to analyze.
 * @param minLines          Minimum number of lines for a block to be considered.
 * @param withTypeLiterals  True if including Type I literals, false for Type II.
 * @return                  A tuple containing:
 *                            - map from block hash to lists of clone members
 *                            - total number of lines processed across all declarations
 */
tuple[map[str, list[CloneMember]], int] extractCodeBlocks(loc project, int minLines, bool withTypeLiterals) {
    map[str, list[CloneMember]] blocks = ();
    int totalLines = 0;
    M3 model = createM3FromMavenProject(project);

    for (file <- files(model)) {
        Declaration ast = createAstFromFile(file, true);
        
        for (/Declaration d := ast) {
            if (d is method || d is constructor) {
                blocks = extractFromDeclaration(d, file, minLines, blocks, withTypeLiterals);
                totalLines += size(normalizeLines(d.src)); // accumulate lines processed
            }
        }
    }
    return <blocks, totalLines>;
}

/**
 * Extracts all contiguous slices of code from a single method/constructor declaration.
 * 
 * @param d                 The method or constructor declaration.
 * @param file              The file location of the declaration.
 * @param minLines          Minimum number of lines for a block to be considered.
 * @param blocks            Existing map of hash to clone members to update.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  Updated map of hash to clone members including new blocks.
 */
map[str, list[CloneMember]] extractFromDeclaration(Declaration d, loc file, int minLines, map[str, list[CloneMember]] blocks, bool withTypeLiterals) {
    list[str] lines = normalizeLines(d.src);
    
    if (size(lines) < minLines) {
        return blocks;
    }
    list[list[str]] tokenizedLines = [tokenizeLine(line, withTypeLiterals) | line <- lines];

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

/**
 * Normalizes lines from a source file or declaration by removing comments, trimming, and collapsing whitespace.
 * 
 * @param dec  The file or declaration location to normalize.
 * @return     List of normalized lines as strings.
 */ 
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

/**
 * Tokenizes a single line of code into keywords, identifiers, literals, and operators.
 * 
 * @param line              The line of code to tokenize.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  List of tokens extracted from the line.
 */
list[str] tokenizeLine(str line, bool withTypeLiterals) {
    line = trim(line);
    
    if (line == "") {
        return [];
    }
    list[str] tokens = [];
    str current = "";
    
    int i = 0;
    while (i < size(line)) {
        str ch = substring(line, i, i+1);
        
        if (i + 1 < size(line)) {
            str twoChar = substring(line, i, i+2);

            if (twoChar in operators) {
                if (current != "") {
                    tokens += classifyToken(current, withTypeLiterals);
                    current = "";
                }
                tokens += twoChar;
                i += 2;
                continue;
            }
        }
        if (ch in operators) {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
                current = "";
            }
            tokens += ch;
            i += 1;
        } else if (ch == " " || ch == "\t") {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
                current = "";
            }
            i += 1;
        } else if (ch == "\"") {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
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
                tokens += classifyToken(current, withTypeLiterals);
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
        tokens += classifyToken(current, withTypeLiterals);
    }
    return tokens;
}

/**
 * Classifies a single token as a keyword, number literal, or identifier (optionally including the literal value for Type I clones).
 * 
 * @param token             The string token to classify.
 * @param keywords          Set of keywords for the language.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  The classified token string.
 */
str classifyToken(str token, bool withTypeLiterals) {
    if (token in keywords) { // TODO - maybe use AST keyword tokens
        return token;
    }
    if (/^[0-9]+$/ := token || /^[0-9]+\.[0-9]+$/ := token || /^[0-9]+[lLfFdD]$/ := token || /^[0-9]+\.[0-9]+[fFdD]$/ := token) {
        return "NUMBER_LITERAL<withTypeLiterals ? "(<token>)" : "">";
    }
    return "IDENTIFIER<withTypeLiterals ? "(<token>)" : "">";
}
