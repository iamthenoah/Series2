module CloneDetectionAST

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import util::Benchmark;
import lang::java::m3::Core;
import lang::java::m3::AST;

import DataTypes;

/**
 * Detects Type I clones (exact matches) using AST comparison.
 */
public tuple[list[CloneClass], int] detectTypeIClone(loc project) {
    return detectClones(project, 6, false);
}

/**
 * Detects Type II clones (allowing renamed identifiers and literals).
 */
public tuple[list[CloneClass], int] detectTypeIIClone(loc project) {
    return detectClones(project, 6, true);
}

/**
 * Generic AST-based clone detection.
 * 
 * @param project - Project location
 * @param minSize - Minimum number of statements
 * @param normalize - True for Type II (normalize identifiers/literals)
 */
tuple[list[CloneClass], int] detectClones(loc project, int minSize, bool normalize) {
    M3 model = createM3FromMavenProject(project);
    map[str, list[CloneMember]] buckets = ();
    int totalLines = 0;
    
    for (file <- files(model)) {
        try {
            Declaration ast = createAstFromFile(file, true);
            
            for (/Declaration d := ast) {
                if (d is method || d is constructor) {
                    buckets = extractCandidates(d.impl, file, minSize, normalize, buckets);
                    totalLines += d.src.end.line - d.src.begin.line + 1;
                }
            }
        } catch e: {
            println("Warning: Could not parse <file>: <e>");
        }
    }
    list[CloneClass] cloneClasses = [
        cloneClass(members, members[0].endLine - members[0].startLine + 1)
        | hash <- buckets, members := buckets[hash], size(members) > 1
    ];
    cloneClasses = filterSubsumedClones(cloneClasses);
    
    return <cloneClasses, totalLines>;
}

/**
 * Extracts clone candidates from a method/constructor body.
 */
map[str, list[CloneMember]] extractCandidates(
    Statement impl,
    loc file,
    int minSize,
    bool normalize,
    map[str, list[CloneMember]] buckets
) {
    list[Statement] stmts = block(stmts) := impl ? stmts : [impl];
    if (size(stmts) < minSize) return buckets;
    
    for (int i <- [0..size(stmts) - minSize + 1]) {
        list[Statement] window = slice(stmts, i, minSize);
        str hash = intercalate("|", [serializeStatement(s, normalize) | s <- window]);
        if (hash == "") continue;
        
        int startLine = window[0].src.begin.line;
        int endLine = window[-1].src.end.line;
        
        str sourceText = readFile(file);
        list[str] lines = split("\n", sourceText);
        str cloneText = intercalate("\n", 
            slice(lines, startLine - 1, endLine - startLine + 1));
        CloneMember member = cloneMember(file, startLine, endLine, cloneText);
        
        if (hash in buckets) {
            buckets[hash] += [member];
        } else {
            buckets[hash] = [member];
        }
    }
    return buckets;
}

str serializeStatement(Statement s, bool normalize) {
    visit(s) {
        case \if(cond, thenBranch):
            return "if(<serializeExpr(cond, normalize)>){<serializeStatement(thenBranch, normalize)>}";
        case \if(cond, thenBranch, elseBranch):
            return "if(<serializeExpr(cond, normalize)>){<serializeStatement(thenBranch, normalize)>}else{<serializeStatement(elseBranch, normalize)>}";
        case \while(cond, body):
            return "while(<serializeExpr(cond, normalize)>){<serializeStatement(body, normalize)>}";
        case \for(inits, cond, updaters, body):
            return "for(<intercalate(",", [serializeExpr(e, normalize) | e <- inits])>;<serializeExpr(cond, normalize)>;<intercalate(",", [serializeExpr(e, normalize) | e <- updaters])>){<serializeStatement(body, normalize)>}";
        case \foreach(_, col, body):
             return "foreach(<serializeExpr(col, normalize)>:<serializeExpr(col, normalize)>){<serializeStatement(body, normalize)>}";
        case \return(expr):
            return "return(<serializeExpr(expr, normalize)>)";
        case \return():
            return "return";
        case \declarationStatement(decl):
            return serializeExpr(declarationExpression(decl), normalize);
        case \block(stmts):
            return "{<intercalate(";", [serializeStatement(st, normalize) | st <- stmts])>}";
        case \expressionStatement(expr):
            return serializeExpr(expr, normalize);
        case \assert(expr):
            return "assert(<serializeExpr(expr, normalize)>)";
        case \assert(expr, msg):
            return "assert(<serializeExpr(expr, normalize)>,<serializeExpr(msg, normalize)>)";
        case \break(): return "break";
        case \break(label): return "break(<label>)";
        case \continue(): return "continue";
        case \continue(label): return "continue(<label>)";
        case \throw(expr):
            return "throw(<serializeExpr(expr, normalize)>)";
        case \try(body, catches):
            return "try{<serializeStatement(body, normalize)>}<intercalate("", [serializeCatch(c, normalize) | c <- catches])>";
        case \try(body, catches, finallyBlock):
            return "try{<serializeStatement(body, normalize)>}<intercalate("", [serializeCatch(c, normalize) | c <- catches])>finally{<serializeStatement(finallyBlock, normalize)>}";
    }
    return "";
}

