package dev.samuelxing.flinkjob;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.StatementSet;
import org.apache.flink.table.api.TableEnvironment;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Runs a .sql file as one Flink job.
 *
 * The job is defined entirely by SQL mounted into the pod, so changing the
 * pipeline is a ConfigMap change, not a rebuild. The jar itself never changes.
 *
 * Three kinds of statement are treated differently:
 *   SET 'k' = 'v'   goes into the table config. executeSql() rejects SET: it
 *                   is SQL client syntax, not SQL.
 *   INSERT ...      is collected, and all of them are submitted together as a
 *                   single StatementSet, so a file is always exactly one job.
 *                   Application mode with HA allows only one.
 *   anything else   (CREATE TABLE, CREATE VIEW, ...) runs immediately.
 */
public final class SqlRunner {

    enum Kind { SET, INSERT, DDL, SKIP }

    private static final Pattern SET_STATEMENT = Pattern.compile(
            "^SET\\s+'([^']+)'\\s*=\\s*'((?:[^']|'')*)'$",
            Pattern.CASE_INSENSITIVE | Pattern.DOTALL);

    // `EXECUTE STATEMENT SET BEGIN` is accepted and unwrapped: every INSERT is
    // grouped into one set anyway, so the wrapper carries no extra meaning.
    private static final Pattern STATEMENT_SET_OPEN = Pattern.compile(
            "^(EXECUTE\\s+STATEMENT\\s+SET\\s+BEGIN|BEGIN\\s+STATEMENT\\s+SET)\\s*",
            Pattern.CASE_INSENSITIVE);

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: SqlRunner <path-to-sql-file>");
        }
        Path file = Paths.get(args[0]);
        if (!Files.isReadable(file)) {
            throw new IllegalArgumentException("cannot read SQL file: " + file);
        }
        List<String> statements =
                split(new String(Files.readAllBytes(file), StandardCharsets.UTF_8));

        TableEnvironment tEnv = TableEnvironment.create(
                EnvironmentSettings.newInstance().inStreamingMode().build());
        StatementSet inserts = tEnv.createStatementSet();
        int insertCount = 0;

        for (String raw : statements) {
            String statement = unwrap(raw);
            switch (classify(statement)) {
                case SKIP:
                    break;
                case SET:
                    String[] kv = parseSet(statement);
                    System.out.println("SET " + kv[0] + " = " + kv[1]);
                    tEnv.getConfig().set(kv[0], kv[1]);
                    break;
                case INSERT:
                    System.out.println("--- insert ---\n" + statement + "\n");
                    inserts.addInsertSql(statement);
                    insertCount++;
                    break;
                default:
                    System.out.println("--- executing ---\n" + statement + "\n");
                    tEnv.executeSql(statement);
            }
        }
        if (insertCount == 0) {
            throw new IllegalArgumentException(
                    "no INSERT statement in " + file + ": there is no job to run");
        }
        // Submits asynchronously. In application mode the job keeps running
        // after main() returns, so there is nothing to await.
        inserts.execute();
    }

    /** Strips a leading statement-set wrapper, if there is one. */
    static String unwrap(String statement) {
        return STATEMENT_SET_OPEN.matcher(statement).replaceFirst("").trim();
    }

    static Kind classify(String statement) {
        String upper = statement.toUpperCase(Locale.ROOT);
        if (upper.isEmpty() || upper.equals("END")) {
            return Kind.SKIP;
        }
        if (SET_STATEMENT.matcher(statement).matches()) {
            return Kind.SET;
        }
        if (upper.startsWith("INSERT ")) {
            return Kind.INSERT;
        }
        return Kind.DDL;
    }

    static String[] parseSet(String statement) {
        Matcher m = SET_STATEMENT.matcher(statement);
        if (!m.matches()) {
            throw new IllegalArgumentException("not a SET statement: " + statement);
        }
        return new String[] {m.group(1), m.group(2).replace("''", "'")};
    }

    /**
     * Splits a script on `;`, ignoring any `;` inside a string literal, a
     * `--` line comment or a block comment. Comments are dropped.
     */
    static List<String> split(String script) {
        List<String> out = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inString = false;
        boolean inLineComment = false;
        boolean inBlockComment = false;

        for (int i = 0; i < script.length(); i++) {
            char c = script.charAt(i);
            char next = (i + 1 < script.length()) ? script.charAt(i + 1) : '\0';

            if (inLineComment) {
                if (c == '\n') {
                    inLineComment = false;
                    current.append(c);
                }
            } else if (inBlockComment) {
                if (c == '*' && next == '/') {
                    inBlockComment = false;
                    current.append(' ');
                    i++;
                }
            } else if (inString) {
                current.append(c);
                if (c == '\'' && next == '\'') { // '' is an escaped quote
                    current.append(next);
                    i++;
                } else if (c == '\'') {
                    inString = false;
                }
            } else if (c == '-' && next == '-') {
                inLineComment = true;
                i++;
            } else if (c == '/' && next == '*') {
                inBlockComment = true;
                i++;
            } else if (c == ';') {
                emit(out, current);
            } else {
                if (c == '\'') {
                    inString = true;
                }
                current.append(c);
            }
        }
        emit(out, current);
        return out;
    }

    private static void emit(List<String> out, StringBuilder sb) {
        String s = sb.toString().trim();
        sb.setLength(0);
        if (!s.isEmpty()) {
            out.add(s);
        }
    }

    private SqlRunner() {
    }
}
