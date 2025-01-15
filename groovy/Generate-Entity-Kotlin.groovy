import com.intellij.database.model.DasTable
import com.intellij.database.util.Case
import com.intellij.database.util.DasUtil

/*
 * Available context bindings:
 *   SELECTION   Iterable<DasObject>
 *   PROJECT     project
 *   FILES       files helper
 */
packageName = "com.c332030.entity"
typeMapping = [
        (~/(?i)bit/)                      : "Boolean",
        (~/(?i)tinyint/)                  : "Short",
        (~/(?i)smallint/)                 : "Short",
        (~/(?i)bigint/)                   : "Long",
        (~/(?i)int/)                      : "Int",
        (~/(?i)float|double|decimal|real/): "BigDecimal",
        (~/(?i)datetime|timestamp/)       : "Instant",
        (~/(?i)date/)                     : "Instant",
        (~/(?i)time/)                     : "Instant",
        (~/(?i)/)                         : "String"
]

FILES.chooseDirectoryAndSave("Choose directory", "Choose where to store generated files") { dir ->
    SELECTION.filter { it instanceof DasTable }.each { generate(it, dir) }
}

def generate(table, dir) {
    def className = javaName(table.getName(), true) + "DO"
    def fields = calcFields(table)
    new File(dir, className + ".kt").withPrintWriter("UTF-8") {
            // 使用 UTF-8 格式写入文件，默认是 GBK
        out ->

            def dirPath = dir.path
            def sourcePath = "kotlin"
            def sourcePathIndex = dirPath.indexOf(sourcePath)
            def packagePath = packageName
            if (sourcePathIndex > 0) {
                def packageFilePath = dirPath.substring(sourcePathIndex + sourcePath.length() + 1)
                packagePath = packageFilePath.replace("\\", ".")
            }

            out.print "package $packagePath\n\n"

            out.print "import com.baomidou.mybatisplus.annotation.TableName\n\n"

            out.print "import java.math.BigDecimal\n"
            out.print "import java.time.Instant\n\n"
            out.print "/**\n"
            out.print " * $table.comment\n"
            out.print " */\n"
            out.print "@TableName(\"$table.name\")\n"
            out.print "data class $className (\n"
            fields.each() {
                if (it.annos != "") {
                    out.print "  ${it.annos}\n"
                }
                out.print "\n    /**\n"
                out.print "     * ${it.comment}\n"
                out.print "     */\n"
                out.print "    val ${it.name}: ${it.type},\n"
            }
            out.print "\n)\n"
    }
}

def calcFields(table) {
    DasUtil.getColumns(table).reduce([]) { fields, col ->
        def spec = Case.LOWER.apply(col.getDataType().getSpecification())
        def typeStr = typeMapping.find { p, t -> p.matcher(spec).find() }.value
        fields += [
                [
                        name   : javaName(col.getName(), false),
                        type   : typeStr,
                        comment: col.getComment(), // 获取注释
                        annos  : "",
                ]
        ]
    }
}

def javaName(str, capitalize) {
    def s = com.intellij.psi.codeStyle.NameUtil.splitNameIntoWords(str)
            .collect { Case.LOWER.apply(it).capitalize() }
            .join("")
            .replaceAll(/[^\p{javaJavaIdentifierPart}[_]]/, "_")
    capitalize || s.length() == 1 ? s : Case.LOWER.apply(s[0]) + s[1..-1]
}
