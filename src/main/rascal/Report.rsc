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

import DataTypes;

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
 * @param duration    The total time taken for the detection in milliseconds.
 */
void printCloneReport(str name, list[CloneClass] clones, int totalLines, int duration) {
    println("=====================================");
    println("<name> Clone Detection Report");
    println("Completed in (<duration / 1000.0>s).");
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
    
    if (isEmpty(clones)) {
        println("No clones detected.");
        return;
    }
    CloneClass largestClone = clones[0];

    for (clone <- clones) {
        if (size(clone.members) > size(largestClone.members)) {
            largestClone = clone;
        }
    }
    
    println("-------------------------------------");
    println("  Largest Clone Class:");
    println("  Size: <size(largestClone.members)> members");
    println("  Instances: <size(largestClone.members)>");
    println("  Total lines: <size(largestClone.members) * largestClone.sizeLines>");

    println("  Code Snippet:");
    println("---");
    println("<largestClone.members[0].text>");
    println("---");
    println("  Locations:");
    
    for (member <- largestClone.members) {
        println("    - <member.location> from lines <member.startLine> to <member.endLine>");
    }
    println();
    println("=====================================");
}
