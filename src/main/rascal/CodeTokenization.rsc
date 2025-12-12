module CodeTokenization

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::json::IO;
import lang::java::m3::Core;
import lang::java::m3::AST;

set[str] keywords = {
    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
    "class", "const", "continue", "default", "do", "double", "else", "enum",
    "extends", "final", "finally", "float", "for", "goto", "if", "implements",
    "import", "instanceof", "int", "interface", "long", "native", "new", "package",
    "private", "protected", "public", "return", "short", "static", "strictfp",
    "super", "switch", "synchronized", "this", "throw", "throws", "transient",
    "try", "void", "volatile", "while", "true", "false", "null"
};

set[str] operators = {
    "+", "-", "*", "/", "%", "++", "--",
    "==", "!=", "\>", "\<", "\>=", "\<=",
    "&&", "||", "!",
    "&", "|", "^", "~", "\<\<", "\>\>", "\>\>\>",
    "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "\<\<=", "\>\>=", "\>\>\>=",
    "(", ")", "{", "}", "[", "]",
    ";", ",", ".", ":", "?", "@"
};

/**
 * Normalizes lines from a source file or declaration by removing comments, trimming, and collapsing whitespace.
 * 
 * @param dec  The file or declaration location to normalize.
 * @return     List of normalized lines as strings.
 */ 
public list[str] normalizeLines(loc dec) {
    list[str] result = [];
    bool inBlock = false;

    for (str raw <- readFileLines(dec)) {
        str line = trim(raw);

        if (inBlock) {
            if (contains(line, "*/")) {
                inBlock = false;
            }
            continue;
        }
        if (startsWith(line, "/*")) {
            line = replaceAll(line, "/\\*|\\*/", ""); 
            if (line == "") continue;

            if (!contains(raw, "*/")) { 
                inBlock = true;
                continue;
            }
        }
        if (/^(.*)\/\/.*$/ := line) {
            line = line[0..findFirst(line, "//")];
        }
        line = trim(line); 

        if (line == "" || startsWith(line, "//")) {
            continue; 
        }
        line = replaceAll(line, "\\s+", " ");
        line = trim(line);
        result += [line];
    }
    return result;
}

/**
 * Tokenizes a single line of code into keywords, identifiers, literals, and operators.
 * 
 * @param line              The line of code to tokenize.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  List of tokens extracted from the line.
 */
list[str] tokenizeLine(str line, bool withTypeLiterals) {
    line = trim(line);
    
    if (line == "") {
        return [];
    }
    list[str] tokens = [];
    str current = "";
    
    int i = 0;
    while (i < size(line)) {
        str ch = substring(line, i, i+1);
        
        if (i + 1 < size(line)) {
            str twoChar = substring(line, i, i+2);

            if (twoChar in operators) {
                if (current != "") {
                    tokens += classifyToken(current, withTypeLiterals);
                    current = "";
                }
                tokens += twoChar;
                i += 2;
                continue;
            }
        }
        if (ch in operators) {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
                current = "";
            }
            tokens += ch;
            i += 1;
        } else if (ch == " " || ch == "\t") {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
                current = "";
            }
            i += 1;
        } else if (ch == "\"") {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
                current = "";
            }
            tokens += "STRING_LITERAL<(ch)>";
            i += 1;
            
            while (i < size(line) && substring(line, i, i+1) != "\"") {
                if (substring(line, i, i+1) == "\\") {
                    i += 2; 
                } else {
                    i += 1;
                }
            }
            i += 1; 
        } else if (ch == "\'") {
            if (current != "") {
                tokens += classifyToken(current, withTypeLiterals);
                current = "";
            }
            tokens += "CHAR_LITERAL<(ch)>";
            i += 1;
            
            while (i < size(line) && substring(line, i, i+1) != "\'") {
                if (substring(line, i, i+1) == "\\") {
                    i += 2;
                } else {
                    i += 1;
                }
            }
            i += 1;
        } else {
            current += ch;
            i += 1;
        }
    }
    if (current != "") {
        tokens += classifyToken(current, withTypeLiterals);
    }
    return tokens;
}

/**
 * Classifies a single token as a keyword, number literal, or identifier (optionally including the literal value for Type I clones).
 * 
 * @param token             The string token to classify.
 * @param keywords          Set of keywords for the language.
 * @param withTypeLiterals  True if detecting Type I clones, false for Type II.
 * @return                  The classified token string.
 */
str classifyToken(str token, bool withTypeLiterals) {
    if (token in keywords) { // TODO - maybe use AST keyword tokens
        return token;
    }
    if (/^[0-9]+$/ := token || /^[0-9]+\.[0-9]+$/ := token || /^[0-9]+[lLfFdD]$/ := token || /^[0-9]+\.[0-9]+[fFdD]$/ := token) {
        return "NUMBER_LITERAL<withTypeLiterals ? "(<token>)" : "">";
    }
    return "IDENTIFIER<withTypeLiterals ? "(<token>)" : "">";
}