str serializeCatch(Statement c, bool normalize) {
    visit(c) {
        case \catch(param, body):
            return "catch(<serializeExpr(declarationExpression(param), normalize)>){<serializeStatement(body, normalize)>}";
    }
    return "";
}

str serializeExpr(Expression e, bool normalize) {
    visit(e) {
        case \variable(name, _):
            return normalize ? "VAR" : serializeExpr(name, normalize);
        case \variable(name, _, init):
            return normalize ? "VAR=<serializeExpr(init, normalize)>" : "<name>=<serializeExpr(init, normalize)>";
        case \number(val):
            return normalize ? "NUM" : val; 
        case \booleanLiteral(val):
            return "<val>";
        case \stringLiteral(val):
            return normalize ? "STR" : val;
        case \null():"null";
        case \characterLiteral(val):
            return normalize ? "CHAR" : val;
        case \methodCall(_, name, args):
            return normalize ? "ID(<intercalate(",", [serializeExpr(a, normalize) | a <- args])>)" 
                     : "<name>(<intercalate(",", [serializeExpr(a, normalize) | a <- args])>)";
        case \methodCall(exp, _, name, args):
            return "<serializeExpr(exp, normalize)>.<normalize ? "ID" : name>(<intercalate(",", [serializeExpr(a, normalize) | a <- args])>)";
        case \assignment(lhs, op, rhs):
            return "<serializeExpr(lhs, normalize)><op><serializeExpr(rhs, normalize)>";
        case \cast(typ, expr):
            return "(<typ>)<serializeExpr(expr, normalize)>";
        case \newObject(_, typ, args):
            return "new(<intercalate(",", [serializeExpr(a, normalize) | a <- args])>)";
        case \newArray(_, typ, dims):
            return "new[]<intercalate("", ["[<serializeExpr(d, normalize)>]" | d <- dims])>";
        case \arrayAccess(arr, idx):
            return "<serializeExpr(arr, normalize)>[<serializeExpr(idx, normalize)>]";
        case \conditional(cond, thenBr, elseBr):
            return "<serializeExpr(cond, normalize)>?<serializeExpr(thenBr, normalize)>:<serializeExpr(elseBr, normalize)>";
        case \this():
            return "this";
        case \this(expr):
            return "<serializeExpr(expr, normalize)>.this";
        case \super():
            return "super";
    }
    return "";
}

/**
 * Removes clone classes that are subsumed by (contained within) larger ones.
 */
list[CloneClass] filterSubsumedClones(list[CloneClass] clones) {
    clones = sort(clones, bool (CloneClass a, CloneClass b) {
        return a.sizeLines > b.sizeLines;
    });
    
    list[CloneClass] filtered = [];
    set[tuple[loc, int, int]] covered = {};
    
    for (clone <- clones) {
        bool isSubsumed = false;
        
        for (member <- clone.members) {
            for (range <- covered) {
                if (range[0] == member.location) {
                    if (!(member.endLine < range[1] || member.startLine > range[2])) {
                        isSubsumed = true;
                        break;
                    }
                }
            }
            if (isSubsumed) break;
        }
        if (!isSubsumed) {
            filtered += [clone];

            for (member <- clone.members) {
                covered += {<member.location, member.startLine, member.endLine>};
            }
        }
    }
    return filtered;
}
