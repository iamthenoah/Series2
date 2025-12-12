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
    <type1, t1TotalLines> = detectTypeIClone(project);
    printCloneReport("Type I", type1, t1TotalLines);
    exportCloneDataAsJson(project, "type_1", type1);

    <clones, t2TotalLines> = detectTypeIIClone(project);
    // DISCLAIMER: There seams to be a rascal type system issue here that gives an unsolvable type error.
    // see CloneDetection::filterTypeIIClones for more details.
    list[CloneClass] type2 = filterTypeIIClones(clones);
    printCloneReport("Type II", type2, t2TotalLines);
    exportCloneDataAsJson(project, "type_2", type2);
    return 0;
}
