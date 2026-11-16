package dev.samuelxing.flinkjob;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * Runs a .sql file as a Flink job.
 *
 * The job is defined entirely by SQL mounted into the pod, so changing the
 * pipeline is a ConfigMap change, not a rebuild. The jar itself never changes.
 *
 *   flink run-application ... flink-sql-runner.jar /opt/flink/sql/pipeline.sql
 */
public final class SqlRunner {

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: SqlRunner <path-to-sql-file>");
        }
        Path file = Paths.get(args[0]);
        if (!Files.isReadable(file)) {
            throw new IllegalArgumentException("cannot read SQL file: " + file);
        }

        String script = new String(Files.readAllBytes(file), StandardCharsets.UTF_8);
        List<String> statements = split(script);
        if (statements.isEmpty()) {
            throw new IllegalArgumentException("no statements found in " + file);
        }

        TableEnvironment tEnv = TableEnvironment.create(
                EnvironmentSettings.newInstance().inStreamingMode().build());

        for (String statement : statements) {
            System.out.println("--- executing ---\n" + statement + "\n");
            tEnv.executeSql(statement);
        }
        // In application mode the job keeps running after main() returns; an
        // INSERT submits asynchronously, so there is nothing to await here.
    }

    /**
     * Splits a script into statements on `;`.
     *
     * Two things stop this from being a one-line String.split(";"):
     *   - a `;` inside a string literal is not a terminator
     *   - `EXECUTE STATEMENT SET BEGIN ... END;` contains inner `;` and must
     *     stay one statement, or the statements run as separate jobs
     */
    static List<String> split(String script) {
        List<String> out = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inString = false;
        boolean inLineComment = false;
        int statementSetDepth = 0;

        for (int i = 0; i < script.length(); i++) {
            char c = script.charAt(i);
            char next = (i + 1 < script.length()) ? script.charAt(i + 1) : '\0';

            if (inLineComment) {
                if (c == '\n') {
                    inLineComment = false;
                    current.append(c);
                }
                continue;
            }
            if (inString) {
                current.append(c);
                // '' is an escaped quote inside a string literal
                if (c == '\'' && next == '\'') {
                    current.append(next);
                    i++;
                } else if (c == '\'') {
                    inString = false;
                }
                continue;
            }
            if (c == '-' && next == '-') {
                inLineComment = true;
                i++;
                continue;
            }
            if (c == '\'') {
                inString = true;
                current.append(c);
                continue;
            }

            current.append(c);

            if (statementSetDepth == 0 && startsBlockAt(current)) {
                statementSetDepth = 1;
                continue;
            }
            if (c == ';') {
                if (statementSetDepth > 0) {
                    if (endsBlockAt(current)) {
                        statementSetDepth = 0;
                    } else {
                        continue; // inner `;` of a statement set
                    }
                }
                emit(out, current);
                current.setLength(0);
            }
        }
        emit(out, current);
        return out;
    }

    private static boolean startsBlockAt(StringBuilder sb) {
        return endsWithWord(sb, "BEGIN");
    }

    private static boolean endsBlockAt(StringBuilder sb) {
        // the block terminator is `END;`, which we have just appended
        String tail = sb.substring(Math.max(0, sb.length() - 5)).trim().toUpperCase();
        return tail.endsWith("END;");
    }

    private static boolean endsWithWord(StringBuilder sb, String word) {
        String s = sb.toString().toUpperCase().trim();
        if (!s.endsWith(word)) {
            return false;
        }
        int before = s.length() - word.length() - 1;
        return before < 0 || !Character.isLetterOrDigit(s.charAt(before));
    }

    private static void emit(List<String> out, StringBuilder sb) {
        String s = sb.toString().trim();
        if (s.endsWith(";")) {
            s = s.substring(0, s.length() - 1).trim();
        }
        if (!s.isEmpty()) {
            out.add(s);
        }
    }

    private SqlRunner() {
    }
}
