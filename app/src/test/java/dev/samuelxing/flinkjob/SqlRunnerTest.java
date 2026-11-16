package dev.samuelxing.flinkjob;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SqlRunnerTest {

    private static List<SqlRunner.Kind> kinds(String script) {
        return SqlRunner.split(script).stream()
                .map(SqlRunner::unwrap)
                .map(SqlRunner::classify)
                .collect(Collectors.toList());
    }

    @Test
    void splitsPlainStatements() {
        assertEquals(List.of("SELECT 1", "SELECT 2"), SqlRunner.split("SELECT 1; SELECT 2;"));
    }

    @Test
    void dropsLineAndBlockComments() {
        List<String> out = SqlRunner.split(
                "-- a comment with a ; in it\nSELECT /* and ; here */ 1;\n-- trailing\n");
        assertEquals(1, out.size());
        assertEquals("SELECT   1", out.get(0));
    }

    @Test
    void semicolonInsideStringIsNotATerminator() {
        List<String> out = SqlRunner.split("SELECT 'a;b' AS x;");
        assertEquals(List.of("SELECT 'a;b' AS x"), out);
    }

    @Test
    void escapedQuoteDoesNotEndTheString() {
        List<String> out = SqlRunner.split("SELECT 'it''s; fine' AS x; SELECT 2;");
        assertEquals(2, out.size());
        assertTrue(out.get(0).contains("it''s; fine"));
    }

    @Test
    void commentMarkerInsideStringIsKept() {
        assertEquals(List.of("SELECT '--not a comment' AS x"),
                SqlRunner.split("SELECT '--not a comment' AS x;"));
    }

    @Test
    void ignoresBlankScript() {
        assertTrue(SqlRunner.split("   \n-- nothing\n   ").isEmpty());
    }

    @Test
    void setIsRecognisedAndParsed() {
        String s = "SET 'pipeline.name' = 'demo-pipeline'";
        assertEquals(SqlRunner.Kind.SET, SqlRunner.classify(s));
        assertArrayEquals(new String[] {"pipeline.name", "demo-pipeline"}, SqlRunner.parseSet(s));
    }

    @Test
    void statementSetWrapperIsUnwrappedIntoItsInserts() {
        String script =
                "CREATE TABLE a (x INT) WITH ('connector'='datagen');\n"
              + "EXECUTE STATEMENT SET\n"
              + "BEGIN\n"
              + "  INSERT INTO a SELECT 1;\n"
              + "  INSERT INTO a SELECT x FROM spend;\n"
              + "END;\n";
        assertEquals(
                List.of(SqlRunner.Kind.DDL, SqlRunner.Kind.INSERT,
                        SqlRunner.Kind.INSERT, SqlRunner.Kind.SKIP),
                kinds(script));
        assertEquals("INSERT INTO a SELECT 1", SqlRunner.unwrap(SqlRunner.split(script).get(1)));
    }

    @Test
    void classifiesTheRealPipelineShape() {
        String script =
                "SET 'pipeline.name' = 'x';\n"
              + "CREATE TABLE orders (\n"
              + "  id STRING,\n"
              + "  WATERMARK FOR t AS t - INTERVAL '5' SECOND\n"
              + ") WITH ('connector' = 'kafka');\n"
              + "INSERT INTO sink SELECT * FROM TABLE(TUMBLE(TABLE orders,"
              + " DESCRIPTOR(t), INTERVAL '1' MINUTE));\n";
        assertEquals(
                List.of(SqlRunner.Kind.SET, SqlRunner.Kind.DDL, SqlRunner.Kind.INSERT),
                kinds(script));
    }
}
