module CodeExtraction

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::json::IO;
import lang::java::m3::Core;
import lang::java::m3::AST;

import CloneDetection;
import CodeTokenization;

/**
 * Traverses the project AST and extracts code blocks from all methods/constructors for clone detection.
 * 
 * @param project           The root location of the project to analyze.
 * @param minLines          Minimum number of lines for a block to be considered.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  A map from block hashes to lists of clone members.
 */
map[str, list[CloneMember]] extractCodeBlocks(loc project, int minLines, bool withTypeLiterals) {
    map[str, list[CloneMember]] blocks = ();
    M3 model = createM3FromMavenProject(project);

    for (file <- files(model)) {
        Declaration ast = createAstFromFile(file, true);
        
        for (/Declaration d := ast) {
            if (d is method || d is constructor) {
                blocks = extractFromDeclaration(d, file, minLines, blocks, withTypeLiterals);
            }
        }
    }
    return blocks;
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

