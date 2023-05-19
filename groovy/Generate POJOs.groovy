import com.intellij.database.model.DasTable
import com.intellij.database.util.Case
import com.intellij.database.util.DasUtil

/*
 * Available context bindings:
 *   SELECTION   Iterable<DasObject>
 *   PROJECT     project
 *   FILES       files helper
 */

typeMapping = [
  (~/(?i)bit/)                      : "Boolean",
  (~/(?i)tinyint/)                  : "Short",
  (~/(?i)smallint/)                 : "Short",
  (~/(?i)bigint/)                   : "Long",
  (~/(?i)int/)                      : "Integer",
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
  def className = javaName(table.getName(), true)
  def fields = calcFields(table)
//  new File(dir, className + ".java").withPrintWriter { out -> generate(out, className, fields).getBytes('UTF-8'), }

  File sql = new File(dir, className + ".java")
  sql.delete()

  sql.withPrintWriter('UTF-8') { // 使用 UTF-8 格式写入文件，默认是 GBK
//    out -> generate(out, className, fields)
  out ->

    def dirPath = dir.path
    def sourcePath = "src\\main\\java"
    def sourcePathIndex = dirPath.indexOf(sourcePath)
    def packagePath = packageName
    if(sourcePathIndex > 0) {
      def packageFilePath = dirPath.substring(sourcePathIndex + sourcePath.length() + 1)
      packagePath = packageFilePath.replace("\\", ".")
    }

    out.println "package $packagePath;"
    out.println ""
    out.println "import lombok.Data;"
    out.println ""
    out.println "import java.time.Instant;"
    out.println ""
    out.println "/**"
    out.println " * Table: $table.name $table.comment"
    out.println " */"
    out.println "@Data"
    out.println "public class $className {\n"
    fields.each() {
      if (it.annos != "") {
        out.println "  ${it.annos}"
      }
      out.println "    /**"
      out.println "     * ${it.comment}"
      out.println "     */"
      out.println "    private ${it.type} ${it.name};\n"
    }

    out.println "}"

  }
}

def calcFields(table) {
  DasUtil.getColumns(table).reduce([]) { fields, col ->
    def spec = Case.LOWER.apply(col.getDataType().getSpecification())
    def typeStr = typeMapping.find { p, t -> p.matcher(spec).find() }.value
    fields += [
      [
        name : javaName(col.getName(), false),
        type : typeStr,
        comment: col.getComment(), // 获取注释
        annos: '',
      ]
    ]
  }
}

def javaName(str, capitalize) {
  def s = com.intellij.psi.codeStyle.NameUtil.splitNameIntoWords(str)
    .collect { Case.LOWER.apply(it).capitalize() }
    .join("")
    .replaceAll(/[^\p{javaJavaIdentifierPart}[_]]/, "_")
  capitalize || s.length() == 1? s : Case.LOWER.apply(s[0]) + s[1..-1]
}
