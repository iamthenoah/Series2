module Report

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

/**
 * Exports a list of clone classes to a JSON file in the project root.
 * 
 * @param project  The location of the root folder of the project.
 * @param name     Name to use in the output JSON file.
 * @param raw      The list of clone classes to export.
 */
void exportCloneDataAsJson(loc project, str name, list[CloneClass] raw) {
    loc outFile = project + "/<name>_clones.json";
    writeJSON(outFile, raw, indent=2);
    println("Exported clone data to <outFile>");
}

/**
 * Prints a detailed clone detection report with number of clones, lines, and code snippets.
 * 
 * @param name        The clone type to display (e.g., "Type I" or "Type II").
 * @param clones      The list of clone classes to print in the report.
 * @param totalLines  The total number of lines processed in the project.
 */
void printCloneReport(str name, list[CloneClass] clones, int totalLines) {
    println("=====================================");
    println("<name> Clone Detection Report");
    println("=====================================");
    println("Total clone classes found: <size(clones)>");
    println();
    
    if (isEmpty(clones)) {
        println("No clones detected.");
        return;
    }
    int totalCloneInstances = (0 | it + size(cc.members) | cc <- clones);
    int totalClonedLines = (0 | it + (cc.sizeLines * size(cc.members)) | cc <- clones);
    real duplicationPercent = totalLines > 0.0 ? (totalClonedLines * 100.0) / totalLines : 0.0;

    println("Total clone instances: <totalCloneInstances>");
    println("Total cloned lines: <totalClonedLines>");
    println("Total lines processed: <totalLines>");
    println("Clone line duplication: <duplicationPercent>%");
    println();
    
    for (clone <- clones) {
        println("-------------------------------------");
        println("  Size: <clone.sizeLines> lines");
        println("  Instances: <size(clone.members)>");
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
