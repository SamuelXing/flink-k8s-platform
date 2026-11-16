package dev.samuelxing.flinkjob;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SqlRunnerTest {

    @Test
    void splitsPlainStatements() {
        List<String> out = SqlRunner.split("SELECT 1; SELECT 2;");
        assertEquals(2, out.size());
        assertEquals("SELECT 1", out.get(0));
        assertEquals("SELECT 2", out.get(1));
    }

    @Test
    void dropsLineCommentsButKeepsStatements() {
        List<String> out = SqlRunner.split(
                "-- a comment with a ; in it\nSELECT 1;\n-- trailing comment\n");
        assertEquals(1, out.size());
        assertEquals("SELECT 1", out.get(0).trim());
    }

    @Test
    void semicolonInsideStringIsNotATerminator() {
        List<String> out = SqlRunner.split("SELECT 'a;b' AS x;");
        assertEquals(1, out.size());
        assertTrue(out.get(0).contains("'a;b'"));
    }

    @Test
    void escapedQuoteDoesNotEndTheString() {
        List<String> out = SqlRunner.split("SELECT 'it''s; fine' AS x; SELECT 2;");
        assertEquals(2, out.size());
        assertTrue(out.get(0).contains("it''s; fine"));
    }

    @Test
    void statementSetStaysOneStatement() {
        String script =
                "CREATE TABLE a (x INT) WITH ('connector'='datagen');\n"
              + "EXECUTE STATEMENT SET\n"
              + "BEGIN\n"
              + "  INSERT INTO a SELECT 1;\n"
              + "  INSERT INTO a SELECT 2;\n"
              + "END;\n";
        List<String> out = SqlRunner.split(script);
        assertEquals(2, out.size(), "CREATE plus one statement set, got: " + out);
        assertTrue(out.get(1).startsWith("EXECUTE STATEMENT SET"));
        assertTrue(out.get(1).contains("INSERT INTO a SELECT 1"));
        assertTrue(out.get(1).contains("INSERT INTO a SELECT 2"));
        assertTrue(out.get(1).trim().endsWith("END"));
    }

    @Test
    void ignoresBlankScript() {
        assertTrue(SqlRunner.split("   \n-- nothing\n   ").isEmpty());
    }

    @Test
    void handlesTheRealPipelineShape() {
        String script =
                "SET 'pipeline.name' = 'x';\n"
              + "CREATE TABLE orders (\n"
              + "  id STRING,\n"
              + "  WATERMARK FOR t AS t - INTERVAL '5' SECOND\n"
              + ") WITH ('connector' = 'kafka');\n"
              + "INSERT INTO sink SELECT * FROM TABLE(TUMBLE(TABLE orders,"
              + " DESCRIPTOR(t), INTERVAL '1' MINUTE));\n";
        List<String> out = SqlRunner.split(script);
        assertEquals(3, out.size(), "got: " + out);
    }
}
