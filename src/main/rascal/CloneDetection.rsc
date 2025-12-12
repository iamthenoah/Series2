module CloneDetection

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::json::IO;
import lang::java::m3::Core;
import lang::java::m3::AST;

import CodeTokenization;

/**
 * Data structure representing a single clone member in the codebase.
 * 
 * @param location   The file location of the clone member.
 * @param startLine  The starting line number of the clone member.
 * @param endLine    The ending line number of the clone member.
 * @param text       The actual text content of the clone member.
 */
data CloneMember = cloneMember(loc location, int startLine, int endLine, str text);

/**
 * Data structure representing a class of clones.
 * 
 * @param members     The list of clone members in this class.
 * @param sizeLines   The number of lines in each clone member.
 */
data CloneClass = cloneClass(list[CloneMember] members, int sizeLines);

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
 tuple[list[CloneClass], int] detectTypeIIClone(loc project) {
    <classes, totalLines> = detectTypeClone(project, 6, false); // throws "Expected set[loc] (M3), but got list[CloneClass]"

    println("<totalLines> total lines processed for Type II clone detection.");
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
    return <result, totalLines>;
 }
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

