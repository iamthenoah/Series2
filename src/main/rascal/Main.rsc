module Main

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import util::Benchmark;
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
    println("Starting clone detection...");
    println();
    
    // Type I detection with timing
    int type1Start = realTime();
    <type1, t1TotalLines> = detectTypeIClone(project);
    int type1Duration = realTime() - type1Start;
    printCloneReport("Type I", type1, t1TotalLines, type1Duration);
    exportCloneDataAsJson(project, "type_1", type1);
    println();
    
    // Type II detection with timing
    int type2Start = realTime();
    <clones, t2TotalLines> = detectTypeIIClone(project);
    // DISCLAIMER: There seams to be a rascal type system issue here that gives an unsolvable type error.
    // see CloneDetection::filterTypeIIClones for more details.
    list[CloneClass] type2 = filterTypeIIClones(clones);
    int type2Duration = realTime() - type2Start;
    printCloneReport("Type II", type2, t2TotalLines, type2Duration);
    exportCloneDataAsJson(project, "type_2", type2);
    println();
    
    // Total time
    int totalDuration = type1Duration + type2Duration;
    println("=====================================");
    println("Total analysis time: <totalDuration>ms (<totalDuration / 1000.0>s)");
    println("=====================================");
    
    return 0;
}