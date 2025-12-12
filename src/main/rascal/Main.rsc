module Main

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
import Report;

/** 
 * Entry point for clone detection. Detects Type I and Type II clones, prints reports, and exports JSON.
 * 
 * @param project  The location of the root folder of the project to analyze.
 * @return         Status code (0 = success).
 */
public int main(loc project) {
    list[CloneClass] typeI = detectTypeIClone(project);
    printCloneReport("Type I", typeI);
    exportCloneDataAsJson(project, "type_1", typeI);

    list[CloneClass] typeII = detectTypeIIClone(project);
    printCloneReport("Type II", typeII);
    exportCloneDataAsJson(project, "type_2", typeII);

    return 0;
}
