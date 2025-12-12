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

import CodeExtraction;

data CloneMember = cloneMember(loc location, int startLine, int endLine, str text);

data CloneClass = cloneClass(list[CloneMember] members, int sizeLines);

/**
 * Detects Type I clones in the project using minimum line threshold.
 * 
 * @param project  The root location of the project to analyze.
 * @return         A list of detected Type I clone classes.
 */
list[CloneClass] detectTypeIClone(loc project) {
    return detectTypeClone(project, 6, true);
}

/**
 * Detects Type II clones and removes duplicate members with identical text.
 * 
 * @param project  The root location of the project to analyze.
 * @return         A list of detected Type II clone classes.
 */
list[CloneClass] detectTypeIIClone(loc project) {
    list[CloneClass] classes = detectTypeClone(project, 6, false);
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
 * @return                  A list of clone classes found in the project.
 */
list[CloneClass] detectTypeClone(loc project, int minLines, bool withTypeLiterals) {
    map[str, list[CloneMember]] codeBlocks = extractCodeBlocks(project, minLines, withTypeLiterals);
    list[CloneClass] cloneClasses = [];
    
    for (hash <- codeBlocks) {
        list[CloneMember] members = codeBlocks[hash];

        if (size(members) > 1) {
            int sizeLines = members[0].endLine - members[0].startLine + 1;
            cloneClasses += cloneClass(members, sizeLines);
        }
    }
    return filterOverlappingClones(cloneClasses);
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
