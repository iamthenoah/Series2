module CloneDetection

import IO;
import List;
import Set;
import Map;
import String;

// ------------------------------------------------------------
// Python-style pseudocode overview (Series 2 pipeline)
// ------------------------------------------------------------
/*
# 1) Build ASTs for each Java file
#    asts = parse_java_files(java_files)
#
# 2) Detect Type I clones (AST-based, whitespace/comments ignored)
#    clone_classes = detect_type_i_clones(asts)
#
# 3) Drop clone classes strictly contained in others (subsumption)
#    clone_classes = remove_subsumed_classes(clone_classes)
#
# 4) Persist textual representation of clone classes
#    write_clone_classes(output_file, clone_classes)
#
# 5) Compute statistics
#    stats = compute_stats(clone_classes, java_files)
*/

// ------------------------------------------------------------
// Data containers (sketch)
// ------------------------------------------------------------
data CloneMember = cloneMember(loc file, int startLine, int endLine, str text, int sizeLines);
data CloneClass  = cloneClass(int id, list[CloneMember] members, int sizeLines, int sizeMembers);
data CloneStats  = cloneStats(
    int duplicatedLines,
    real duplicatedPercentage,
    int numberOfClones,
    int numberOfCloneClasses,
    int biggestCloneLines,
    int biggestCloneClassMembers,
    list[str] exampleClones
);

// ------------------------------------------------------------
// 1) Build ASTs for each Java file
// ------------------------------------------------------------
/*
def parse_java_files(java_files):
    asts = {}
    for f in java_files:
        try:
            ast = parse_java(f)  # Rascal Java parser
            asts[f] = ast
        except ParseError:
            continue
    return asts
*/
public map[loc, value] parseJavaFiles(list[loc] javaFiles) {
    map[loc, value] asts = ();
    // placeholder: in real code call Rascal Java parser and fill asts
    return asts;
}

// ------------------------------------------------------------
// 2) Detect Type I clones over ASTs
// ------------------------------------------------------------
/*
def detect_type_i_clones(asts):
    hash_to_members = {}
    for file_loc, ast in asts.items():
        for unit in extract_units(ast):  # methods/ctors/initializers
            frag_text, start, end = slice_source(unit, file_loc)
            normalized = normalize_whitespace_and_comments(frag_text)
            h = sha1(normalized)
            hash_to_members.setdefault(h, []).append({
                "file": file_loc,
                "start_line": start,
                "end_line": end,
                "text": frag_text,
                "size_lines": end - start + 1
            })
    clone_classes = []
    cid = 1
    for h, members in hash_to_members.items():
        if len(members) < 2:
            continue
        clone_classes.append({
            "id": cid,
            "members": members,
            "size_lines": max(m["size_lines"] for m in members),
            "size_members": len(members)
        })
        cid += 1
    return clone_classes
*/
public list[CloneClass] detectTypeIClones(map[loc, value] asts) {
    list[CloneClass] cloneClasses = [];
    // placeholder: use normalization + hashing like in examples
    return cloneClasses;
}

// ------------------------------------------------------------
// 3) Drop clone classes strictly contained in others (subsumption)
// ------------------------------------------------------------
/*
def remove_subsumed_classes(clone_classes):
    kept = []
    for i, cc in enumerate(clone_classes):
        subsumed = False
        for j, other in enumerate(clone_classes):
            if i == j:
                continue
            if all(member_contained(m, other["members"]) for m in cc["members"]):
                subsumed = True
                break
        if not subsumed:
            kept.append(cc)
    return kept
*/
public list[CloneClass] removeSubsumedClasses(list[CloneClass] cloneClasses) {
    // placeholder: containment check between member intervals
    return cloneClasses;
}

// ------------------------------------------------------------
// 4) Persist textual representation of clone classes
// ------------------------------------------------------------
/*
def write_clone_classes(output_file, clone_classes):
    with open(output_file, "w", encoding="utf-8") as out:
        for cc in clone_classes:
            out.write(f"CloneClass {cc['id']} (members: {cc['size_members']}, max_lines: {cc['size_lines']})\n")
            for m in cc["members"]:
                out.write(f"  - {m['file']}:{m['start_line']}-{m['end_line']}\n")
            out.write("\n")
*/
public void writeCloneClasses(loc outputFile, list[CloneClass] cloneClasses) {
    // placeholder: use writeFile/append to produce textual clone class listing
    return;
}

// ------------------------------------------------------------
// 5) Compute statistics
// ------------------------------------------------------------
/*
def compute_stats(clone_classes, java_files):
    total_lines = count_total_lines(java_files)
    line_spans = set()
    for cc in clone_classes:
        for m in cc["members"]:
            for ln in range(m["start_line"], m["end_line"] + 1):
                line_spans.add((m["file"], ln))
    duplicated_lines = len(line_spans)
    duplicated_percentage = 0.0 if total_lines == 0 else (duplicated_lines * 100.0) / total_lines
    number_of_clones = sum(len(cc["members"]) for cc in clone_classes)
    number_of_clone_classes = len(clone_classes)
    biggest_clone_lines = max([m["size_lines"] for cc in clone_classes for m in cc["members"]], default=0)
    biggest_clone_class_members = max([cc["size_members"] for cc in clone_classes], default=0)
    sorted_classes = sorted(clone_classes, key=lambda cc: cc["size_members"], reverse=True)
    example_clones = []
    for cc in sorted_classes[:3]:
        m = cc["members"][0]
        example_clones.append(f"{m['file']}:{m['start_line']}-{m['end_line']}")
    return {
        "duplicated_lines": duplicated_lines,
        "duplicated_percentage": duplicated_percentage,
        "number_of_clones": number_of_clones,
        "number_of_clone_classes": number_of_clone_classes,
        "biggest_clone_lines": biggest_clone_lines,
        "biggest_clone_class_members": biggest_clone_class_members,
        "example_clones": example_clones,
    }
*/
public CloneStats computeStats(list[CloneClass] cloneClasses, list[loc] javaFiles) {
    // placeholder: compute duplicated lines and other stats similar to pseudocode
    return cloneStats(0, 0.0, 0, 0, 0, 0, []);
}

