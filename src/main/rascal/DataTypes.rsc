module DataTypes

import IO;
import List;
import Set;
import Map;
import String;
import util::Math;
import lang::json::IO;
import lang::java::m3::Core;
import lang::java::m3::AST;

/**
 * Data structure representing a single clone member in the codebase.
 * 
 * @param location   The file location of the clone member.
 * @param startLine  The starting line number of the clone member.
 * @param endLine    The ending line number of the clone member.
 * @param text       The actual text content of the clone member.
 */
data CloneMember = cloneMember(loc location, int startLine, int endLine, str text);

/**
 * Data structure representing a class of clones.
 * 
 * @param members     The list of clone members in this class.
 * @param sizeLines   The number of lines in each clone member.
 */
data CloneClass = cloneClass(list[CloneMember] members, int sizeLines);
