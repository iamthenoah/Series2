module Main

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import Map;
import List;
import Set;
import String;
import util::Math;
import CloneDetection;

// Simple data container for the Series 2 clone report.
data CloneReport = cloneReport(
    int duplicatedLines,
    real duplicatedPercentage,
    int numberOfClones,
    int numberOfCloneClasses,
    int biggestCloneLines,
    int biggestCloneClassMembers,
    list[str] exampleClones,
    loc outputFile
);

/*
 * Series 2 entry point.
 * - Builds an M3 model for the given project
 * - Runs (placeholder) AST-based Type I clone detection
 * - Writes clone classes to a textual file (placeholder)
 * - Prints required cloning statistics
 *
 * The actual clone detection logic is left as commented Python-style pseudocode
 * as requested.
 */
public int main(loc project) {
    M3 model = createM3FromMavenProject(project);
    list[loc] javaFiles = toList(files(model));

    // Choose where to write textual clone classes (adjust as needed).
    loc cloneOutputFile = |file:///tmp/clone-classes.txt|;

    CloneReport cr = collectCloneReport(javaFiles, cloneOutputFile);

    println();
    println("======= Java Project Clone Report =======");
    println();
    println("- Analyzing project: <project> (<size(javaFiles)> Java files)");
    println();
    printCloneReport(cr);
    println();
    println("======= =========================== =======");
    println();

    return 0;
}

// ---------------------------------------------------------
// Clone collection (placeholder with Python pseudocode)
// ---------------------------------------------------------

/*
 * How this Series 2 clone pipeline is supposed to work (theory → implementation)
 *
 * Theory ( Roy et al. 2009 “Comparison and Evaluation of Code Clone Detection Techniques and Tools”, Rattan et al. 2013 “Software Clone Detection: A Systematic Review”, Roy et al. 2014 “The Vision of Software Clone Management”):
 * - Target: detect at least Type I clones (identical code, ignoring whitespace/comments) using AST-backed normalization, then manage them (subsumption, reporting).
 * - Units: typically method bodies / constructors / initializers extracted from the Java AST. Type I requires strict textual identity after normalization.
 * - Normalization: strip comments/whitespace (cf. token/text-based detectors in surveys) to remove layout/noise while keeping structural sameness.
 * - Grouping: hash normalized units; identical hashes form a clone class (Type I). This is akin to token-hash or pretty-print+hash in the surveys.
 * - Subsumption: drop clone classes that are fully contained in another clone class, to avoid nested/duplicate reporting (as required by the assignment).
 * - Metrics/reporting: compute duplicated lines (% over total), number of clones, number of clone classes, biggest clone (lines), biggest class (members),
 *   and provide example clones. Persist clone classes to a textual file. This aligns with the assignment’s reporting requirements.
 *
 * Mapping to this implementation skeleton:
 * - Build ASTs → CloneDetection::parseJavaFiles(javaFiles) — expected to call Rascal’s Java front-end (placeholder).
 * - Extract/normalize/hash units → CloneDetection::detectTypeIClones(asts) — expected to follow Duplication example style (normalize, hash blocks/units) but at unit granularity.
 * - Subsumption filtering → CloneDetection::removeSubsumedClasses(cloneClasses) — expected to compare member intervals and drop contained classes.
 * - Persist clone classes → CloneDetection::writeCloneClasses(outputFile, cloneClasses) — expected to emit a human-readable list of classes and member locations.
 * - Compute stats → CloneDetection::computeStats(cloneClasses, javaFiles) — expected to union duplicated line ranges, count classes/members, pick examples.
 *
 * Practical shortcuts (to be explicit about simplifications):
 * - Placeholder Rascal code: actual parsing, normalization, hashing, interval math, and file I/O are not implemented here; they must be filled in using patterns
 *   similar to Cloning/example/rascal/Duplication.rsc (normalization, block hashing) and the assignment’s AST-based guidance.
 * - Type coverage: only Type I is sketched. Extending to Type II/III would require further normalization (e.g., identifiers/literals normalization or structural
 *   similarity) as discussed in the surveyed techniques.
 */
private CloneReport collectCloneReport(list[loc] javaFiles, loc outputFile) {
    map[loc, value] asts = CloneDetection::parseJavaFiles(javaFiles);
    list[CloneDetection::CloneClass] cloneClasses = CloneDetection::detectTypeIClones(asts);
    cloneClasses = CloneDetection::removeSubsumedClasses(cloneClasses);
    CloneDetection::writeCloneClasses(outputFile, cloneClasses);
    CloneDetection::CloneStats stats = CloneDetection::computeStats(cloneClasses, javaFiles);

    return cloneReport(
        stats.duplicatedLines,
        stats.duplicatedPercentage,
        stats.numberOfClones,
        stats.numberOfCloneClasses,
        stats.biggestCloneLines,
        stats.biggestCloneClassMembers,
        stats.exampleClones,
        outputFile
    );
}

// ---------------------------------------------------------
// Printing utilities for Series 2 requirements
// ---------------------------------------------------------

private void printCloneReport(CloneReport cr) {
    println("--- Clone Detection (Series 2)");
    println();
    println("  Clone classes file:      <cr.outputFile>");
    println("  Duplicated Lines:        <cr.duplicatedLines>");
    println("  Percentage:              <round(cr.duplicatedPercentage, 0.1)>%");
    println("  Number of Clones:        <cr.numberOfClones>");
    println("  Number of Clone Classes: <cr.numberOfCloneClasses>");
    println("  Biggest Clone (lines):   <cr.biggestCloneLines>");
    println("  Biggest Clone Class:     <cr.biggestCloneClassMembers> members");
    println();
    println("  Example Clones:");
    for (c <- cr.exampleClones) {
        println("    - <c>");
    }
    println();

    // Placeholder for back-end vs. front-end routes and additional algorithms.
    /*
    # Python-style pseudocode for optional extensions:
    #
    # def collect_additional_algorithms(java_files):
    #     # Run Type II / Type III detectors
    #     # Compare statistics between algorithms
    #     return comparison_table
    #
    # def generate_visualizations(clone_classes):
    #     # Build interactive visuals (e.g., scatter plots, treemaps, timelines)
    #     # Export to HTML/JS for maintenance insights
    */
}
